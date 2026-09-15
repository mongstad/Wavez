"""Summarize retained baseline/final playback traces without rerunning the viewer."""
import argparse,csv,json,statistics
from pathlib import Path

def write_csv(path,rows):
    if not rows:return
    fields=list(dict.fromkeys(k for row in rows for k in row))
    with path.open('w',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=fields);writer.writeheader();writer.writerows(rows)

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('directory',type=Path)
    args=parser.parse_args();root=args.directory.resolve();out=root/'analysis';out.mkdir(exist_ok=True)
    runs={name:json.loads((root/name/'profile.json').read_text()) for name in ['baseline-compatibility','baseline-forward','final-compatibility','final-forward','stress-compatibility','stress-forward']}
    rows=[];callbacks=[];workers=[];stages=[];checks=[]
    def check(ok,name):checks.append(dict(name=name,ok=bool(ok)))
    for run,data in runs.items():
        baseline=run.startswith('baseline')
        check(json.loads((root/run/'source-preservation.json').read_text())['unchanged'],run+' capture stat unchanged')
        for c in data['cases']:
            name=c['config']['name'];cb=c['callbacks'];transition=[p for p in cb if p['pair_before']!=p['pair_after']]
            times=[p['duration_ms'] for p in transition];cache=c.get('playback',{}).get('cache',{})
            first_ready=next((p['end_us'] for p in cb if not p['buffering']),c['end_us'])
            wait=(first_ready-c['start_us'])/1e6 if c['config'].get('cold') else 0
            delta={k:cache.get(k,0)-c.get('cache_before',{}).get(k,0) for k in ['prepared_hits','prepared_misses','decoded_hits','decoded_misses','prepared_evictions','completed','cancelled']}
            row=dict(run=run,renderer=data['backend'],case=name,wall_seconds=(c['end_us']-c['start_us'])/1e6,callbacks=len(cb),pair_transitions=len(transition),transition_median_ms=statistics.median(times),transition_max_ms=max(times),callback_max_ms=max(p['duration_ms'] for p in cb),stalls_ge_50ms=sum(p['duration_ms']>=50 for p in cb),buffering_callbacks=sum(p['buffering'] for p in cb),initial_buffer_seconds=wait,request_ms=c['request_ms'],source_start=cb[0]['time_before'],source_end=cb[-1]['time_after'],buffer_depth_min=min((p.get('buffer_depth',0) for p in cb),default=0),buffer_depth_max=max((p.get('buffer_depth',0) for p in cb),default=0),rss_bytes=c.get('rss_bytes'),static_bytes=c['memory_static'],gpu_particle_buffer_bytes=c['gpu_buffer_bytes'],gpu_reported_buffer_bytes=c.get('gpu_reported_buffer_bytes'),gpu_reported_texture_bytes=c.get('gpu_reported_texture_bytes'),decoded_cache_bytes=cache.get('decoded_bytes'),prepared_cache_bytes=cache.get('prepared_bytes'),**delta)
            rows.append(row)
            check(c['trace']['dropped']==0,run+'/'+name+' main trace complete')
            if not baseline:
                check(row['stalls_ge_50ms']==0,run+'/'+name+' no >=50ms callback')
                check(not cache['error'],run+'/'+name+' no worker error')
                check(cache['decoded_bytes']<=c['playback']['decoded_limit'] and cache['prepared_bytes']<=c['playback']['prepared_limit'],run+'/'+name+' both cache charges within limits')
                check(c['playback']['events_dropped']==0 and cache['trace_dropped']==0,run+'/'+name+' worker trace complete')
                check(all(e['thread_id']!=data['main_thread_id'] for e in c['playback']['events']),run+'/'+name+' preparation on distinct worker thread')
                if not c['config'].get('cold'):check(row['buffering_callbacks']==0,run+'/'+name+' no buffer underflow')
                if name=='hidden_optimized':
                    check(delta['decoded_misses']==0 and delta['completed']==0,run+' hidden performs no new decoding or pair preparation')
                    check(not any(k in c['stages'] for k in ['interpolation_pack','buffer_submit','identity_match','style_inclusive']),run+' hidden skips particle packing/upload/style/matching')
            for p in cb:
                callbacks.append(dict(run=run,case=name,wall_seconds=(p['start_us']-c['start_us'])/1e6,transition=p['pair_before']!=p['pair_after'],**p))
            for stage,values in c['stages'].items():
                on_transition=[e['duration_ms'] for e in c['trace']['events'] if e['name']==stage and any(p['start_us']<=e['start_us'] and e['end_us']<=p['end_us'] for p in transition)]
                stages.append(dict(run=run,case=name,thread='main',stage=stage,count=values['count'],median_ms=values['p50_ms'],max_ms=values['max_ms'],transition_count=len(on_transition),transition_median_ms=statistics.median(on_transition) if on_transition else None))
            worker_stages={}
            for e in c.get('playback',{}).get('events',[]):
                workers.append(dict(run=run,case=name,index=e['index'],start_us=e['start_us'],end_us=e['end_us'],wall_seconds=(e['start_us']-c['start_us'])/1e6,duration_ms=e['duration_ms'],cancelled=e['cancelled'],error=e['error'],pair_bytes=e['pair_bytes'],sample_a_bytes=e['sample_a_bytes'],thread_id=e['thread_id'],**{'stage_'+k:v for k,v in e['stages'].items()}))
                if not e['cancelled'] and not e['error']:
                    for stage,value in dict(worker_total=e['duration_ms'],**e['stages']).items():worker_stages.setdefault(stage,[]).append(value)
            for stage,values in worker_stages.items():stages.append(dict(run=run,case=name,thread='worker',stage=stage,count=len(values),median_ms=statistics.median(values),max_ms=max(values)))
    write_csv(out/'cases.csv',rows);write_csv(out/'callbacks.csv',callbacks);write_csv(out/'worker_jobs.csv',workers);write_csv(out/'stages.csv',stages)
    result=dict(checks=checks,failures=sum(not c['ok'] for c in checks))
    (out/'performance-checks.json').write_text(json.dumps(result,indent=2)+'\n')
    (out/'summary.json').write_text(json.dumps(rows,indent=2)+'\n')
    table=['| Renderer / case | Pair callbacks | Median / max transition (ms) | Max callback (ms) | ≥50 ms stalls | Initial buffer (s) |','|---|---:|---:|---:|---:|---:|']
    for r in rows:table.append(f"| {r['renderer']} / {r['case']} | {r['pair_transitions']} | {r['transition_median_ms']:.2f} / {r['transition_max_ms']:.2f} | {r['callback_max_ms']:.2f} | {r['stalls_ge_50ms']} | {r['initial_buffer_seconds']:.3f} |")
    (out/'PERFORMANCE_TABLE.md').write_text('\n'.join(table)+'\n')
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    plt.rcParams.update({'font.size':10,'axes.spines.top':False,'axes.spines.right':False,'figure.dpi':150})
    fig,axes=plt.subplots(3,2,figsize=(12,8),sharex=True,sharey=True,layout='constrained')
    for col,suffix in enumerate(['compatibility','forward']):
        for row,(run,name,label) in enumerate([('baseline','synchronous_hidden','Baseline • particles hidden'),('final','hidden_optimized','Optimized • particles hidden'),('final','visible_prebuffered','Optimized • visible, prebuffered')]):
            c=next(c for c in runs[run+'-'+suffix]['cases'] if c['config']['name']==name)
            ax=axes[row,col];cb=c['callbacks'];t=[(p['start_us']-c['start_us'])/1e6 for p in cb];y=[p['duration_ms'] for p in cb]
            ax.plot(t,y,lw=.6,color='#346b9c');changes=[p for p in cb if p['pair_before']!=p['pair_after']]
            ax.scatter([(p['start_us']-c['start_us'])/1e6 for p in changes],[p['duration_ms'] for p in changes],s=15,color='#c35a32',zorder=4,label='Source-pair change')
            ax.axhline(50,color='#888',ls='--',lw=.8);ax.set_title(suffix.title()+' — '+label);ax.set_ylim(0,205);ax.grid(alpha=.2)
            if col==0:ax.set_ylabel('Main callback (ms)')
            if row==2:ax.set_xlabel('Wall time in measured interval (s)')
    axes[0,0].legend(loc='upper right',fontsize=8)
    fig.suptitle('Retained layered capture: source-pair stalls removed from playback callback',fontsize=13)
    fig.savefig(out/'callback-comparison.png');plt.close(fig)
    fig,axes=plt.subplots(2,2,figsize=(12,7),layout='constrained')
    for col,suffix in enumerate(['compatibility','forward']):
        c=runs['stress-'+suffix]['cases'][0];cb=c['callbacks'];t=[(p['start_us']-c['start_us'])/1e6 for p in cb]
        axes[0,col].plot(t,[p['duration_ms'] for p in cb],lw=.6,color='#346b9c');axes[0,col].axhline(50,color='#888',ls='--',lw=.8);axes[0,col].set_ylim(0,55);axes[0,col].set_title(suffix.title()+' • sustained replenishment');axes[0,col].set_ylabel('Main callback (ms)')
        axes[1,col].step(t,[p['buffer_depth'] for p in cb],where='post',lw=1,color='#228675');axes[1,col].set_ylim(0,9);axes[1,col].set_xlabel('Wall time (s)');axes[1,col].set_ylabel('Ready upcoming pairs')
        for ax in axes[:,col]:ax.grid(alpha=.2)
    fig.savefig(out/'buffer-replenishment.png');plt.close(fig)
    print('PERFORMANCE:',len(checks),'checks,',result['failures'],'failures')
    if result['failures']:raise SystemExit(1)

if __name__=='__main__':main()

"""Paired native timings on accepted benchmark 04B against a separate baseline; no solver."""
import argparse,hashlib,json,os,shutil,sys
from pathlib import Path
import numpy as np
from validate_performance_maintenance import run
ROOT=Path(__file__).resolve().parents[1]
def summarize(d):
    rows=d.pop('callbacks');cost=np.array([r['callback_ms'] for r in rows]);interval=np.array([r['delta_ms'] for r in rows]);times=[r['time'] for r in rows];rate=d['config']['rate']
    progress=0.
    for a,b in zip(times,times[1:]):
        delta=b-a
        if rate>0 and delta<-.5:delta+=1
        if rate<0 and delta>.5:delta-=1
        progress+=delta
    return d|dict(callbacks_summary=dict(count=len(rows),p95_ms=float(np.percentile(cost,95)),p99_ms=float(np.percentile(cost,99)),max_ms=float(cost.max()),over_50ms=int((cost>=50).sum()),interval_p95_ms=float(np.percentile(interval,95)),interval_max_ms=float(interval.max()),buffering_callbacks=sum(r['buffering'] for r in rows),buffering_seconds=sum(r['delta_ms'] for r in rows if r['buffering'])/1000,distinct_indices=sorted({r['index'] for r in rows}),transitions=sum(a['index']!=b['index'] for a,b in zip(rows,rows[1:])),load_factor_progress=progress,expected_progress=rate*d['duration_seconds'],progress_fraction=progress/(rate*d['duration_seconds'])))
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--godot',required=True);p.add_argument('--capture',required=True,type=Path);p.add_argument('--baseline-viewer',required=True,type=Path);p.add_argument('--output-dir',required=True,type=Path);p.add_argument('--seconds',type=float,default=12);p.add_argument('--renderer',default='gl_compatibility',choices=['gl_compatibility','forward_plus']);p.add_argument('--extended',action='store_true');a=p.parse_args()
    out=a.output_dir.resolve();out.mkdir(parents=True,exist_ok=False);capture=a.capture.resolve();digest=hashlib.sha256(capture.read_bytes()).hexdigest();runs=[]
    # This small identical harness is an explicitly recorded baseline instrumentation overlay.
    script=ROOT/'viewer/layers/profile_mesh_playback.gd';dest=a.baseline_viewer/'layers/profile_mesh_playback.gd'
    if dest.exists():assert dest.read_bytes()==script.read_bytes()
    else:shutil.copyfile(script,dest)
    configs=[(256,False,.2),(256,True,.2)]
    if a.extended:configs += [(0,False,.2),(256,False,.4),(256,True,-.2)]
    for cache,wire,rate in configs:
        for mode,viewer in [('before',a.baseline_viewer.resolve()),('after',ROOT/'viewer')]:
            name=f'{mode}-cache{cache}-wire{int(wire)}-rate{rate}';result=out/(name+'.json');job=result.with_suffix('.job.json');job.write_text(json.dumps(dict(capture=str(capture),cache_mib=cache,wireframe=wire,rate=rate,seconds=a.seconds,output=str(result))))
            os.environ['XDG_DATA_HOME']=str(out/(name+'-userdata'))
            run(a.godot,viewer,'layers/profile_mesh_playback.gd',result,['--mesh-profile-job='+str(job)],a.renderer)
            data=summarize(json.loads(result.read_text()));data['mode']=mode;runs.append(data);print(name,data['callbacks_summary'],flush=True)
    checks=[]
    for d in (x for x in runs if x['mode']=='after'):
        c=d['config'];before=next(x for x in runs if x['mode']=='before' and all(x['config'][k]==c[k] for k in ['wireframe','cache_mib','rate']));s=d['callbacks_summary'];label=f"cache{c['cache_mib']}/wire{c['wireframe']}/rate{c['rate']}"
        for name,ok in [('no underflow',s['buffering_callbacks']==0),('no callbacks >=50 ms',s['over_50ms']==0),('lower callback p99',s['p99_ms']<before['callbacks_summary']['p99_ms']),('wall-time progress within 5 percent',.95<=s['progress_fraction']<=1.05),('all 20 retained intervals visited',len(set(range(20))&set(s['distinct_indices']))==20),('bounded CPU cache',d['mesh']['cache']['bytes']<=d['mesh']['cache']['limit']),('one future GPU mesh',d['mesh']['staged_meshes']<=1),('worker separate from main',d['mesh']['cache']['worker_thread']!=d['main_thread']),('no preparation errors',not d['mesh']['error'] and not d['mesh']['cache']['error'])]:checks.append(dict(case=label,name=name,passed=bool(ok)))
    assert hashlib.sha256(capture.read_bytes()).hexdigest()==digest
    summary=dict(runs=runs,checks=checks,source_sha256=digest,source_unchanged=True,scientific_solvers_run=0,harness_sha256=hashlib.sha256(script.read_bytes()).hexdigest(),scope='Application callbacks, source-clock progress and process RSS; not monitor FPS or isolated GPU timing. Fixed 0.5 s warmup; OS page cache not flushed.')
    (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');assert all(x['passed'] for x in checks),[x for x in checks if not x['passed']]
if __name__=='__main__':main()

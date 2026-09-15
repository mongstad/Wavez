"""Compare actual SIMSCP3 callback transitions with bounded CPU preparation."""
import argparse,hashlib,json,shutil,statistics,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def analyze(path):
    data=json.loads(path.read_text());rows=[]
    for c in data['cases']:
        points=c['callbacks'];transitions=[p for p in points if p['pair_before']!=p['pair_after']]
        times=[p['duration_ms'] for p in transitions]
        stalls=[p for p in points if p['duration_ms']>=50]
        row=dict(case=c['config']['name'],callbacks=len(points),stalls=len(stalls),transitions=len(transitions),transition_median_ms=statistics.median(times) if times else None,transition_max_ms=max(times,default=0),callback_max_ms=max(p['duration_ms'] for p in points),buffering_callbacks=sum(p['buffering'] for p in points),request_ms=c['request_ms'],ready_before=c['ready_before'],gpu_buffer_bytes=c['gpu_buffer_bytes'],static_memory=c['memory_static'],source_start=points[0]['time_before'],source_end=points[-1]['time_after'])
        row['cache']=c.get('playback',{}).get('cache',{})
        row['rss_bytes']=c.get('rss_bytes')
        row['cache_delta']={k:row['cache'].get(k,0)-c.get('cache_before',{}).get(k,0) for k in ['prepared_hits','prepared_misses','decoded_hits','decoded_misses','prepared_evictions','completed','cancelled']}
        row['gpu_reported_buffer_bytes']=c.get('gpu_reported_buffer_bytes')
        row['gpu_reported_texture_bytes']=c.get('gpu_reported_texture_bytes')
        rows.append(row)
    result=dict(capture=data['capture'],backend=data['backend'],cases=rows)
    (path.parent/'analysis.json').write_text(json.dumps(result,indent=2)+'\n')
    return result

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot',required=True);p.add_argument('--capture',required=True,type=Path)
    p.add_argument('--output-dir',required=True,type=Path);p.add_argument('--baseline',action='store_true');p.add_argument('--baseline-viewer',type=Path)
    p.add_argument('--stress',action='store_true',help='Longer replenishment, 2x physical speed, and loop controls')
    p.add_argument('--renderer',choices=['gl_compatibility','forward_plus'],default='gl_compatibility')
    a=p.parse_args();out=a.output_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    source=a.capture.resolve();before=source.stat()
    viewer=ROOT/'viewer'
    if a.baseline:
        if not a.baseline_viewer or not (a.baseline_viewer/'project.godot').is_file():
            p.error('--baseline requires --baseline-viewer pointing to a restored historical viewer')
        viewer=a.baseline_viewer.resolve()
        for f in (ROOT/'viewer').rglob('*'):
            if f.is_file() and '.godot' not in f.parts and f.suffix!='.gd':
                dest=viewer/f.relative_to(ROOT/'viewer');dest.parent.mkdir(parents=True,exist_ok=True)
                if not dest.exists():shutil.copy2(f,dest)
        shutil.copy2(ROOT/'viewer/layers/profile_scene_playback.gd',viewer/'layers/profile_scene_playback.gd')
    cases=[dict(name='synchronous_hidden',visible=False,seconds=4),dict(name='synchronous_visible',seconds=4)] if a.baseline else [dict(name='hidden_optimized',visible=False,seconds=4),dict(name='visible_cold',cold=True,seconds=4),dict(name='visible_prebuffered',prebuffer=True,seconds=4),dict(name='prepared_replay',reuse=True,prebuffer=True,seconds=4),dict(name='uncached_seek',reuse=True,cold=True,start=32.125,seconds=4)]
    if a.stress:
        if a.baseline:p.error('--stress is for optimized playback')
        cases=[dict(name='long_replenishment',prebuffer=True,seconds=12),dict(name='physical_rate_2',prebuffer=True,start=12,rate=2,seconds=8),dict(name='loop',prebuffer=True,start=38,loop=True,seconds=5)]
    job=dict(capture=str(source),optimized=not a.baseline,cases=cases,output=str(out/'profile.json'))
    (out/'job.json').write_text(json.dumps(job,indent=2)+'\n')
    hashes={str(f.relative_to(viewer)):hashlib.sha256(f.read_bytes()).hexdigest() for f in viewer.rglob('*.gd')}
    (out/'source-sha256.json').write_text(json.dumps(hashes,indent=2)+'\n')
    cmd=[a.godot,'--path',str(viewer),'--resolution','960x640','--rendering-method',a.renderer,'--audio-driver','Dummy','--disable-vsync','--max-fps','120','--log-file',str(out/'godot.log'),'--script','layers/profile_scene_playback.gd','--','--playback-job='+str(out/'job.json')]
    with (out/'stdout.log').open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=180)
    log=(out/'stdout.log').read_text()
    if r.returncode or 'ERROR:' in log:raise RuntimeError('Profile failed: '+str(out/'stdout.log'))
    after=source.stat();unchanged=(before.st_dev,before.st_ino,before.st_size,before.st_mtime_ns,before.st_ctime_ns)==(after.st_dev,after.st_ino,after.st_size,after.st_mtime_ns,after.st_ctime_ns)
    (out/'source-preservation.json').write_text(json.dumps(dict(unchanged=unchanged,size=before.st_size),indent=2)+'\n')
    if not unchanged:raise RuntimeError('Source changed during measurement')
    print(json.dumps(analyze(out/'profile.json'),indent=2))
if __name__=='__main__':main()

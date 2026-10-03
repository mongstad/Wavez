"""Check native maintenance regressions and optionally profile retained captures (no solvers)."""
import argparse,hashlib,json,subprocess,sys
from pathlib import Path
import numpy as np
from validate_scene_playback import prepare
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from wavez_export import SceneCapture, SceneReader

def run(godot,viewer,script,out,args,renderer='headless',timeout=180):
    cmd=[godot,'--path',str(viewer),'--audio-driver','Dummy','--log-file',str(out.with_suffix('.godot.log'))]
    cmd+=['--headless'] if renderer=='headless' else ['--rendering-method',renderer,'--resolution','1280x800']
    cmd+=['--script',script,'--',*args]
    r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=timeout)
    out.with_suffix('.log').write_text(r.stdout)
    if r.returncode or 'ERROR:' in r.stdout:raise RuntimeError(f'{script}: {out.with_suffix(".log")}')

def summarize(path):
    d=json.loads(path.read_text());d['memory']={k.rstrip(':\t '):v for k,v in d['memory'].items()};rows=d.pop('callbacks');ms=np.array([r['callback_ms'] for r in rows])
    ids=[r['index'] for r in rows]
    d['callbacks_summary']=dict(count=len(rows),callbacks_per_second=len(rows)/d['duration_seconds'],p95_ms=float(np.percentile(ms,95)),p99_ms=float(np.percentile(ms,99)),max_ms=float(ms.max()),over_50ms=int((ms>=50).sum()),buffering_seconds=sum(r['delta_ms'] for r in rows if r['buffering'])/1000,buffering_callbacks=sum(r['buffering'] for r in rows),transitions=sum(a!=b for a,b in zip(ids,ids[1:])),wraps=sum(b<a for a,b in zip(ids,ids[1:])),distinct_indices=len(set(ids)))
    return d

def validate_profiles(runs):
    checks=[]
    def check(ok,name):
        checks.append(dict(name=name,passed=bool(ok)))
    for after in (r for r in runs if r['mode']=='after'):
        before=next(r for r in runs if r['mode']=='before' and r['case']==after['case'] and r['cache_mib']==after['cache_mib'])
        stats=after['callbacks_summary'];label=f"{after['case']} cache {after['cache_mib']:g} MiB"
        check(stats['buffering_callbacks']==0,label+' zero playback underflow')
        check(stats['over_50ms']==0,label+' zero callbacks >=50 ms')
        check(stats['distinct_indices']>=(60 if after['case']=='02B' else 40),label+' traverses retained intervals')
        if after['case']=='02B':
            p=after['particle'];check(p['policy']=='adaptive' and p['cache']['prepared_bytes']<=p['prepared_limit'],label+' automatically requests safe preparation')
            check(p['cache']['decoded_bytes']<=p['decoded_limit'] and p['cache']['prepared_bytes']<=p['prepared_limit'],label+' bounded particle caches')
        else:
            f=after['field'];check(f['enabled'] and f['cache']['bytes']<=f['cache']['limit'] and f['staged_textures']<=1,label+' bounded CPU preparation and GPU staging')
            check(stats['p99_ms']<before['callbacks_summary']['p99_ms'],label+' improves callback p99')
            check(not f['error'] and not f['cache']['error'],label+' no field preparation errors')
    return checks

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--godot',required=True);p.add_argument('--output-dir',type=Path,required=True)
    p.add_argument('--renderer',default='headless',choices=['headless','gl_compatibility','forward_plus']);p.add_argument('--baseline-viewer',type=Path)
    p.add_argument('--particle-scene',type=Path);p.add_argument('--field-scene',type=Path)
    a=p.parse_args();out=a.output_dir.resolve();out.mkdir(parents=True,exist_ok=True)
    if a.particle_scene or a.field_scene:
        if not a.baseline_viewer or a.renderer=='headless' or not a.particle_scene or not a.field_scene:
            p.error('Profile comparison requires both WVZ1 scenes, --baseline-viewer and a real --renderer')
        runs=[];sources={}
        for case,capture,seconds in [('02B',a.particle_scene,16),('03B',a.field_scene,12)]:
            capture=capture.resolve()
            with SceneReader(capture, strict=True, cache_bytes=0) as reader:
                expected = 'particles' if case == '02B' else 'volume'
                if not any(obj['kind'] == expected for obj in reader.objects.values()):
                    p.error(f'{case} requires a WVZ1 {expected} scene')
            sources[str(capture)]=hashlib.sha256(capture.read_bytes()).hexdigest()
            for cache in ([256] if case=='02B' else [0,256]):
                for mode,viewer in [('before',a.baseline_viewer.resolve()),('after',ROOT/'viewer')]:
                    result=out/f'{case}-{cache}-{mode}.json';job=result.with_suffix('.job.json');job.write_text(json.dumps(dict(case=case,capture=str(capture),cache_mib=cache,seconds=seconds,output=str(result))))
                    run(a.godot,viewer,'layers/profile_maintenance.gd',result,['--maintenance-job='+str(job)],a.renderer)
                    data=summarize(result);data['mode']=mode;runs.append(data);print(case,cache,mode,data['callbacks_summary'],flush=True)
        assert all(hashlib.sha256(Path(s).read_bytes()).hexdigest()==h for s,h in sources.items())
        checks=validate_profiles(runs)
        (out/'summary.json').write_text(json.dumps(dict(runs=runs,sources=sources,source_unchanged=True,checks=checks),indent=2)+'\n')
        assert all(c['passed'] for c in checks), checks
    else:
        fixtures=out/'fixtures';prepare(fixtures)
        path=fixtures/'field.wvz';path.unlink(missing_ok=True)
        with SceneCapture(path,objects=[dict(id='field',kind='volume',units='u')],compression='zstd') as w:
            for t in [0,1.25,3.25,4]:w.add_volume('field',t,{'rho':np.full((4,4,4),t+1,dtype='f8')},origin=[0,0,0],spacing=[1,1,1])
        for script in ['test_performance_maintenance','test_scene_playback_lifecycle']:
            run(a.godot,ROOT/'viewer',f'layers/{script}.gd',out/script,['--playback-fixture='+str(fixtures)],a.renderer)
            print(script,'PASS',flush=True)
if __name__=='__main__':main()

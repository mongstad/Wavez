"""100k-particle G4 idle baseline and separately measured active source analysis."""
import argparse,hashlib,json,shutil,statistics,subprocess,sys,tempfile
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
from wavez_export import SceneCapture


def fixture(path):
    rng=np.random.default_rng(491);base=rng.uniform(-5,5,(100000,3));ids=np.arange(100000,dtype='i8')+2**53+1
    with SceneCapture(path,objects=[dict(id='p',kind='particles',units='m',identity='persistent_i8')],metadata=dict(time_unit='s',position_unit='m'),compression='zstd') as writer:
        for n in range(81):
            time=n*.5;order=np.roll(np.arange(100000),n*17);positions=base[order]+[.02*time,0,0]
            writer.add_particles('p',time,positions,ids=ids[order],value=np.sin(base[order,0])+time,visual_size=np.full(100000,.03,dtype='f4'))
    return path


def summarize(case):
    rows=case['callbacks'];values=sorted(r['duration_ms'] for r in rows);delta=sorted(r['delta_ms'] for r in rows);transitions=[r['duration_ms'] for r in rows if r['transition']]
    stage=case['stages'];g4=sum(stage.get(k,{}).get('total_ms',0) for k in ['g4_worker_poll','g4_overlay_tick'])
    return dict(name=case['config']['name'],config=case['config'],overlay_gpu_bytes=case.get('overlay_gpu_bytes'),warm_ready_ms=case.get('warm_ready_ms'),seek_calls=len(case.get('seek_calls_ms',[])),seek_max_ms=max(case.get('seek_calls_ms',[]),default=0),export=case.get('analysis',{}).get('data',{}).get('export'),callbacks=len(rows),callback_p50_ms=statistics.median(values),callback_p95_ms=values[int(.95*(len(values)-1))],callback_max_ms=max(values),stalls_50ms=sum(v>=50 for v in values),frame_delta_p50_ms=statistics.median(delta),frame_delta_p95_ms=delta[int(.95*(len(delta)-1))],transition_p50_ms=statistics.median(transitions) if transitions else None,transition_max_ms=max(transitions,default=0),source_advance=rows[-1]['time']-rows[0]['time'],buffering_callbacks=sum(r['buffering'] for r in rows),g4_separate_callback_ms=g4,viewer_rss_peak=case['viewer_rss_peak'],worker_rss_peak=case['worker_rss_peak'],gpu_buffers=case['gpu_buffers'],gpu_textures=case['gpu_textures'],ready_ms=case['ready_ms'],enqueue_ms=case['enqueue_ms'],analysis_metrics=case.get('analysis',{}).get('metrics'),pressure=case.get('analysis',{}).get('playback_pressure'),close_ms=case.get('close_ms'),worker_alive_after_close=case.get('worker_alive_after_close'),trace_dropped=case.get('trace',{}).get('dropped'))


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--godot',required=True);p.add_argument('--output-dir',type=Path,required=True);p.add_argument('--renderer',choices=['gl_compatibility','forward_plus'],required=True);p.add_argument('--capture',type=Path);p.add_argument('--repeats',type=int,default=3);p.add_argument('--resume-active',action='store_true',help='Preserve complete idle repetitions and rerun only interrupted/failed active cases');args=p.parse_args()
    if not 1<=args.repeats<=5:p.error('Use 1–5 repetitions')
    out=args.output_dir.resolve()
    if args.resume_active:
        report=json.loads((out/'report.json').read_text());source=Path(report['capture']);before=report['source_sha256'];baseline=Path(report['baseline_path']);runs=report['runs']
        report.setdefault('prior_active_runs',[]).extend(r for r in runs if r['kind'].startswith('active'))
        runs[:]=[r for r in runs if not r['kind'].startswith('active')]
        if len(runs)!=args.repeats*2 or any(r['backend']!=args.renderer for r in runs) or hashlib.sha256(source.read_bytes()).hexdigest()!=before:raise RuntimeError('Resume requires all matching complete idle runs and unchanged source')
        report['prior_failure']=report.pop('error',report['status'])
    else:
        out.mkdir(parents=True,exist_ok=False);source=args.capture.resolve() if args.capture else fixture(out/'100k.ssc');before=hashlib.sha256(source.read_bytes()).hexdigest()
        baseline=Path(tempfile.mkdtemp(prefix='wavez-g4-g3-baseline-'))
        with (out/'baseline.tar').open('wb') as file:subprocess.run(['git','archive','--format=tar','pre-g4-consolidation'],cwd=ROOT,stdout=file,check=True)
        subprocess.run(['tar','-xf',str(out/'baseline.tar'),'-C',str(baseline)],check=True);(out/'baseline.tar').unlink()
        (baseline/'viewer/analysis').mkdir(exist_ok=True);shutil.copyfile(ROOT/'viewer/analysis/profile_g4.gd',baseline/'viewer/analysis/profile_g4.gd')
        runs=[];report=dict(status='in_progress',capture=str(source),source_sha256=before,baseline_commit=subprocess.check_output(['git','rev-parse','pre-g4-consolidation^{}'],cwd=ROOT,text=True).strip(),baseline_path=str(baseline),runs=runs)
    try:
        for repeat in range(0 if args.resume_active else args.repeats):
            for kind,viewer in [('baseline',baseline/'viewer'),('g4-idle',ROOT/'viewer')]:
                directory=out/(kind+'-'+str(repeat));directory.mkdir();job=dict(capture=str(source),output=str(directory/'profile.json'),cases=[dict(name='hidden',visible=False,seconds=4),dict(name='visible',visible=True,seconds=4)])
                run(args,viewer,directory,job,runs)
        directory=out/('active-retry-'+str(len(list(out.glob('active*')))) if args.resume_active else 'active');directory.mkdir();job=dict(capture=str(source),output=str(directory/'profile.json'),cases=[dict(name='stored-hidden',visible=False,stored=True,seconds=4),dict(name='active-analysis',visible=True,analysis=True,seconds=8)])
        run(args,ROOT/'viewer',directory,job,runs)
        comparisons=[]
        for name in ['hidden','visible']:
            for metric in ['callback_p50_ms','callback_p95_ms','frame_delta_p50_ms','frame_delta_p95_ms']:
                values={kind:statistics.median(next(c[metric] for c in r['cases'] if c['name']==name) for r in runs if r['kind'].startswith(kind+'-')) for kind in ['baseline','g4-idle']}
                comparisons.append(dict(case=name,metric=metric,**values,change_percent=(values['g4-idle']/values['baseline']-1)*100))
        report.update(status='MEASURED; review regression deltas',comparisons=comparisons,source_unchanged=hashlib.sha256(source.read_bytes()).hexdigest()==before)
        if not report['source_unchanged']:raise RuntimeError('Source changed')
    except BaseException as exc:report.update(status='FAIL',error=str(exc));raise
    finally:(out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))


def run(args,viewer,directory,job,runs):
    (directory/'job.json').write_text(json.dumps(job))
    command=[args.godot,'--path',str(viewer),'--resolution','960x640','--rendering-method',args.renderer,'--audio-driver','Dummy','--disable-vsync','--max-fps','120','--log-file',str(directory/'godot.log'),'--script','analysis/profile_g4.gd','--','--g4-profile='+str(directory/'job.json')]
    with (directory/'stdout.log').open('w') as file:r=subprocess.run(command,cwd=ROOT,stdout=file,stderr=subprocess.STDOUT,timeout=180)
    if r.returncode or 'ERROR:' in (directory/'stdout.log').read_text():raise RuntimeError('Profile failed: '+str(directory/'stdout.log'))
    data=json.loads((directory/'profile.json').read_text());cases=[summarize(c) for c in data['cases']]
    if any(c['trace_dropped'] or c['worker_alive_after_close'] for c in cases):raise RuntimeError('Truncated trace or orphan worker')
    runs.append(dict(kind=directory.name,command=command,cases=cases,backend=data['backend'],device=data['device']))


if __name__=='__main__':main()

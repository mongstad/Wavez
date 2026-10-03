"""F09/F10: pinned G4 append, mutation, finite quota and cancelled scene output."""
import argparse,hashlib,json,shutil,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
from tests.g4.fixtures import traveling_pulse
from wavez_export.analysis import SourceSnapshot
from wavez_export.analysis.recipes import unpack,pack


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--godot',required=True);p.add_argument('--output-dir',type=Path,required=True);p.add_argument('--renderer',choices=['gl_compatibility','forward_plus'],required=True);args=p.parse_args()
    root=args.output_dir.resolve();root.mkdir(parents=True,exist_ok=False);checks=[];runs=[];report=dict(status='in_progress',checks=checks,runs=runs,renderer=args.renderer)
    def check(value,label):
        checks.append(dict(label=label,pass_=bool(value)))
        if not value:raise AssertionError(label)
    try:
        for label in ('append','quota','mutation','cancel'):
            directory=root/label;directory.mkdir();full=traveling_pulse(directory/'complete.wvz')
            with SourceSnapshot(full) as source:extent=source.samples['p'][2]['end']
            raw=full.read_bytes();live=directory/'pulse.wvz';live.write_bytes(raw[:extent]);pinned_hash=hashlib.sha256(live.read_bytes()).hexdigest()
            setup=[args.godot,'--headless','--path',str(ROOT/'viewer'),'--log-file',str(directory/'setup-godot.log'),'--script','analysis/test_render_state.gd','--','--g4-render-fixture='+str(directory)]
            result=subprocess.run(setup,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60);(directory/'setup.log').write_text(result.stdout)
            check(result.returncode==0 and 'ERROR:' not in result.stdout,label+' portable pinned setup')
            recipe=json.loads((directory/'recipe.inspection/inspection.json').read_text());base=unpack(recipe['payload'])['base']
            output=directory/'render';output.mkdir();shutil.copytree(directory/'recipe.inspection',output/'recipe.inspection');inspection=output/'recipe.inspection/inspection.json'
            timing=dict(start_time=1.5 if label=='append' else 0.,end_time=1.5 if label=='append' else .75,fps=4,playback_rate=1.)
            job=dict(version=2,capture_path=str(live),source=base['source'],state=base['visual'],exact_state=pack(base['visual']),**timing,exact_timing=pack(timing),width=640,height=360,output_path=str(output/'result.mp4'),camera_mode='locked',orbit_speed=0.,quality='high',keep_frames=True,inspection_sidecars=True,inspection_path=str(inspection),inspection_sha256=hashlib.sha256(inspection.read_bytes()).hexdigest(),opened_paths=[str(live)],output_quota_bytes=str((1 if label=='quota' else 128)*1024**2),test_frame_delay_ms=500 if label=='cancel' else 0)
            if label=='append':
                with live.open('ab') as file:file.write(raw[extent:])
            if label=='mutation':
                changed=bytearray(live.read_bytes());changed[-100]^=1;live.write_bytes(changed)
            expected=hashlib.sha256(live.read_bytes()).hexdigest();path=output/'job.json';path.write_text(json.dumps(job))
            command=[args.godot,'--path',str(ROOT/'viewer'),'--rendering-method',args.renderer,'--resolution','640x360','--audio-driver','Dummy','--log-file',str(output/'godot.log'),'--','--wavez-render-job='+str(path)]
            with (output/'stdout.log').open('w') as file:
                process=subprocess.Popen(command,cwd=ROOT,stdout=file,stderr=subprocess.STDOUT)
                try:
                    if label=='cancel':
                        end=time.monotonic()+30
                        while time.monotonic()<end:
                            try:progress=json.loads((output/'progress.json').read_text())
                            except (OSError,ValueError):progress={}
                            if progress.get('stage')=='rendering' and progress.get('current_frame',0)>=1:break
                            if process.poll() is not None:raise RuntimeError('Renderer ended before cancellation checkpoint')
                            time.sleep(.01)
                        else:raise TimeoutError('Cancellation checkpoint')
                        (output/'cancel').write_text('cancel');start=time.monotonic()
                    code=process.wait(timeout=60)
                finally:
                    if process.poll() is None:process.kill();process.wait()
            progress=json.loads((output/'progress.json').read_text());runs.append(dict(case=label,command=command,exit_code=code,progress=progress))
            if label=='append':
                check(code==0 and progress['stage']=='complete','appended capture renders the original committed extent')
                state=json.loads((output/'inspection-00000000.json').read_text());payload=unpack(state['payload']);frame=payload['base']['render']['selection_frame']
                check(state['source']['sha256']==pinned_hash and int(state['source']['committed_bytes'])==extent,'append does not replace pinned source hash/extent')
                check(payload['base']['source']['complete_frames']==base['source']['complete_frames'],'append does not increase saved frame count')
                check(frame['requested_time']==1.5 and frame['results'][0]['sampling']['a']==frame['results'][0]['sampling']['b'],'last pinned particle sample has no bracket in appended future')
            elif label=='cancel':
                check(code==2 and progress['stage']=='cancelled','cancellation is explicit')
                check(time.monotonic()-start<3,'render cancellation completes within three seconds')
                check(0<progress['current_frame']<3,'completed partial PNGs retained')
                check(not Path(job['output_path']).exists(),'cancelled export never publishes MP4')
            else:
                check(code==1 and progress['stage']=='failed',label+' explicitly refused')
                check(not Path(job['output_path']).exists(),label+' never publishes MP4')
            check(hashlib.sha256(live.read_bytes()).hexdigest()==expected,label+' renderer leaves test input unchanged')
        report['status']='PASS'
    except BaseException as exc:report.update(status='FAIL',error=type(exc).__name__+': '+str(exc));raise
    finally:(root/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'G4 render lifecycle: {len(checks)} checks PASS')


if __name__=='__main__':main()

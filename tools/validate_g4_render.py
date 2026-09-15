"""A18/A20 synthetic selection PNG/clip timing and sidecar acceptance."""
import argparse,hashlib,json,shutil,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
import numpy as np
from PIL import Image
from tests.g4.fixtures import traveling_pulse
from simscope_export.analysis.recipes import unpack,pack


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--godot',required=True);parser.add_argument('--output-dir',required=True,type=Path);parser.add_argument('--renderer',choices=['gl_compatibility','forward_plus'],required=True);args=parser.parse_args()
    root=args.output_dir.resolve();root.mkdir(parents=True,exist_ok=False);source=traveling_pulse(root/'pulse.ssc');digest=hashlib.sha256(source.read_bytes()).hexdigest();runs=[];checks=[]
    def run(command,directory):
        start=time.monotonic();result=subprocess.run(command,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
        (directory/'stdout.log').write_text(result.stdout);runs.append(dict(command=command,exit_code=result.returncode,seconds=time.monotonic()-start))
        if result.returncode or 'ERROR:' in result.stdout:raise RuntimeError('Renderer/test failed: '+str(directory/'stdout.log'))
    def check(condition,label):
        checks.append(dict(label=label,pass_=bool(condition)))
        if not condition:raise AssertionError(label)
    setup=[args.godot,'--headless','--path',str(ROOT/'viewer'),'--audio-driver','Dummy','--log-file',str(root/'setup.log'),'--script','analysis/test_render_state.gd','--','--g4-render-fixture='+str(root)]
    report=dict(status='in_progress',renderer=args.renderer,source_sha256=digest,runs=runs,checks=checks)
    try:
        run(setup,root);recipe=json.loads((root/'recipe.inspection/inspection.json').read_text());base=unpack(recipe['payload'])['base'];images=[]
        for label,delay in [('normal',0),('delayed',125)]:
            directory=root/label;directory.mkdir();shutil.copytree(root/'recipe.inspection',directory/'recipe.inspection');inspection=directory/'recipe.inspection/inspection.json'
            timing=dict(start_time=0.,end_time=.75,fps=4,playback_rate=1.)
            job=dict(version=2,capture_path=str(source),source=base['source'],state=base['visual'],**timing,width=640,height=360,output_path=str(directory/'selection.mp4'),camera_mode='locked',orbit_speed=0.,quality='high',keep_frames=True,inspection_sidecars=True,ffmpeg_path=shutil.which('ffmpeg'),inspection_path=str(inspection),inspection_sha256=hashlib.sha256(inspection.read_bytes()).hexdigest(),opened_paths=[str(source)],output_quota_bytes=str(256*1024**2),exact_timing=pack(timing),test_frame_delay_ms=delay)
            (directory/'job.json').write_text(json.dumps(job))
            run([args.godot,'--path',str(ROOT/'viewer'),'--rendering-method',args.renderer,'--resolution','640x360','--audio-driver','Dummy','--log-file',str(directory/'renderer.log'),'--fixed-fps','4','--disable-vsync','--','--simscope-render-job='+str(directory/'job.json')],directory)
            progress=json.loads((directory/'progress.json').read_text());check(progress['stage']=='complete',label+' complete clip')
            stream=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_entries','stream=width,height,nb_frames,avg_frame_rate','-of','json',job['output_path']]))['streams'][0]
            check((stream['width'],stream['height'],int(stream['nb_frames']),stream['avg_frame_rate'])==(640,360,3,'4/1'),label+' exact clip dimensions/frame count')
            pixels=[]
            for n in range(3):
                path=directory/'frames'/f'frame{n:08d}.png';record=json.loads((directory/f'inspection-{n:08d}.json').read_text());payload=unpack(record['payload']);frame=payload['base']['render']['selection_frame'];resolution=frame['results'][0]
                check(record['version']==3 and record['source']['sha256']==digest and payload['base']['render']['image']['sha256']==hashlib.sha256(path.read_bytes()).hexdigest(),label+f' frame {n} source/image hash')
                check(frame['requested_time']==n/4 and frame['selection_revision']==payload['selections']['revision'],label+f' frame {n} exact time/revision')
                check(resolution['present']==2 and {p['id'] for p in resolution['preview']}=={'0','40'},label+f' frame {n} exact membership')
                for point in resolution['preview']:
                    expected=-.5+int(point['id'])*.05+n/4
                    check(abs(float(point['position'][0]['text'])-expected)<1e-14,label+f' frame {n} independent position oracle ID '+point['id'])
                pixels.append(np.asarray(Image.open(path).convert('RGB')))
                yellow=(pixels[-1][:,:,0]>100)&(pixels[-1][:,:,1]>70)&(pixels[-1][:,:,2]<100)
                check(yellow.sum()>50,label+f' frame {n} visible selection markers on actual GPU')
            images.append(pixels)
        check(all(np.array_equal(a,b) for a,b in zip(*images)),'all PNG pixels identical with delayed rendering')
        run([args.godot,'--path',str(ROOT/'viewer'),'--rendering-method',args.renderer,'--resolution','640x360','--audio-driver','Dummy','--log-file',str(root/'replay.log'),'--script','analysis/test_render_state.gd','--','--g4-render-fixture='+str(root),'--verify-sidecar='+str(root/'normal/inspection-00000001.json')],root)
        check(np.array_equal(np.asarray(Image.open(root/'replayed.png').convert('RGB')),images[0][1]),'restored frame and ordinary PNG capture reproduce exact clip pixels')
        png_recipe=json.loads((root/'replayed.inspection/inspection.json').read_text());png_state=unpack(png_recipe['payload'])
        check(png_state['base']['render']['image']['sha256']==hashlib.sha256((root/'replayed.png').read_bytes()).hexdigest(),'ordinary PNG and portable recipe image hash agree')
        check(hashlib.sha256(source.read_bytes()).hexdigest()==digest,'capture checksum unchanged')
        report['status']='PASS';report['image_inspection_required']=True
    except BaseException as exc:report.update(status='FAIL',error=type(exc).__name__+': '+str(exc));raise
    finally:(root/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'G4 render: {len(checks)} checks PASS; inspect PNGs in {root}')


if __name__=='__main__':main()

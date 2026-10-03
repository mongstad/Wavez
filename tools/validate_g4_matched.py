"""A09/A18/A20: native explicit matched preparation and sequential GPU exports."""
import argparse,hashlib,json,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
import numpy as np
from PIL import Image
from tests.g4.fixtures import traveling_pulse
from wavez_export.analysis.recipes import unpack


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--godot',required=True);p.add_argument('--output-dir',type=Path,required=True);p.add_argument('--renderer',choices=['gl_compatibility','forward_plus'],required=True);args=p.parse_args()
    root=args.output_dir.resolve();root.mkdir(parents=True,exist_ok=False);runs=[];checks=[];report=dict(status='in_progress',renderer=args.renderer,runs=runs,checks=checks)
    def run(command,log):
        start=time.monotonic();r=subprocess.run(command,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180);log.write_text(r.stdout);runs.append(dict(command=command,exit_code=r.returncode,seconds=time.monotonic()-start))
        if r.returncode or 'ERROR:' in r.stdout:raise RuntimeError(str(log))
    def check(value,label):
        checks.append(dict(label=label,pass_=bool(value)))
        if not value:raise AssertionError(label)
    try:
        hashes=[]
        for n,label in enumerate(('left-input','right-input')):
            directory=root/label;directory.mkdir();source=traveling_pulse(directory/'pulse.wvz',time_scale=1 if n==0 else 2,time_offset=0 if n==0 else 10);hashes.append(hashlib.sha256(source.read_bytes()).hexdigest())
            run([args.godot,'--headless','--path',str(ROOT/'viewer'),'--log-file',str(directory/'godot.log'),'--script','analysis/test_render_state.gd','--','--g4-render-fixture='+str(directory),'--g4-render-visible'],directory/'stdout.log')
        run([args.godot,'--path',str(ROOT/'viewer'),'--rendering-method',args.renderer,'--resolution','640x360','--audio-driver','Dummy','--log-file',str(root/'native.log'),'--script','analysis/test_matched_render.gd','--','--matched-fixture='+str(root),'--render-pair'],root/'stdout.log')
        prepared=json.loads((root/'prepared.json').read_text());comparison=unpack(json.loads(Path(prepared['path']).read_text()))
        check(comparison['frames']==3,'native UI prepared three frames per input')
        check([i['source']['sha256'] for i in comparison['inputs']]==hashes,'comparison retains both independent source identities')
        check(comparison['inputs'][0]['source']['uuid']!=comparison['inputs'][1]['source']['uuid'],'equal decimal IDs retain distinct source namespaces')
        images=[];pids=[];first_finished=None
        for n,side in enumerate(('left','right')):
            directory=root/'pair'/side;progress=json.loads((directory/'progress.json').read_text());pids.append(progress['renderer_pid']);check(progress['stage']=='complete',side+' renderer completed')
            timing=[json.loads(line) for line in (directory/'timing.jsonl').read_text().splitlines()];check(len(timing)==3,side+' full timing rows')
            stream=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_entries','stream=width,height,nb_frames,avg_frame_rate','-of','json',str(directory/'matched.mp4')]))['streams'][0]
            check((stream['width'],stream['height'],int(stream['nb_frames']),stream['avg_frame_rate'])==(640,360,3,'4/1'),side+' encoded dimensions/FPS/frame count')
            pixels=[]
            for frame in range(3):
                path=directory/'frames'/f'frame{frame:08d}.png';recipe=json.loads((directory/f'inspection-{frame:08d}.json').read_text());payload=unpack(recipe['payload']);render=payload['base']['render'];c=render['comparison'];resolution=render['selection_frame']['results'][0]
                check(c['frame']['aligned_time']==frame/4 and c['frame']['raw_time']==(frame/4 if n==0 else 10+frame/2),side+f' frame {frame} raw and aligned times')
                clock=timing[frame]['comparison']
                check(clock['side']==side and clock['frame']==c['frame'] and [i['source']['sha256'] for i in clock['inputs']]==hashes,side+f' frame {frame} timing log retains matched provenance')
                check([i['source']['sha256'] for i in c['inputs']]==hashes,side+f' frame {frame} both source provenances')
                check(resolution['present']==2 and {p['id'] for p in resolution['preview']}=={'0','40'},side+f' frame {frame} explicit membership')
                check(all(abs(float(p['position'][0]['text'])-(-.5+int(p['id'])*.05+frame/4))<1e-14 for p in resolution['preview']),side+f' frame {frame} independent physical position oracle')
                check(render['image']['sha256']==hashlib.sha256(path.read_bytes()).hexdigest(),side+f' frame {frame} image checksum')
                pixels.append(np.asarray(Image.open(path).convert('RGB')))
            images.append(pixels)
            if n==0:first_finished=(directory/'progress.json').stat().st_mtime_ns
            else:check((directory/'timing.jsonl').stat().st_mtime_ns>first_finished,'right rendering follows left completion')
        check(pids[0]!=pids[1],'separate sequential scene renderers')
        check(all(np.array_equal(a,b) for a,b in zip(*images)),'matched physical geometry reproduces identical PNG pixels across raw clocks')
        for n,label in enumerate(('left-input','right-input')):check(hashlib.sha256((root/label/'pulse.wvz').read_bytes()).hexdigest()==hashes[n],label+' source unchanged')
        report.update(status='PASS',image_inspection_required=True)
    except BaseException as exc:report.update(status='FAIL',error=type(exc).__name__+': '+str(exc));raise
    finally:(root/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'G4 matched: {len(checks)} checks PASS; inspect PNGs in {root}')


if __name__=='__main__':main()

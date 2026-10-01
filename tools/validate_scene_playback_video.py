"""Compare deterministic export against the frozen pre-optimization viewer."""
import argparse,copy,hashlib,json,subprocess
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--godot',required=True)
    p.add_argument('--baseline-viewer',type=Path,required=True);p.add_argument('--job',type=Path,required=True);p.add_argument('--output-dir',type=Path,required=True)
    a=p.parse_args();out=a.output_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    template=json.loads(a.job.read_text());checks=[]
    def check(ok,name):
        checks.append(dict(name=name,ok=bool(ok)))
        if not ok:raise AssertionError(name)
    for renderer in ['gl_compatibility','forward_plus']:
        for mode in ['baseline','optimized']:
            folder=out/(renderer+'-'+mode);folder.mkdir()
            job=copy.deepcopy(template);job['output_path']=str(folder/'result.mp4')
            path=folder/'job.json';path.write_text(json.dumps(job,indent=2))
            viewer=ROOT/'viewer' if mode=='optimized' else a.baseline_viewer.resolve()
            cmd=[a.godot,'--path',str(viewer),'--resolution','512x384','--rendering-method',renderer,'--audio-driver','Dummy','--log-file',str(folder/'godot.log'),'--','--wavez-render-job='+str(path)]
            r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=120)
            (folder/'stdout.log').write_text(r.stdout)
            check(r.returncode==0 and 'ERROR:' not in r.stdout,renderer+'/'+mode+' native export completed')
            timing=[json.loads(line) for line in (folder/'timing.jsonl').read_text().splitlines()]
            check([row['capture_time'] for row in timing]==[1.25,1.375,1.5,1.625],renderer+'/'+mode+' exact physical output times')
            probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_entries','stream=width,height,nb_frames,avg_frame_rate','-of','json',job['output_path']]))['streams'][0]
            check((probe['width'],probe['height'],int(probe['nb_frames']),probe['avg_frame_rate'])==(512,384,4,'8/1'),renderer+'/'+mode+' MP4 dimensions/count/rate')
            (folder/'ffprobe.json').write_text(json.dumps(probe,indent=2))
            for n in range(4):
                state=json.loads((folder/f'inspection-{n:08d}.json').read_text());image=folder/'frames'/f'frame{n:08d}.png'
                check(state['image']['sha256']==hashlib.sha256(image.read_bytes()).hexdigest(),renderer+'/'+mode+f' frame {n} sidecar hash')
        before=out/(renderer+'-baseline');after=out/(renderer+'-optimized')
        check((before/'timing.jsonl').read_text()==(after/'timing.jsonl').read_text(),renderer+' identical sample/ID/trail/normalization timing records')
        for n in range(4):
            name=f'frame{n:08d}.png'
            check(Image.open(before/'frames'/name).convert('RGBA').tobytes()==Image.open(after/'frames'/name).convert('RGBA').tobytes(),renderer+f' frame {n} identical exported pixels')
            astate=json.loads((before/f'inspection-{n:08d}.json').read_text());bstate=json.loads((after/f'inspection-{n:08d}.json').read_text())
            check(astate['sample']==bstate['sample'] and astate['particle_identity']==bstate['particle_identity'],renderer+f' frame {n} identical scientific sidecar')
    result=dict(checks=checks,failures=sum(not c['ok'] for c in checks))
    (out/'results.json').write_text(json.dumps(result,indent=2)+'\n');print('VIDEO:',len(checks),'checks,',result['failures'],'failures')
if __name__=='__main__':main()

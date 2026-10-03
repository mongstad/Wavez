"""Native redraw-on-change, interaction, scientific-state and offline-isolation checks."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import numpy as np
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture


def fixtures(out):
    for name in ('particles','field','mesh','mixed'):
        objects = []
        if name in ('particles','mixed'):objects.append(dict(id='p',kind='particles',identity='persistent_i8',units='m'))
        if name in ('field','mixed'):objects.append(dict(id='field',kind='volume',units='m'))
        if name in ('mesh','mixed'):objects.append(dict(id='mesh',kind='mesh',identity='stable_topology',units='m'))
        with SceneCapture(out/(name+'.wvz'), objects=objects, compression='none') as writer:
            for time in (0.,.5,1.,1.5,2.):
                points = np.array([[-2,0,0],[2,0,0],[0,3,1]], dtype='f8')+[0,0,time]
                if name in ('particles','mixed'):writer.add_particles('p',time,points,ids=np.array([7,9007199254740993,2**63-1],dtype='i8'))
                if name in ('field','mixed'):
                    z,y,x = np.indices((16,16,16));value=(x+2*y+3*z+time).astype('f8')/100
                    writer.add_volume('field',time,dict(density=value,psi_real=-value),origin=[-4,-4,-4],spacing=[.5,.5,.5])
                if name in ('mesh','mixed'):writer.add_mesh('mesh',time,points,np.array([[0,1,2]]),vertex_channels=dict(vertex_id=np.array([7,8,9],dtype='i8'),value=np.array([0.,.5,1.])))


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot',required=True)
    p.add_argument('--output-dir',type=Path,required=True)
    p.add_argument('--renderer',choices=['forward_plus','gl_compatibility'],default='forward_plus')
    a=p.parse_args();out=a.output_dir.resolve();out.mkdir(parents=True,exist_ok=False);fixtures(out)
    hashes={path.name:hashlib.sha256(path.read_bytes()).hexdigest() for path in out.glob('*.wvz')}
    result=subprocess.run([a.godot,'--path',str(ROOT/'viewer'),'--rendering-method',a.renderer,'--resolution','960x640','--log-file',str(out/'live.log'),
                           '--audio-driver','Dummy','--script','scene/test_render_pacing.gd','--',str(out)],capture_output=True,text=True,timeout=180)
    log=result.stdout+result.stderr;(out/'native.log').write_text(log)
    assert result.returncode==0 and 'ERROR:' not in log and 'RENDER PACING:' in log,log[-6000:]
    report=json.loads((out/'report.json').read_text());assert not report['failures'],report['failures']
    assert hashes=={path.name:hashlib.sha256(path.read_bytes()).hexdigest() for path in out.glob('*.wvz')}
    report['source_hashes_unchanged']=hashes;(out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'Render pacing: {report["checks"]} checks PASS ({a.renderer})')


if __name__=='__main__':main()

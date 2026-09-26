"""Synthetic mesh worker/lifecycle/render regression; optional retained SIMSCP4 input, no solver."""
import argparse, hashlib, json, os, subprocess, sys
from pathlib import Path
import numpy as np
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from simscope_export import SceneCapture
from validate_performance_maintenance import run

def fixtures(out):
    out.mkdir(parents=True, exist_ok=True)
    positions = np.array([[0,0,0],[2,0,0],[2,1,0],[0,1,0]], dtype='f8')
    triangles = np.array([[0,1,2],[0,2,3]], dtype='u4')
    ids = np.array([7,42,9007199254741011,99], dtype='i8')
    for name in ['stable','changing','anonymous','mixed','empty']:
        objects = [dict(id='surface', kind='mesh', units='m', identity='none' if name=='anonymous' else 'stable_topology')]
        if name == 'mixed':
            objects += [dict(id='reflected',kind='mesh',units='m',identity='stable_topology',static=True,data_to_world=[-1,0,0,4,0,1,0,0,0,0,1,0]),dict(id='particles',kind='particles',units='m',identity='persistent_i8'),dict(id='field',kind='volume',units='m')]
        with SceneCapture(out/(name+'.ssc'), objects=objects, compression='zstd') as w:
            for i,t in enumerate([0,.7,1.9,3.0]):
                p=positions.copy();p[:,2]=t*.2*p[:,0]**2
                tri=triangles.copy();vid=ids.copy()
                if name=='changing' and i==1:tri=tri[:,::-1].copy()
                if name=='changing' and i==2:vid=vid[::-1].copy()
                if name=='empty':p=p[:0];tri=tri[:0];vid=vid[:0]
                channels=dict(value=np.arange(len(p),dtype='f8')+t,normal=np.tile([0.,0.,1.],(len(p),1)))
                if name!='anonymous':channels['vertex_id']=vid
                w.add_mesh('surface',t,p,tri,vertex_channels=channels,face_channels=dict(stress=np.arange(len(tri),dtype='f8')+t))
            if name=='mixed':
                w.add_mesh('reflected',1.0,positions,triangles,vertex_channels=dict(vertex_id=ids),face_channels=dict(stress=np.array([.25,.75])))
                for t in [0,1.25,3]:
                    w.add_particles('particles',t,np.array([[t,0,0]],dtype='f8'),ids=np.array([9007199254741011],dtype='i8'))
                    w.add_volume('field',t,{'rho':np.full((2,2,2),t+1,dtype='f8')},origin=[0,0,0],spacing=[1,1,1])
    return out

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot',required=True);p.add_argument('--output-dir',required=True,type=Path)
    p.add_argument('--renderer',choices=['headless','gl_compatibility','forward_plus'],default='headless')
    p.add_argument('--capture',type=Path,help='Optional accepted benchmark 04B capture; read only')
    a=p.parse_args();out=a.output_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    fixture=fixtures(out/'fixtures');job=dict(fixtures=str(fixture),output=str(out/'checks.json'))
    before=None
    if a.capture:
        job['capture']=str(a.capture.resolve());before=hashlib.sha256(a.capture.read_bytes()).hexdigest()
    jobfile=out/'job.json';jobfile.write_text(json.dumps(job))
    os.environ['XDG_DATA_HOME']=str(out/'userdata')
    run(a.godot,ROOT/'viewer','layers/test_mesh_playback.gd',out/'native',['--mesh-playback-job='+str(jobfile)],a.renderer,timeout=300)
    result=json.loads((out/'checks.json').read_text());assert not result['failures'],result['failures']
    if a.capture:assert hashlib.sha256(a.capture.read_bytes()).hexdigest()==before
    print(json.dumps(dict(checks=result['checks'],failures=result['failures'],capture_sha256=before,source_unchanged=True,scientific_solvers_run=0)))
if __name__=='__main__':main()

"""World-scale and rendered-landmark regression for issue #212; tiny WVZ1 inputs only."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import numpy as np
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture
from tools.package_linux import stage, build


def fixtures(out):
    for kind in ['particles', 'mesh', 'volume', 'mixed', 'small', 'large', 'lobes']:
        scale = {'small': .001, 'large': 10000.}.get(kind, 1.)
        kinds = ['particles', 'mesh', 'volume'] if kind in ['mixed', 'small', 'large', 'lobes'] else [kind]
        tx = np.array([[1.7, .2, 0, 13], [0, .8, -.1, -7], [.1, 0, 1.3, 5.]])
        tx[:, 3] *= scale
        objects = [dict(id=k, kind=k, identity='persistent_i8' if k=='particles' else 'stable_topology' if k=='mesh' else 'grid', units='world units', **({} if k=='particles' else dict(data_to_world=tx.ravel().tolist()))) for k in kinds]
        expected_points = []
        with SceneCapture(out/(kind+'.wvz'), objects=objects, compression='none') as w:
            for t in [0., 1.]:
                points = np.array([[-2,0,0],[2,0,0],[0,3,1],[0,0,3]],dtype=float)*scale
                if kind == 'lobes': points[1,0] = 60*scale
                world = points@tx[:,:3].T+tx[:,3]
                if t == 0: expected_points.extend(world.tolist())
                if 'particles' in kinds: w.add_particles('particles',t,world,ids=np.arange(4,dtype='i8'),visual_size=np.full(4,.12*scale),value=np.arange(4,dtype=float)+t)
                if 'mesh' in kinds: w.add_mesh('mesh',t,points,np.array([[0,2,1],[0,1,3],[0,3,2],[1,2,3]]),vertex_channels=dict(vertex_id=np.arange(4,dtype='i8')))
                if 'volume' in kinds:
                    z,y,x=np.indices((12,12,12)); value=np.exp(-((x-4)**2+(y-5)**2+(z-6)**2)/8)+.5*np.exp(-((x-9)**2+(y-8)**2+(z-6)**2)/3)
                    w.add_volume('volume',t,dict(value=value*(1+t)),origin=np.array([-3,-3,-3])*scale,spacing=np.full(3,.6*scale))
                    if t == 0:
                        import itertools
                        corners=np.array(list(itertools.product([-3,3.6],repeat=3)))*scale
                        expected_points.extend((corners@tx[:,:3].T+tx[:,3]).tolist())
        expected=np.array(expected_points)
        (out/(kind+'-bounds.json')).write_text(json.dumps(dict(low=expected.min(axis=0).tolist(), high=expected.max(axis=0).tolist())))


def package(godot, out):
    project=out/'export-source'
    stage(project)
    script=(project/'ui/shell/test_orbit_gizmo.gd').read_text()
    script=script.replace('extends SceneTree','extends Node\nvar root: Window:\n get: return get_tree().root\nvar process_frame: Signal:\n get: return get_tree().process_frame')
    script=script.replace('func _initialize()', 'func _ready()').replace('create_timer(', 'get_tree().create_timer(').replace('quit(', 'get_tree().quit(')
    (project/'review_gizmo.gd').write_text(script)
    (project/'Review.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://review_gizmo.gd" id="1"]\n[node name="Review" type="Node"]\nscript = ExtResource("1")\n')
    config=project/'project.godot';config.write_text(config.read_text().replace('res://Main.tscn','res://Review.tscn'))
    binary=out/'WAVEZ-review.x86_64'
    build(godot,project,binary,out/'build-logs')
    return str(binary)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot',required=True)
    p.add_argument('--output-dir',type=Path,required=True)
    p.add_argument('--renderer',choices=['headless','forward_plus'],default='headless')
    p.add_argument('--project',type=Path,default=ROOT/'viewer')
    p.add_argument('--packaged',action='store_true',help='Run an existing validation-entry package')
    p.add_argument('--export',action='store_true',help='Build a release-template validation-entry package')
    a=p.parse_args();out=a.output_dir.resolve();out.mkdir(parents=True,exist_ok=False);fixtures(out)
    hashes={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in out.glob('*.wvz')}
    env=dict(os.environ,XDG_DATA_HOME=str(out/'userdata'),XDG_CONFIG_HOME=str(out/'config'))
    runtime=package(a.godot,out) if a.export else a.godot
    packaged=a.packaged or a.export
    command=[runtime]
    if not packaged:command+=['--path',str(a.project),'--script','res://ui/shell/test_orbit_gizmo.gd']
    command+=['--headless'] if a.renderer=='headless' else ['--rendering-method',a.renderer]
    command+=['--audio-driver','Dummy','--resolution','1280x900','--','--gizmo-output='+str(out)]
    result=subprocess.run(command,capture_output=True,text=True,env=env,timeout=240)
    log=result.stdout+result.stderr;(out/'native.log').write_text(log)
    assert result.returncode==0 and 'ERROR:' not in log,log[-8000:]
    report=json.loads((out/'report.json').read_text())
    assert not report['failures'],report['failures']
    assert hashes=={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in out.glob('*.wvz')}
    report['source_hashes_unchanged']=hashes
    report['packaged']=packaged
    if packaged:report['package_hashes']={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in [Path(runtime),Path(runtime).with_suffix('.pck')]}
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'Orbit gizmo: {report["checks"]} checks PASS ({a.renderer}); {len(report["pixels"])} rendered landmark comparisons; hashes unchanged')
if __name__=='__main__':main()

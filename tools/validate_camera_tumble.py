"""Focused continuous camera regression using tiny native SIMSCP4 fixtures."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import numpy as np
from simscope_export import SceneCapture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--renderer', choices=['headless', 'forward_plus', 'gl_compatibility'], default='headless')
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    for kind in ['particles', 'volume', 'mesh']:
        with SceneCapture(out / (kind + '.ssc'), objects=[dict(id='object', kind=kind, units='demo units', identity='persistent_i8' if kind == 'particles' else 'stable_topology' if kind == 'mesh' else 'grid')], compression='none') as writer:
            for t in [0., 1.]:
                points = np.array([[-2., 0., 0.], [2., 0., 0.], [0., 3., 1.]]) + [0, 0, t]
                if kind == 'particles':
                    writer.add_particles('object', t, points, ids=np.array([1,2,3], dtype='i8'), visual_size=np.ones(3))
                elif kind == 'volume':
                    z,y,x = np.indices((5,6,7))
                    writer.add_volume('object', t, dict(value=(x+2*y+3*z+t).astype('f8')), origin=[-3,-3,-2], spacing=[1,1,1])
                else:
                    # Closed asymmetric tetrahedron remains visible from both sides of a pole.
                    vertices = np.vstack((points, [0., 0., 3.+t]))
                    faces = np.array([[0,1,2], [0,1,3], [0,2,3], [1,2,3]])
                    for face in faces:
                        a,b,c = vertices[face]
                        if np.dot(np.cross(b-a,c-a), (a+b+c)/3-vertices.mean(axis=0)) < 0:
                            face[1],face[2] = face[2],face[1]
                    writer.add_mesh('object', t, vertices, faces, vertex_channels=dict(vertex_id=np.arange(4, dtype='i8')))
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.ssc')}
    env = os.environ.copy()
    env.update(XDG_DATA_HOME=str(out/'userdata'), XDG_CONFIG_HOME=str(out/'config'))
    def run(name, command):
        result = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True, timeout=150)
        log = result.stdout + result.stderr
        (out/(name+'.log')).write_text(log)
        if result.returncode or any(marker in log for marker in ['ERROR:', 'WARNING:']):
            raise RuntimeError(log[-6000:])
    run('import', [args.godot, '--headless', '--path', 'viewer', '--editor', '--import'])
    renderer = ['--headless'] if args.renderer == 'headless' else ['--rendering-method', args.renderer]
    run('camera', [args.godot, '--path', 'viewer', *renderer, '--resolution', '960x640', '--audio-driver', 'Dummy', '--script', 'res://scene/test_camera_tumble.gd', '--', '--camera-output='+str(out)])
    assert hashes == {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.ssc')}, 'Capture bytes changed'
    report = json.loads((out/'camera-report.json').read_text())
    assert not report['failures'], report
    report['source_hashes_unchanged'] = hashes
    (out/'camera-report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'Camera tumble: {report["checks"]} checks PASS ({args.renderer}); capture hashes unchanged')


if __name__ == '__main__':
    main()

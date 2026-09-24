"""Native #68 ownership, multi-object context and disclosure checks on tiny captures."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from simscope_export import SceneCapture


def fixture(path, kinds):
    objects = []
    if 'particles' in kinds:
        objects.append(dict(id='p', kind='particles', identity='persistent_i8', units='m'))
    for kind in ['volume', 'mesh']:
        if kind in kinds:
            objects += [dict(id=f'{kind}{n}', kind=kind, units='m', **({'identity':'none'} if kind == 'mesh' else {})) for n in range(2)]
    with SceneCapture(path, objects=objects, metadata={'type_labels': {
        '0': 'Density-seeded passive tracers', '1': 'Coverage-seeded passive tracers'}}) as writer:
        for t in [0., 1.]:
            for obj in objects:
                if obj['kind'] == 'particles':
                    writer.add_particles(obj['id'], t, np.array([[0.,0.,0.],[1.,0.,0.]]),
                                         ids=np.array([7, 9007199254740993], dtype='i8'),
                                         value=np.array([.25,.75]), particle_type=np.array([0,1],dtype='u4'))
                elif obj['kind'] == 'volume':
                    writer.add_volume(obj['id'], t, {'value': np.arange(8,dtype='f8').reshape(2,2,2),
                                      'other': np.ones((2,2,2))}, origin=[0,0,0], spacing=[1,1,1])
                else:
                    writer.add_mesh(obj['id'], t, np.array([[0.,0.,0.],[1.,0.,0.],[0.,1.,0.]]),
                                    [[0,1,2]], vertex_channels={'value':np.array([.1,.5,.9])})


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--output-dir', required=True, type=Path)
    p.add_argument('--renderer', choices=['gl_compatibility','forward_plus'], default='gl_compatibility')
    p.add_argument('--startup-capture', action='store_true', help='Launch directly into a capture to check fresh-session disclosure defaults.')
    args = p.parse_args()
    out = args.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    fixture(out/'mixed.ssc', ['particles','volume','mesh'])
    fixture(out/'mixed-replacement.ssc', ['particles','volume','mesh'])
    fixture(out/'fields.ssc', ['volume'])
    fixture(out/'particles.ssc', ['particles'])
    hashes = {f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in out.glob('*.ssc')}
    run = subprocess.run([args.godot, '--path', str(ROOT/'viewer'), '--rendering-method', args.renderer,
                          '--audio-driver','Dummy','--resolution','1440x900', '--script',
                          'ui/shell/test_simulation_panel.gd','--',str(out)] +
                         (['--capture='+str(out/'mixed.ssc')] if args.startup_capture else []), text=True,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=150)
    (out/'native.log').write_text(run.stdout)
    if run.returncode or 'ERROR:' in run.stdout or 'WARNING:' in run.stdout:
        raise RuntimeError(f'Panel regression failed: {out}/native.log')
    report = json.loads((out/'report.json').read_text())
    assert not report['failures'],report['failures']
    assert hashes == {f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in out.glob('*.ssc')}
    report['source_hashes_unchanged'] = hashes
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'Simulation panel: {report["checks"]} PASS ({args.renderer}); sources unchanged')

if __name__ == '__main__':
    main()

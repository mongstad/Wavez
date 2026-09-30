"""Native custom-orbit interaction and complete synthetic source invariance."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import subprocess
import sys
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from simscope_export import SceneCapture
from tests.g4.fixtures import scene


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility', 'headless'], default='forward_plus')
    parser.add_argument('--baseline-log', type=Path, help='Explicit matched accepted-main GL teardown comparison; all other diagnostics still fail')
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    scene(out / 'mixed.ssc')
    for kind in ['particles', 'volume', 'mesh']:
        identity = 'persistent_i8' if kind == 'particles' else 'stable_topology' if kind == 'mesh' else 'grid'
        with SceneCapture(out / (kind + '.ssc'), objects=[dict(id='object', kind=kind, units='m', identity=identity)], compression='none') as writer:
            for t in [0., 1.]:
                points = np.array([[-2., 0., 0.], [2., 0., 0.], [0., 3., 1.]]) + [1300, -100, 3439+t]
                if kind == 'particles':
                    writer.add_particles('object', t, points, ids=np.array([1, 2, 3], dtype='i8'), visual_size=np.ones(3))
                elif kind == 'volume':
                    z, y, x = np.indices((5, 6, 7))
                    writer.add_volume('object', t, dict(value=(x+2*y+3*z+t).astype('f8')), origin=[1297, -103, 3437], spacing=[1, 1, 1])
                else:
                    writer.add_mesh('object', t, np.vstack((points, [1300., -100., 3442.+t])), np.array([[0, 1, 2], [0, 1, 3], [0, 2, 3], [1, 2, 3]]), vertex_channels=dict(vertex_id=np.arange(4, dtype='i8')))
    for name, scale in [('mesh-small-scale', .01), ('mesh-large-scale', 1000.)]:
        with SceneCapture(out / (name+'.ssc'), objects=[dict(id='object', kind='mesh', units='m', identity='stable_topology')], compression='none') as writer:
            for t in [0., 1.]:
                points = (np.array([[-2., 0., 0.], [2., 0., 0.], [0., 3., 1.], [0., 0., 3.]]) + [1300, -100, 3439+t]) * scale
                writer.add_mesh('object', t, points, np.array([[0, 1, 2], [0, 1, 3], [0, 2, 3], [1, 2, 3]]), vertex_channels=dict(vertex_id=np.arange(4, dtype='i8')))
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.ssc')}
    env = os.environ.copy()
    env.update(XDG_DATA_HOME=str(out/'userdata'), XDG_CONFIG_HOME=str(out/'config'))
    backend = ['--headless'] if args.renderer == 'headless' else ['--rendering-method', args.renderer]
    command = [args.godot, '--path', str(ROOT/'viewer'), *backend, '--resolution', '1440x900', '--audio-driver', 'Dummy', '--script', 'res://scene/test_orbit_setup.gd', '--', str(out)]
    with (out/'native.log').open('w') as stream:
        result = subprocess.run(command, cwd=ROOT, env=env, text=True, stdout=stream, stderr=subprocess.STDOUT, timeout=180)
    log = (out/'native.log').read_text()
    report = json.loads((out/'report.json').read_text())
    assert hashes == {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.ssc')}, 'Capture bytes changed'
    report['source_hashes_unchanged'] = hashes
    errors = re.findall(r'^(?:ERROR|SCRIPT ERROR): .*$', log, flags=re.MULTILINE)
    matched = False
    if errors and args.baseline_log and args.renderer == 'gl_compatibility':
        baseline = re.findall(r'^ERROR: .*$', args.baseline_log.read_text(), flags=re.MULTILINE)
        # GL resource IDs depend on runtime allocation order; leak type/size and
        # count must match the retained accepted-main probe exactly.
        pattern = r'ERROR: Texture with GL ID of \d+: leaked \d+ bytes\.'
        normalize = lambda values: sorted(re.sub(r'GL ID of \d+', 'GL ID of <runtime>', v) for v in values)
        matched = bool(baseline) and all(re.fullmatch(pattern, e) for e in errors+baseline) and normalize(errors) == normalize(baseline)
    report['runtime'] = dict(exit_code=result.returncode, errors=errors, clean_log=not errors and 'WARNING:' not in log,
                             matched_accepted_main_gl_teardown=matched)
    (out/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    assert not report['failures'], report['failures']
    assert result.returncode == 0 and (not errors or matched) and 'WARNING:' not in log, out/'native.log'
    suffix = '; matched accepted-main GL teardown diagnostics remain' if matched else ''
    print(f'Orbit setup: {report["checks"]} checks PASS ({args.renderer}); {len(hashes)} complete capture hashes unchanged{suffix}')


if __name__ == '__main__':
    main()

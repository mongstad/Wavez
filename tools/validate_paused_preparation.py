"""Issue #204: exercise paused startup and shared scene preparation on WVZ1 fixtures."""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture


def fixtures(out, large=False):
    if large:
        values = np.linspace(0, 1, 192**3, dtype='f4').reshape(192, 192, 192)
        with SceneCapture(out / 'large-field.wvz', objects=[dict(id='field', kind='volume', units='m')],
                          compression='zstd', compression_level=1) as writer:
            for t in (0., 1., 2.):
                writer.add_volume('field', t, {'density': values + t, 'psi_real': values*.5 + t,
                                               'psi_imag': -values + t}, origin=[0, 0, 0], spacing=[1, 1, 1])
        axis = np.arange(256, dtype='f8')
        xx, yy = np.meshgrid(axis, axis)
        positions = np.column_stack((xx.ravel(), yy.ravel(), np.zeros(xx.size)))
        index = np.arange(255*255, dtype='u4')
        row = index // 255
        col = index % 255
        corner = row*256 + col
        triangles = np.concatenate((np.column_stack((corner, corner+1, corner+256)),
                                    np.column_stack((corner+1, corner+257, corner+256)))).astype('u4')
        with SceneCapture(out / 'large-mesh.wvz', objects=[dict(id='mesh', kind='mesh', units='m',
                                                                identity='stable_topology')],
                          compression='zstd', compression_level=1) as writer:
            for t in (0., 1., 2., 3.):
                moved = positions.copy()
                moved[:, 2] = t * .1 * (xx.ravel()/255)
                writer.add_mesh('mesh', t, moved, triangles,
                                vertex_channels={'vertex_id': np.arange(len(moved), dtype='i8'),
                                                 'scalar': (xx.ravel()/255 + t).astype('f8')})
        return
    objects = {
        'particles': dict(id='particles', kind='particles', units='m', identity='persistent_i8'),
        'field': dict(id='field', kind='volume', units='m'),
        'mesh': dict(id='mesh', kind='mesh', units='m', identity='stable_topology'),
    }
    for name, kinds in [('particles', ['particles']), ('field', ['field']),
                        ('mesh', ['mesh']), ('mixed', list(objects))]:
        with SceneCapture(out / f'{name}.wvz', objects=[objects[k] for k in kinds]) as writer:
            for t in (0., 1., 2., 3.):
                if 'particles' in kinds:
                    writer.add_particles('particles', t, np.array([[t, 0, 0], [t, 1, 0]], 'f8'),
                                         ids=np.array([7, 42], 'i8'))
                if 'field' in kinds:
                    writer.add_volume('field', t, {'density': np.full((8, 8, 8), t + 1, 'f4')},
                                      origin=[0, 0, 0], spacing=[1, 1, 1])
                if 'mesh' in kinds:
                    writer.add_mesh('mesh', t, np.array([[t, 0, 0], [t + 1, 0, 0], [t, 1, 0]], 'f8'),
                                    np.array([[0, 1, 2]], 'u4'),
                                    vertex_channels={'vertex_id': np.array([1, 2, 3], 'i8')})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['forward_plus'], required=True)
    parser.add_argument('--hold-seconds', type=float, default=5.)
    parser.add_argument('--large', action='store_true', help='Use synthetic 192-cubed fields and 256x256 meshes')
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    fixtures(out, args.large)
    before = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in out.glob('*.wvz')}
    command = [args.godot, '--path', str(ROOT / 'viewer'), '--audio-driver', 'Dummy',
               '--rendering-method', args.renderer, '--resolution', '960x640',
               '--disable-vsync', '--script', 'layers/test_paused_preparation.gd',
               '--', f'--paused-fixture={out}', f'--hold-seconds={args.hold_seconds}',
               f'--large={int(args.large)}']
    try:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, timeout=max(300 if args.large else 120, args.hold_seconds * 4 + 60))
    except subprocess.TimeoutExpired as exc:
        (out / 'native.log').write_bytes(exc.stdout or b'')
        raise
    (out / 'native.log').write_text(result.stdout)
    report = json.loads((out / 'report.json').read_text())
    unchanged = all(hashlib.sha256((out / name).read_bytes()).hexdigest() == digest
                    for name, digest in before.items())
    print(json.dumps({'renderer': args.renderer, 'exit_code': result.returncode,
                      'checks': report['checks'], 'failures': report['failures'],
                      'hold_seconds': args.hold_seconds, 'large': args.large,
                      'sources_unchanged': unchanged}, indent=2))
    if result.returncode or report['failures'] or not unchanged or 'ERROR:' in result.stdout:
        print(result.stdout)
        raise SystemExit(1)


if __name__ == '__main__':
    main()

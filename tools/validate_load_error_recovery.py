"""Focused native load-error ownership/recovery checks; synthetic WVZ1 inputs only."""
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
from tests.g4.fixtures import scene
from wavez_export import SceneCapture, SceneReader


def fixtures(out):
    for name in ('scene.wvz', 'replacement.wvz'):
        scene(out / name)
    (out / 'invalid.wvz').write_bytes(b'not a WVZ1 capture')
    (out / 'unsupported.txt').write_text('unsupported capture')
    corrupt = out / 'duplicate.wvz'
    with SceneCapture(corrupt, objects=[dict(id='p', kind='particles', units='m',
                                           identity='persistent_i8')], compression='none') as writer:
        writer.add_particles('p', 0, np.array([[0., 0, 0], [1., 1, 1]], dtype='f8'),
                             ids=np.array([1, 2], dtype='i8'))
    # Keep the descriptor/commit valid and inject a payload-level ID failure.
    # Interactive opening checks ID validity while decoding the initial sample.
    with SceneReader(corrupt) as reader:
        row = reader.samples['p'][0]
        ids = next(a for a in row['descriptor']['arrays'] if a['name'] == 'particle_id')
        offset = row['offset'] + int(ids['chunks'][0]['offset'])
    with corrupt.open('r+b') as file:
        file.seek(offset)
        file.write(np.array([1, 1], dtype='i8').tobytes())
    return [out / name for name in ('scene.wvz', 'replacement.wvz', 'invalid.wvz',
                                    'duplicate.wvz', 'unsupported.txt')]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], default='forward_plus')
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    sources = fixtures(out)
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
    env = os.environ.copy()
    env['XDG_DATA_HOME'] = str(out / 'user-data')
    command = [args.godot, '--path', str(ROOT / 'viewer'), '--rendering-method', args.renderer,
               '--audio-driver', 'Dummy', '--resolution', '1440x900', '--log-file', str(out / 'engine.txt'),
               '--script', 'res://ui/shell/test_load_error_recovery.gd', '--', '--load-output=' + str(out)]
    result = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True, timeout=90)
    log = result.stdout + result.stderr
    (out / 'stdout.txt').write_text(log)
    report = json.loads((out / 'report.json').read_text()) if (out / 'report.json').exists() else {}
    report['process_exit_code'] = result.returncode
    report['source_hashes_before'] = hashes
    report['source_hashes_after'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
    report['source_hashes_unchanged'] = report['source_hashes_after'] == hashes
    (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    assert result.returncode == 0 and 'ERROR:' not in log and 'WARNING:' not in log, out / 'stdout.txt'
    assert not report['failures'] and report['source_hashes_unchanged'], report
    assert len(list(out.glob('*.png'))) == 16, 'Expected failed/recovered/details evidence in both layouts'
    print(f'Load recovery: {report["checks"]} checks PASS ({args.renderer}); 16 screenshots; source hashes unchanged')


if __name__ == '__main__':
    main()

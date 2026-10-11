"""Measure actual WVZ1 particle cache coverage, accounting, reuse and pressure."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture
import numpy as np


def fixture(path):
    n = 256
    with SceneCapture(path, objects=[dict(id='particles', kind='particles', units='m',
                                          identity='persistent_i8')]) as writer:
        for index in range(41):
            pos = np.zeros((n, 3), dtype='f4')
            pos[:, 0] = np.arange(n) * .01
            pos[:, 1] = index * .01
            channels = {f'scalar_{i}': np.full(n, index+i, dtype='f4') for i in range(10)}
            writer.add_particles('particles', index*.2, pos, ids=np.arange(n, dtype='i8'),
                                 velocity=pos*.1, particle_type=np.zeros(n, dtype='u4'), **channels)


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--capture', type=Path)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['headless', 'forward_plus'], default='headless')
    parser.add_argument('--packaged', action='store_true')
    args = parser.parse_args()
    out = args.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    source = args.capture.resolve() if args.capture else out/'particles.wvz'
    if not args.capture: fixture(source)
    before = digest(source)
    env = dict(os.environ, XDG_DATA_HOME=str(out/'data'), XDG_CONFIG_HOME=str(out/'config'))
    command = [args.godot, '--audio-driver', 'Dummy']
    if not args.packaged: command += ['--path', str(ROOT/'viewer')]
    command += ['--headless'] if args.renderer == 'headless' else ['--rendering-method', args.renderer, '--resolution', '960x640']
    if not args.packaged: command += ['--script', 'layers/test_particle_cache.gd']
    command += ['--', str(source), str(out/'report.json')]
    with (out/'native.log').open('w') as log:
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, env=env, timeout=480)
    report = json.loads((out/'report.json').read_text())
    unchanged = before == digest(source)
    summary = dict(renderer=args.renderer, packaged=args.packaged, exit_code=result.returncode,
                   checks=report['checks'], failures=report['failures'], source_sha256=before,
                   source_unchanged=unchanged)
    (out/'summary.json').write_text(json.dumps(summary, indent=2)+'\n')
    print(json.dumps(summary, indent=2))
    if result.returncode or report['failures'] or not unchanged or 'ERROR:' in (out/'native.log').read_text():
        raise SystemExit(1)


if __name__ == '__main__':
    main()

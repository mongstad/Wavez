"""Bounded 192-cubed, three-channel regression; never runs an external solver."""
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


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], required=True)
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    capture = out / 'large.wvz'
    if capture.exists():
        parser.error('Use a fresh output directory; existing captures are preserved')
    values = np.linspace(.1, 1, 192**3, dtype='f4').reshape(192, 192, 192)
    frames = []
    objects = [dict(id='p', kind='particles', identity='persistent_i8', units='m'),
               dict(id='field', kind='volume', units='m')]
    with SceneCapture(capture, objects=objects, compression='zstd', compression_level=1) as writer:
        for time in range(3):
            channels = dict(density=values+time, psi_real=values*.5+time, psi_imag=-values+time)
            writer.add_particles('p', time, np.zeros((50000, 3), dtype='f4'),
                                 ids=np.arange(50000, dtype='i8'), value=np.ones(50000, dtype='f4'))
            writer.add_volume('field', time, channels, origin=[0, 0, 0], spacing=[1, 1, 1])
            frames.append({key: hashlib.sha256(value.tobytes()).hexdigest() for key, value in channels.items()})
    (out / 'oracle.json').write_text(json.dumps(frames))
    multiple = out / 'multiple.wvz'
    with SceneCapture(multiple, objects=[dict(id=name, kind='volume', units='m')
                                        for name in ['a', 'b']]) as writer:
        for time in range(2):
            for name in ['a', 'b']:
                writer.add_volume(name, time, dict(density=np.ones((2, 2, 2), dtype='f4')),
                                  origin=[0, 0, 0], spacing=[1, 1, 1])
    before = digest(capture)
    multiple_before = digest(multiple)
    command = [args.godot, '--path', str(ROOT / 'viewer'), '--rendering-method', args.renderer,
               '--audio-driver', 'Dummy', '--resolution', '960x640',
               '--script', 'layers/test_field_budget.gd', '--', str(out)]
    result = subprocess.run(command, capture_output=True, text=True, timeout=180)
    log = result.stdout + result.stderr
    (out / 'native.log').write_text(log)
    unchanged = digest(capture) == before and digest(multiple) == multiple_before
    (out / 'source.json').write_text(json.dumps(dict(sha256=before, unchanged=unchanged), indent=2))
    print(log)
    if result.returncode or 'ERROR:' in log or not unchanged:
        raise SystemExit(1)


if __name__ == '__main__':
    main()

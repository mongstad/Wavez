"""Exact descriptor grammar and immutable identity reuse regression."""
import argparse
import hashlib
from pathlib import Path
import subprocess
import sys

import numpy as np
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from simscope_export import SceneCapture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    source = out / 'identity.ssc'
    large = 9007199254740993
    cases = [[0, large, 9223372036854775807], [0, large, 9223372036854775807],
             [9223372036854775807, large, 0], [4, large, 0]]
    with SceneCapture(source, objects=[dict(id='p', kind='particles', identity='persistent_i8', units='u')]) as writer:
        for index, ids in enumerate(cases):
            writer.add_particles('p', index, np.zeros((3, 3), dtype='f4'), ids=np.array(ids, dtype='i8'))
    before = hashlib.sha256(source.read_bytes()).hexdigest()
    result = subprocess.run([args.godot, '--headless', '--path', str(ROOT / 'viewer'),
                             '--log-file', str(out / 'godot.log'), '--script', 'layers/test_load_optimizations.gd', '--', str(out)],
                            capture_output=True, text=True, timeout=120)
    log = result.stdout + result.stderr
    (out / 'native.log').write_text(log)
    print(log)
    assert result.returncode == 0 and 'ERROR:' not in log
    assert hashlib.sha256(source.read_bytes()).hexdigest() == before


if __name__ == '__main__':
    main()

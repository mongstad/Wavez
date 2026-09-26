"""Full-field admission, cancellation, retention and temporal/source correctness."""
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


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--output-dir', type=Path, required=True)
    p.add_argument('--renderer', default='headless', choices=['headless', 'forward_plus', 'gl_compatibility'])
    a = p.parse_args()
    out = a.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    source = out / 'session.ssc'
    oracle = []
    gpu_oracle = []
    with SceneCapture(source, objects=[dict(id='field', kind='volume', units='m')], compression='zstd') as writer:
        for i in range(20):
            channels = dict(density=(np.arange(32**3, dtype='f4') / 32768 + i).reshape(32, 32, 32),
                            signed=(np.arange(32**3, dtype='f4') / 16384 - 1 - i/32).reshape(32, 32, 32),
                            exact=np.full((32, 32, 32), 1+i/32, dtype='f8'))
            writer.add_volume('field', i*.1, channels, origin=[0, 0, 0], spacing=[1, 1, 1])
            oracle.append({k: hashlib.sha256(v.tobytes()).hexdigest() for k, v in channels.items()})
            gpu_oracle.append({k: hashlib.sha256(v.astype('f4').tobytes()).hexdigest() for k, v in channels.items()})
    (out / 'oracle.json').write_text(json.dumps(oracle))
    (out / 'gpu-oracle.json').write_text(json.dumps(gpu_oracle))
    before = hashlib.sha256(source.read_bytes()).hexdigest()
    cmd = [a.godot, '--path', str(ROOT / 'viewer'), '--audio-driver', 'Dummy', '--log-file', str(out / 'godot.log')]
    cmd += ['--headless'] if a.renderer == 'headless' else ['--rendering-method', a.renderer, '--resolution', '1280x800']
    cmd += ['--script', 'layers/test_field_session.gd', '--', str(out)]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    log = result.stdout + result.stderr; (out / 'native.log').write_text(log); print(log)
    assert result.returncode == 0 and 'ERROR:' not in log
    assert hashlib.sha256(source.read_bytes()).hexdigest() == before


if __name__ == '__main__':
    main()

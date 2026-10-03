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
from wavez_export import SceneCapture


def fixture(out):
    source = out / 'session.wvz'
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
    with SceneCapture(out/'late.wvz', objects=[dict(id='p', kind='particles', identity='anonymous', units='m'),
                                              dict(id='field', kind='volume', units='u')]) as writer:
        for t in (0., 2.):writer.add_particles('p', t, np.zeros((1, 3), dtype='f4'))
        for t in (.4, .8, 1.2):writer.add_volume('field', t, dict(rho=np.ones((2, 2, 2), dtype='f4')), origin=[0]*3, spacing=[1]*3)
    old_prefix = bytearray(source.read_bytes()); old_prefix[:8] = b'SIMSCP3\0'; old_prefix[8:12] = (3).to_bytes(4, 'little')
    (out/'unsupported-v3.wvz').write_bytes(old_prefix)
    old_prefix = bytearray(source.read_bytes()); old_prefix[:8] = b'SIMSCP4\0'; old_prefix[8:12] = (4).to_bytes(4, 'little')
    (out/'unsupported-v4.wvz').write_bytes(old_prefix)
    (out/'obsolete-suffix.ssc').write_bytes(source.read_bytes())
    return source


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--output-dir', type=Path, required=True)
    p.add_argument('--renderer', default='headless', choices=['headless', 'forward_plus', 'gl_compatibility'])
    a = p.parse_args()
    out = a.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    source = fixture(out)
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

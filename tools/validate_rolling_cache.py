"""Rolling cache pressure, protected ownership, prepared coverage and source fidelity."""
import argparse
import hashlib
import subprocess
from pathlib import Path
from validate_field_session import ROOT, fixture, SceneCapture
import numpy as np


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['headless', 'forward_plus', 'gl_compatibility'], default='headless')
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    source = fixture(out)
    before = hashlib.sha256(source.read_bytes()).hexdigest()
    with SceneCapture(out/'mixed.wvz', objects=[dict(id='p', kind='particles', identity='anonymous', units='m'), dict(id='field', kind='volume', units='m')]) as writer:
        for t in (0., .01, .02, .03, .04, .05, .06, .07, .08, .5, 1., 2.):
            writer.add_particles('p', t, np.zeros((2, 3), dtype='f4'))
        for t in (0., 1., 2.):
            writer.add_volume('field', t, dict(rho=np.ones((2, 2, 2), dtype='f4')), origin=[0]*3, spacing=[1]*3)
    command = [args.godot, '--path', str(ROOT/'viewer'), '--audio-driver', 'Dummy']
    command += ['--headless'] if args.renderer == 'headless' else ['--rendering-method', args.renderer, '--resolution', '960x640']
    command += ['--script', 'layers/test_rolling_cache.gd', '--', str(out)]
    result = subprocess.run(command, capture_output=True, text=True, timeout=120)
    log = result.stdout+result.stderr
    (out/'native.log').write_text(log)
    print(log)
    assert not result.returncode and 'ERROR:' not in log
    assert hashlib.sha256(source.read_bytes()).hexdigest() == before


if __name__ == '__main__':
    main()

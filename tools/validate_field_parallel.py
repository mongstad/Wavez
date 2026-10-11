"""Bounded field pool race, source and plane equality regressions."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from validate_field_session import fixture


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--output-dir', type=Path, required=True)
    p.add_argument('--renderer', default='headless', choices=['headless', 'forward_plus'])
    a = p.parse_args()
    out = a.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    source = fixture(out)
    before = hashlib.sha256(source.read_bytes()).hexdigest()
    cmd = [a.godot, '--path', str(ROOT / 'viewer'), '--audio-driver', 'Dummy', '--log-file', str(out / 'godot.log')]
    cmd += ['--headless'] if a.renderer == 'headless' else ['--rendering-method', a.renderer, '--resolution', '1280x800']
    cmd += ['--script', 'layers/test_field_parallel.gd', '--', str(out)]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    log = result.stdout + result.stderr; (out / 'native.log').write_text(log); print(log)
    assert result.returncode == 0 and 'ERROR:' not in log
    report = json.loads((out/'parallel-results.json').read_text())
    assert not report['failures']
    assert source.read_bytes()[-1:] == b'\0'  # The final race intentionally appends to this synthetic fixture.
    assert hashlib.sha256(source.read_bytes()[:-1]).hexdigest() == before


if __name__ == '__main__':
    main()

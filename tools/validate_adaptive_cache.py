"""Automatic bounded windows, overlap reuse, pressure recovery and source fidelity."""
import argparse
import hashlib
import subprocess
from pathlib import Path
from validate_field_session import ROOT, fixture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['headless', 'forward_plus'], default='headless')
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    source = fixture(out)
    before = hashlib.sha256(source.read_bytes()).hexdigest()
    command = [args.godot, '--path', str(ROOT/'viewer'), '--audio-driver', 'Dummy']
    command += ['--headless'] if args.renderer == 'headless' else ['--rendering-method', args.renderer, '--resolution', '960x640']
    command += ['--script', 'layers/test_adaptive_cache.gd', '--', str(out)]
    result = subprocess.run(command, capture_output=True, text=True, timeout=120)
    log = result.stdout+result.stderr
    (out/'native.log').write_text(log)
    print(log)
    assert not result.returncode and 'ERROR:' not in log
    assert hashlib.sha256(source.read_bytes()).hexdigest() == before


if __name__ == '__main__':
    main()

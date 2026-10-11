"""Native #147 boolean semantics, Details routing, logo and rebuild regressions."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.validate_simulation_panel import fixture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--renderer', choices=['forward_plus'], default='forward_plus')
    args = parser.parse_args()
    out = args.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    for name, kinds in [('mixed', ['particles', 'volume', 'mesh']), ('particles', ['particles'])]:
        fixture(out / (name + '.wvz'), kinds)
    hashes = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in out.glob('*.wvz')}
    result = subprocess.run([
        args.godot, '--path', str(ROOT / 'viewer'), '--rendering-method', args.renderer,
        '--resolution', '1440x900', '--audio-driver', 'Dummy', '--log-file', str(out / 'godot.log'),
        '--script', 'ui/shell/test_violet_cleanup.gd', '--', str(out),
    ], capture_output=True, text=True, timeout=130)
    log = result.stdout + result.stderr; (out / 'native.log').write_text(log)
    if result.returncode or 'ERROR:' in log or 'WARNING:' in log:
        raise RuntimeError(f'Cleanup regression failed: {out / "native.log"}')
    report = json.loads((out / 'report.json').read_text())
    assert not report['failures'], report['failures']
    assert hashes == {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in out.glob('*.wvz')}
    assert hashlib.sha256((ROOT / 'viewer/ui/about/wavez-logo-dark.png').read_bytes()).hexdigest() == '4398a96d6aaf89733417d5c6c204c1d0238751bee07ad5250a63bcce1ef21aa3'
    report['source_hashes_unchanged'] = hashes
    (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'Violet cleanup: {report["checks"]} PASS ({args.renderer}); complete sources unchanged')


if __name__ == '__main__':
    main()

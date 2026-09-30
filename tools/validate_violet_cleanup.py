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
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], default='forward_plus')
    args = parser.parse_args()
    out = args.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    for name, kinds in [('mixed', ['particles', 'volume', 'mesh']), ('particles', ['particles'])]:
        fixture(out / (name + '.ssc'), kinds)
    hashes = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in out.glob('*.ssc')}
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
    assert hashes == {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in out.glob('*.ssc')}
    assert hashlib.sha256((ROOT / 'viewer/ui/about/simscope-logo.png').read_bytes()).hexdigest() == 'b666a782e6f3a482ae8e87bee5231aaaa7b7711e4d2ba7a91362f7cbdc6e9722'
    report['source_hashes_unchanged'] = hashes
    (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'Violet cleanup: {report["checks"]} PASS ({args.renderer}); complete sources unchanged')


if __name__ == '__main__':
    main()

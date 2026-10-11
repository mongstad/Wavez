"""Native #143 style slice, contrast, component state and isolation checks."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tests.g4.fixtures import scene


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['forward_plus'], default='forward_plus')
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    source = out / 'scene.wvz'
    scene(source)
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    result = subprocess.run([
        args.godot, '--path', str(ROOT / 'viewer'), '--rendering-method', args.renderer,
        '--resolution', '1440x900', '--audio-driver', 'Dummy', '--log-file', str(out / 'godot.log'),
        '--script', 'ui/shell/test_violet_style_slice.gd', '--', str(out),
    ], capture_output=True, text=True, timeout=60)
    log = result.stdout + result.stderr
    (out / 'stdout.log').write_text(log)
    if result.returncode or 'ERROR:' in log or 'WARNING:' in log:
        raise RuntimeError(f'Style slice failed; see {out / "stdout.log"}')
    report = json.loads((out / 'report.json').read_text())
    assert not report['failures'], report['failures']
    assert digest == hashlib.sha256(source.read_bytes()).hexdigest()
    report['source_sha256_unchanged'] = digest
    (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'Violet slice: {report["checks"]} checks PASS ({args.renderer}); source unchanged')


if __name__ == '__main__':
    main()

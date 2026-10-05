"""Exercise live viewport-only Save Image with tiny particle, field and mesh captures."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

from validate_simulation_panel import fixture

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--renderer', choices=['gl_compatibility', 'forward_plus'], required=True)
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    for name, kinds in [('particles', ['particles']), ('fields', ['volume']),
                        ('meshes', ['mesh']), ('mixed', ['particles', 'volume', 'mesh'])]:
        fixture(out / f'{name}.wvz', kinds)
    sources = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.wvz')}
    run = subprocess.run([args.godot, '--path', str(ROOT / 'viewer'),
                          '--rendering-method', args.renderer, '--audio-driver', 'Dummy',
                          '--resolution', '1440x900', '--script', 'ui/test_save_image_viewport.gd',
                          '--', '--save-image-output=' + str(out)],
                         text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=150)
    (out / 'native.log').write_text(run.stdout)
    if run.returncode or 'SCRIPT ERROR:' in run.stdout or 'ERROR:' in run.stdout:
        raise RuntimeError(f'Save Image validation failed: {out / "native.log"}')
    report = json.loads((out / 'report.json').read_text())
    assert not report['failures'], report['failures']
    assert sources == {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.wvz')}
    print(f'Save Image: {report["checks"]} PASS ({args.renderer}); source hashes unchanged')


if __name__ == '__main__':
    main()

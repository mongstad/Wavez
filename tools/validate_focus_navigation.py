"""Native visibility-aware Tab traversal, focus handoff and dialog containment."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tests.g4.fixtures import scene
from tools.validate_simulation_panel import fixture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--renderer', choices=['forward_plus'], default='forward_plus')
    args = parser.parse_args()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=False)
    for name in ['scene.wvz', 'replacement.wvz']:
        scene(output / name)
    fixture(output / 'multi.wvz', ['particles', 'volume', 'mesh'])
    fixture(output / 'fields.wvz', ['volume'])
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in output.glob('*.wvz')}
    env = dict(os.environ, XDG_DATA_HOME=str(output / 'profile/data'),
               XDG_CONFIG_HOME=str(output / 'profile/config'))
    command = [args.godot, '--path', str(ROOT / 'viewer'), '--rendering-method', args.renderer,
               '--audio-driver', 'Dummy', '--resolution', '1440x900',
               '--script', 'ui/shell/test_focus_navigation.gd', '--', str(output)]
    result = subprocess.run(command, cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=180)
    (output / 'native.txt').write_text(result.stdout)
    if result.returncode or 'ERROR:' in result.stdout or 'WARNING:' in result.stdout:
        raise RuntimeError(f'Focus regression failed; see {output / "native.txt"}')
    report = json.loads((output / 'report.json').read_text())
    assert not report['failures'], report['failures']
    assert hashes == {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in output.glob('*.wvz')}
    report['source_hashes_unchanged'] = hashes
    (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'Focus navigation: {report["checks"]} checks PASS ({args.renderer}); sources unchanged')


if __name__ == '__main__':
    main()

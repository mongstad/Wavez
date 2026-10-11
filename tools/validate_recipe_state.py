"""Controlled v2/v3 recipe ownership, UI synchronization and repeated restoration."""
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
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--renderer', choices=['headless', 'forward_plus'], default='headless')
    args = parser.parse_args()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=False)
    source = scene(output / 'scene.wvz')
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    rendering = ['--headless'] if args.renderer == 'headless' else ['--rendering-method', args.renderer]
    command = [args.godot, '--path', str(ROOT / 'viewer'), *rendering,
               '--audio-driver', 'Dummy', '--log-file', str(output / 'godot.log'),
               '--script', 'scene/test_recipe_state.gd', '--', '--recipe-fixture=' + str(output)]
    result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=150)
    (output / 'stdout.log').write_text(result.stdout)
    if result.returncode or 'ERROR:' in result.stdout:
        raise RuntimeError(f'Recipe regression failed; see {output / "stdout.log"}')
    report = json.loads((output / 'recipe-state-report.json').read_text())
    if report['failures'] or hashlib.sha256(source.read_bytes()).hexdigest() != digest:
        raise AssertionError('Recipe assertions failed or capture bytes changed')
    print(f'Recipe state: {report["checks"]} checks PASS ({args.renderer}); inventory in {output}')


if __name__ == '__main__':
    main()

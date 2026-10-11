"""Native visual marker addressing without scientific worker queries."""
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
    parser.add_argument('--renderer', choices=['headless', 'forward_plus', 'gl_compatibility'], default='headless')
    args = parser.parse_args()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=False)
    source = scene(output / 'fixture.wvz')
    before = hashlib.sha256(source.read_bytes()).hexdigest()
    command = [args.godot, '--path', str(ROOT / 'viewer'), '--audio-driver', 'Dummy']
    command += ['--headless'] if args.renderer == 'headless' else ['--rendering-method', args.renderer]
    command += ['--script', 'video/test_presentation_markers.gd', '--', str(output)]
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=40)
    (output / 'native.log').write_text(result.stdout)
    report = json.loads((output / 'report.json').read_text()) if (output / 'report.json').exists() else {'checks': []}
    report.update(command=command, renderer=args.renderer, exit_code=result.returncode,
                  source_sha256=before, source_unchanged=before == hashlib.sha256(source.read_bytes()).hexdigest())
    report['passed'] = (result.returncode == 0 and 'ERROR:' not in result.stdout and report['source_unchanged']
                        and bool(report['checks']) and all(item['ok'] for item in report['checks']))
    (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f"Visual markers: {len(report['checks'])} checks, {'PASS' if report['passed'] else 'FAIL'} ({args.renderer})")
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())

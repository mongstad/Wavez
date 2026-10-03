"""Native UX3 shell geometry, routing, state and lifecycle checks on tiny SSC fixtures."""
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
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], default='forward_plus')
    args = parser.parse_args()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=False)
    for name in ['scene.ssc', 'replacement.ssc']:
        scene(output / name)
    (output / 'invalid.ssc').write_bytes(b'not a SIMSCP4 capture')
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in output.glob('*.ssc')}
    command = [args.godot, '--path', str(ROOT / 'viewer'), '--rendering-method', args.renderer,
               '--audio-driver', 'Dummy', '--resolution', '1440x900', '--log-file', str(output / 'godot.log'),
               '--script', 'ui/shell/test_viewer_shell.gd', '--', '--shell-output=' + str(output)]
    result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=180)
    (output / 'stdout.log').write_text(result.stdout)
    if result.returncode or 'ERROR:' in result.stdout or 'WARNING:' in result.stdout:
        raise RuntimeError(f'Shell regression failed; see {output / "stdout.log"}')
    report = json.loads((output / 'shell-report.json').read_text())
    assert not report['failures'], report['failures']
    contract = (ROOT / 'docs/UX4_DESIGN.md').read_text().split('```text\n', 1)[1].split('```', 1)[0].strip().splitlines()
    contract.insert(contract.index('  Open capture') + 1, '  Details…')  # #147 source/status entry
    contract.insert(contract.index('View'), '  Exit')  # #153 normal application shutdown
    contract.insert(contract.index('  Probe marker'), '  Global effects')  # #68: global Bloom destination
    contract.insert(contract.index('  Handbook') + 1, '  About')  # Current Help menu label after #164.
    contract = [line.replace('Save scene', 'Save view preset…').replace('Load scene', 'Load view preset…') for line in contract]
    contract = [line for line in contract if line not in ['  Panels', '  Immersive', '  Quick setup', '  Handbook']]
    contract.remove('  Shortcuts')  # #175 editable application preferences
    contract[contract.index('View'):contract.index('View')] = ['Edit', '  Preferences', '    Keyboard Shortcuts']
    contract[contract.index('  Fullscreen'):contract.index('  Fullscreen')+1] = ['  Window', '    Fullscreen']
    assert report['menu_tree'] == contract, 'Runtime menu hierarchy differs from accepted UX4 contract'
    report['menu_contract_matches'] = True
    assert hashes == {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in output.glob('*.ssc')}
    report['source_hashes_unchanged'] = hashes
    (output / 'shell-report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'Viewer shell: {report["checks"]} checks PASS ({args.renderer}); source hashes unchanged')


if __name__ == '__main__':
    main()

"""Exercise Godot dialog controls and navigation persistence on tiny WVZ1 scenes."""
import argparse
import hashlib
import json
import os
import re
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
    parser.add_argument('--display-driver', choices=['wayland', 'x11', 'headless'], default='wayland')
    args = parser.parse_args()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=False)
    for name in ['capture', 'other', 'export', 'cancelled', 'invalid']:
        (output / name).mkdir()
    for name in ['capture', 'other']:
        scene(output / name / 'scene.wvz')
    (output / 'invalid' / 'invalid.wvz').write_bytes(b'not a WVZ1 capture')
    (output / 'cancelled' / 'existing.mp4').write_bytes(b'existing destination sentinel')
    hashes = {str(p.relative_to(output)): hashlib.sha256(p.read_bytes()).hexdigest() for p in output.rglob('*.wvz')}
    env = dict(os.environ, XDG_DATA_HOME=str(output / 'user-data'), XDG_CONFIG_HOME=str(output / 'config'), LANG='C.UTF-8')
    if args.display_driver == "wayland":
        env["GDK_BACKEND"] = "wayland"
    reports = []
    for phase in ['baseline', 'native', 'capture_add', 'capture_remove', 'export_add', 'export_remove', 'stale', 'stale_reload']:
        command = [args.godot, '--path', str(ROOT / 'viewer'), '--display-driver', args.display_driver,
                   '--rendering-method', args.renderer, '--audio-driver', 'Dummy', '--resolution', '1440x900',
                   '--log-file', str(output / f'{phase}-godot.log'),
                   '--script', 'ui/test_file_dialog_preferences.gd', '--', f'--output={output}', f'--phase={phase}']
        result = subprocess.run(command, cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=90)
        (output / f'{phase}-stdout.log').write_text(result.stdout)
        # Accepted main b33e9a8 reproduces these two FileDialog GL cleanup
        # diagnostics with the same interaction sequence. Retain, never hide them.
        pattern = r'ERROR: Texture with GL ID of \d+: leaked 349524 bytes\.\n   at: ~Utilities \(drivers/gles3/storage/utilities.cpp:82\)\n'
        known_cleanup = re.findall(pattern, result.stdout) if args.renderer == 'gl_compatibility' else []
        assert len(known_cleanup) <= 2, 'More GL cleanup diagnostics than accepted main'
        checked_log = re.sub(pattern, '', result.stdout) if known_cleanup else result.stdout
        if result.returncode or 'ERROR:' in checked_log or 'WARNING:' in checked_log:
            raise RuntimeError(f'{phase} failed; see {output / (phase + "-stdout.log")}')
        report = json.loads((output / f'{phase}.json').read_text())
        report['known_baseline_gl_cleanup_diagnostics'] = known_cleanup
        assert not report['failures'], report
        reports.append(report)
    assert hashes == {str(p.relative_to(output)): hashlib.sha256(p.read_bytes()).hexdigest() for p in output.rglob('*.wvz')}
    summary = {'phases': reports, 'checks': sum(r['checks'] for r in reports), 'source_hashes_unchanged': hashes}
    (output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print('Known baseline GL cleanup diagnostics:', sum(len(r['known_baseline_gl_cleanup_diagnostics']) for r in reports))
    print(f'File dialogs: {summary["checks"]} checks PASS ({args.renderer}, {args.display_driver}, eight processes)')


if __name__ == '__main__':
    main()

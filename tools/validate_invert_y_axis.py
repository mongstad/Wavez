"""Focused LMB inversion/preference checks, renderer matrix and restart validation."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.validate_simulation_panel import fixture
from tools.package_linux import stage


def run(command, out, label, env):
    result = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True, timeout=160)
    log = result.stdout + result.stderr
    (out / (label + '.txt')).write_text(log)
    if result.returncode or any(marker in log for marker in ('ERROR:', 'WARNING:')):
        raise RuntimeError(f'{label} failed: {out / (label + ".txt")}')


def unchanged_navigation():
    current = (ROOT / 'viewer/main.gd').read_text()
    accepted = subprocess.check_output(['git', 'show', 'main:viewer/main.gd'], cwd=ROOT, text=True)
    names = ['_input', '_unhandled_input', '_steer_camera', '_orbit_camera_horizontally',
             '_move_free_camera', '_zoom_camera', '_update_camera', '_reset_camera',
             '_toggle_auto_orbit', '_focus_activity']
    def body(text, name):
        match = re.search(r'^func ' + re.escape(name) + r'\(.*?(?=^func |\Z)', text, re.M | re.S)
        assert match, name
        return match.group(0)
    for name in names:
        assert body(current, name) == body(accepted, name), f'Out-of-scope function changed: {name}'
    return names


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['headless', 'forward_plus'], default='headless')
    package = parser.add_mutually_exclusive_group()
    package.add_argument('--export', action='store_true')
    package.add_argument('--packaged-binary', type=Path)
    args = parser.parse_args()
    out = args.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    for name, kinds in {'particles':['particles'], 'fields':['volume'], 'meshes':['mesh'], 'mixed':['particles','volume','mesh']}.items():
        fixture(out / (name + '.wvz'), kinds)
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.wvz')}
    unchanged = unchanged_navigation()
    build_env = dict(os.environ, XDG_CONFIG_HOME=str(out / 'editor-config'))
    if args.export:
        project = out / 'export-source'; stage(project)
        with (project / 'project.godot').open('a') as settings:
            settings.write('\n[autoload]\nInversionValidation="*res://ui/shell/test_invert_y_axis.gd"\n')
        run([args.godot, '--headless', '--path', str(project), '--editor', '--import'], out, 'import', build_env)
        executable = out / 'WAVEZ.x86_64'
        run([args.godot, '--headless', '--path', str(project), '--export-release', 'Wavez Linux', str(executable)], out, 'export', build_env)
        command = [str(executable)]
    elif args.packaged_binary:
        command = [str(args.packaged_binary.resolve())]
    else:
        command = [args.godot, '--path', str(ROOT / 'viewer'), '--script', 'res://ui/shell/run_invert_y_tests.gd']
    env = dict(build_env, XDG_DATA_HOME=str(out / 'profile'))
    command += ['--audio-driver', 'Dummy', '--log-file', str(out / 'engine.txt')]
    command += ['--headless'] if args.renderer == 'headless' else ['--rendering-method', args.renderer, '--resolution', '1440x900']
    command += ['--', '--invert-output=' + str(out)]
    run(command, out, 'native', env)
    run(command + ['--invert-restart'], out, 'restart', env)
    reports = [json.loads((out / name).read_text()) for name in ['report.json','restart-report.json']]
    packaged = bool(args.export or args.packaged_binary)
    assert all(not r['failures'] and r['packaged'] == packaged for r in reports), reports
    assert hashes == {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.wvz')}
    report = dict(checks=sum(r['checks'] for r in reports), reports=reports, renderer=args.renderer,
                  packaged=packaged, fresh_process_restart=True, source_hashes_unchanged=hashes,
                  accepted_main_navigation_functions_unchanged=unchanged)
    if packaged:
        binary = Path(command[0])
        report['package_hashes'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in [binary, binary.with_suffix('.pck')]}
    (out / 'validation.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'Invert Y Axis: {report["checks"]} checks PASS ({args.renderer}, packaged={packaged}); restart and hashes verified')


if __name__ == '__main__':
    main()

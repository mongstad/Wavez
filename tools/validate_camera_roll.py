"""Validate #331 camera-local banking and shortcut persistence on tiny WVZ1 fixtures."""
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
from tools.validate_simulation_panel import fixture
from tools.package_linux import stage, build


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['headless', 'forward_plus', 'gl_compatibility'], default='headless')
    parser.add_argument('--package', action='store_true')
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    for name, kinds in {'particles':['particles'], 'fields':['volume'], 'meshes':['mesh'], 'mixed':['particles','volume','mesh']}.items():
        fixture(out / (name + '.wvz'), kinds)
    hashes = {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.wvz')}
    env = dict(os.environ, XDG_CONFIG_HOME=str(out / 'config'), XDG_DATA_HOME=str(out / 'profile'))

    def run(label, command):
        result = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True, timeout=160)
        log = result.stdout + result.stderr
        (out / (label + '.log')).write_text(log)
        # Accepted main c33ff2b reproduces exactly two GL texture diagnostics
        # per export-style viewer at shutdown (five viewers in this suite),
        # and two for a single Light-theme viewer on fresh-process restart.
        # Keep those messages in both the log and the result; reject everything
        # else, including a different count or errors before the final summary.
        pattern = r'ERROR: Texture with GL ID of \d+: leaked 349524 bytes\.\n   at: ~Utilities \(drivers/gles3/storage/utilities.cpp:82\)\n'
        cleanup = re.findall(pattern, log)
        checked = log
        expected = 10 if label == 'roll' else 2 if label == 'restart' else 0
        if args.renderer == 'gl_compatibility' and expected and len(cleanup) == expected and all(log.index(item) > log.index('CAMERA ROLL:') for item in cleanup):
            checked = re.sub(pattern, '', log)
        else:
            cleanup = []
        if result.returncode or 'ERROR:' in checked or 'WARNING:' in checked:
            raise RuntimeError(f'{label} failed: {out / (label + ".log")}\n{log[-3000:]}')
        return cleanup

    if args.package:
        project = out / 'export-source'
        stage(project)
        with (project / 'project.godot').open('a') as config:
            config.write('\n[autoload]\nRollValidation="*res://scene/test_camera_roll.gd"\n')
        executable = out / 'WAVEZ.x86_64'
        build(args.godot, project, executable, out / 'build-logs')
        command = [str(executable)]
    else:
        run('import', [args.godot, '--headless', '--path', str(ROOT / 'viewer'), '--editor', '--import'])
        command = [args.godot, '--path', str(ROOT / 'viewer'), '--script', 'res://scene/run_camera_roll_tests.gd']
    command += ['--audio-driver', 'Dummy']
    command += ['--headless'] if args.renderer == 'headless' else ['--rendering-method', args.renderer, '--resolution', '1440x900']
    command += ['--', '--roll-output=' + str(out)]
    cleanup = run('roll', command)
    restart_cleanup = run('restart', command + ['--roll-restart'])
    reports = [json.loads((out / name).read_text()) for name in ['roll-report.json', 'restart-report.json']]
    assert all(not report['failures'] and report['packaged'] == args.package for report in reports), reports
    assert hashes == {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.wvz')}
    summary = dict(checks=sum(r['checks'] for r in reports), renderer=args.renderer, packaged=args.package,
                   fresh_process_restart=True, source_sha256_unchanged=hashes, reports=reports,
                   known_engine_cleanup_diagnostics={'roll':cleanup, 'restart':restart_cleanup})
    if args.package:
        summary['artifacts'] = {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [executable, executable.with_suffix('.pck')]}
    (out / 'validation.json').write_text(json.dumps(summary, indent=2) + '\n')
    limitation = '; accepted-main GL teardown diagnostics retained' if cleanup else ''
    print(f'Camera roll: {summary["checks"]} PASS ({args.renderer}, packaged={args.package}); restart and source hashes verified{limitation}')


if __name__ == '__main__':
    main()

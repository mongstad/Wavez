"""Verify revised square surfaces, flush About seams and shared close controls in source/Linux packages."""
import argparse
import json
import os
from pathlib import Path
import shutil
import re
import subprocess

def run(command, output, label, env, known_packaged_window_cleanup=False, wayland=False):
    try:
        process = subprocess.run(command, capture_output=True, text=True, env=env, timeout=160)
    except subprocess.TimeoutExpired as failure:
        def decoded(value):
            return value.decode(errors="replace") if isinstance(value, bytes) else (value or "")
        (output / f'{label}.log').write_text(decoded(failure.stdout) + decoded(failure.stderr))
        raise
    log = process.stdout + process.stderr
    (output / f'{label}.log').write_text(log)
    checked = log
    diagnostics = []
    # Exact native Wayland pair reproduced on accepted main 29072a8.
    decor = "libdecor-gtk-WARNING: Failed to initialize GTK\nFailed to load plugin 'libdecor-gtk.so': failed to init\n"
    if wayland and checked.count(decor) == 1:
        diagnostics.append(decor); checked = checked.replace(decor, '')
    # Existing embedded-window shutdown pair reproduced/documented under #175.
    pattern = r"ERROR: Attempt to disconnect a nonexistent connection from 'root:<Window#\d+>'. Signal: '(?:focus_entered|tree_exited)', callable: ''.\n   at: _disconnect \(core/object/object.cpp:1644\)\n"
    cleanup = re.findall(pattern, checked) if known_packaged_window_cleanup else []
    if len(cleanup) == 2 and any("'focus_entered'" in item for item in cleanup) and any("'tree_exited'" in item for item in cleanup):
        diagnostics.extend(cleanup); checked = re.sub(pattern, '', checked)
    if process.returncode or 'ERROR:' in checked or 'WARNING:' in checked:
        raise RuntimeError(f'Rounded validation failed; see {output / (label + ".log")}')
    return diagnostics

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['forward_plus'], default='forward_plus')
    parser.add_argument('--display-driver', choices=['x11', 'wayland'], default='x11')
    parser.add_argument('--export', action='store_true')
    args = parser.parse_args()
    out = args.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    env = os.environ.copy()
    env['XDG_CONFIG_HOME'] = str(out / 'config')
    if args.export:
        project = out / 'export-source'
        shutil.copytree(ROOT / 'viewer', project, ignore=shutil.ignore_patterns('.godot'))
        with (project / 'project.godot').open('a') as settings:
            settings.write('\n[autoload]\nRoundedValidation="*res://ui/shell/test_rounded_surfaces.gd"\n')
        (project / 'export_presets.cfg').write_text('[preset.0]\nname="Rounded validation"\nplatform="Linux"\nrunnable=true\nexport_filter="all_resources"\ninclude_filter=""\nexclude_filter=""\nscript_export_mode=2\n[preset.0.options]\nbinary_format/architecture="x86_64"\nbinary_format/embed_pck=false\n')
        executable = out / 'wavez.x86_64'
        for label, options in [('import', ['--editor', '--import', '--quit']), ('export', ['--export-release', 'Rounded validation', str(executable)])]:
            run([args.godot, '--headless', '--path', str(project), *options], out, label, env)
        command = [str(executable)]
    else:
        command = [args.godot, '--path', str(ROOT / 'viewer'), '--script', 'res://ui/shell/run_rounded_tests.gd']
    env['XDG_DATA_HOME'] = str(out / 'profile')
    command += ['--rendering-method', args.renderer, '--display-driver', args.display_driver,
                '--audio-driver', 'Dummy', '--resolution', '1440x900', '--', '--rounded-output='+str(out)]
    diagnostics = run(command, out, 'native', env, known_packaged_window_cleanup=args.export, wayland=args.display_driver == 'wayland')
    report = json.loads((out / 'rounded-report.json').read_text())
    assert not report['failures'], report['failures']
    assert report['packaged'] == args.export
    report['known_engine_cleanup_diagnostics'] = diagnostics
    (out / 'validation.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'Rounded surfaces: {report["checks"]} PASS ({args.renderer}, {args.display_driver}, packaged={args.export})')


if __name__ == '__main__':
    main()

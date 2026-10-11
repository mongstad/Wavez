"""Focused native and packaged checks for issue #205's viewport-fixed cinematic sky."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.validate_render_pacing import fixtures
from tools.validate_rounded_surfaces import run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['forward_plus'], required=True)
    parser.add_argument('--export', action='store_true')
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    fixtures(out)
    before = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in out.glob('*.wvz')}
    env = os.environ.copy()
    env['XDG_CONFIG_HOME'] = str(out / 'config')
    if args.export:
        project = out / 'export-source'
        shutil.copytree(ROOT / 'viewer', project, ignore=shutil.ignore_patterns('.godot'))
        with (project / 'project.godot').open('a') as settings:
            settings.write('\n[autoload]\nScreenFixedValidation="*res://scene/test_screen_fixed_background.gd"\n')
        (project / 'export_presets.cfg').write_text(
            '[preset.0]\nname="Screen fixed validation"\nplatform="Linux"\n'
            'runnable=true\nexport_filter="all_resources"\ninclude_filter=""\n'
            'exclude_filter=""\nscript_export_mode=2\n[preset.0.options]\n'
            'binary_format/architecture="x86_64"\nbinary_format/embed_pck=false\n'
        )
        executable = out / 'wavez.x86_64'
        for label, options in [('import', ['--editor', '--import', '--quit']),
                               ('export', ['--export-release', 'Screen fixed validation', str(executable)])]:
            run([args.godot, '--headless', '--path', str(project), *options], out, label, env)
        command = [str(executable)]
    else:
        command = [args.godot, '--path', str(ROOT / 'viewer'), '--script',
                   'res://scene/run_screen_fixed_background_tests.gd']
    env['XDG_DATA_HOME'] = str(out / 'profile')
    command += ['--rendering-method', args.renderer, '--display-driver', 'wayland',
                '--audio-driver', 'Dummy', '--resolution', '960x640', '--', str(out)]
    diagnostics = run(command, out, 'native', env, wayland=True,
                      known_packaged_window_cleanup=args.export)
    report = json.loads((out / 'screen-fixed-report.json').read_text())
    assert not report['failures'], report['failures']
    assert report['packaged'] == args.export
    assert before == {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in out.glob('*.wvz')}
    report['source_hashes_unchanged'] = before
    report['known_engine_diagnostics'] = diagnostics
    (out / 'validation.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'Screen-fixed background: {report["checks"]} PASS ({args.renderer}, packaged={args.export})')


if __name__ == '__main__':
    main()

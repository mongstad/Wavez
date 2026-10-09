"""Focused chrome theme audit, with isolated preferences and fresh restarts.

Use --package to export a validation entry scene with the production resources.
Release templates ignore --script; no source project path is passed to the package.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.validate_simulation_panel import fixture
from tools.package_linux import stage, build


def test_package(godot, output):
    with tempfile.TemporaryDirectory(prefix='wavez-theme-package-') as temporary:
        project = Path(temporary) / 'viewer'
        stage(project)
        script = (project / 'ui/theme/test_application_theme.gd').read_text()
        script = script.replace('extends SceneTree', 'extends Node\nvar root: Window:\n\tget: return get_tree().root\nvar process_frame: Signal:\n\tget: return get_tree().process_frame')
        script = script.replace('func _initialize()', 'func _ready()').replace('create_timer(', 'get_tree().create_timer(').replace('quit(', 'get_tree().quit(')
        (project / 'theme_review.gd').write_text(script)
        (project / 'ThemeReview.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://theme_review.gd" id="1"]\n[node name="Review" type="Node"]\nscript = ExtResource("1")\n')
        config = project / 'project.godot'
        config.write_text(config.read_text().replace('res://Main.tscn', 'res://ThemeReview.tscn'))
        binary = output / 'WAVEZ.x86_64'
        build(godot, project, binary, output / 'build-logs')
    return str(binary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--package', action='store_true')
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], default='forward_plus')
    parser.add_argument('--output-dir', required=True, type=Path)
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    fixture(out / 'mixed.wvz', ['particles', 'volume', 'mesh'])
    digest = hashlib.sha256((out / 'mixed.wvz').read_bytes()).hexdigest()
    env = dict(os.environ, XDG_DATA_HOME=str(out / 'profile'), XDG_CONFIG_HOME=str(out / 'profile'))
    reports = {}
    executable = test_package(args.godot, out) if args.package else args.godot
    for phase, choice in [('cycle', None), ('restart-light', 'Light'), ('restart-dark', 'Dark')]:
        destination = out if choice is None else out / phase
        destination.mkdir(exist_ok=True)
        command = [executable]
        if not args.package:
            command += ['--path', str(ROOT / 'viewer'), '--script', 'res://ui/theme/test_application_theme.gd']
        command += ['--rendering-method', args.renderer, '--resolution', '1440x900',
                    '--audio-driver', 'Dummy',
                    '--', str(destination)]
        if choice is not None:
            command.append(choice)
        result = subprocess.run(command, cwd=out, env=env, capture_output=True, text=True, timeout=240)
        log = result.stdout + result.stderr
        (out / (phase + '.log')).write_text(log)
        if result.returncode or 'ERROR:' in log or 'WARNING:' in log:
            raise RuntimeError(f'{phase} failed: {out / (phase + ".log")}')
        reports[phase] = json.loads((destination / 'report.json').read_text())
        assert not reports[phase]['failures'], reports[phase]
    assert hashlib.sha256((out / 'mixed.wvz').read_bytes()).hexdigest() == digest
    reports['source_sha256_unchanged'] = digest
    reports['packaged'] = args.package
    (out / 'summary.json').write_text(json.dumps(reports, indent=2) + '\n')
    print(f'Application theme: {sum(reports[p]["checks"] for p in ["cycle", "restart-light", "restart-dark"])} PASS ({args.renderer}, package={args.package})')


if __name__ == '__main__':
    main()

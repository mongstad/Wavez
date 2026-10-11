"""Focused exit confirmation, real worker shutdown and optional Linux package checks."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tests.g4.fixtures import scene


def run(command, output, name, env):
    result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=240)
    log = result.stdout + result.stderr
    (output / f'{name}.txt').write_text(log)
    if result.returncode or 'ERROR:' in log or 'WARNING:' in log:
        raise RuntimeError(f'Exit validation failed: {output / (name + ".txt")}')


def package(godot, output):
    # Only temporary build output; external templates and runtime are not vendored.
    project = output / 'export-source'
    shutil.copytree(ROOT / 'viewer', project, ignore=shutil.ignore_patterns('.godot'))
    for source, target in [('test_exit_confirmation.gd', 'review_dialog.gd'), ('test_exit_menu.gd', 'review_exit.gd')]:
        text = (project / 'ui/shell' / source).read_text()
        text = text.replace('extends SceneTree', 'extends Node\nvar root: Window:\n\tget: return get_tree().root\nvar process_frame: Signal:\n\tget: return get_tree().process_frame')
        text = text.replace('func _initialize()', 'func _ready()').replace('create_timer(', 'get_tree().create_timer(').replace('quit(', 'get_tree().quit(')
        text = text.replace('not auto_accept_quit', 'not get_tree().auto_accept_quit')
        (project / target).write_text(text)
    (project / 'review_entry.gd').write_text('''extends Node
func _ready():
    var args := OS.get_cmdline_user_args()
    for arg in args:
        if arg.begins_with("--wavez-render-job="):
            add_child(load("res://Main.tscn").instantiate());return
    var script := "res://review_dialog.gd" if "--exit-confirmation-matrix" in args else "res://review_exit.gd"
    add_child(load(script).new())
''')
    (project / 'Review.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://review_entry.gd" id="1"]\n[node name="Review" type="Node"]\nscript = ExtResource("1")\n')
    config = project / 'project.godot'
    config.write_text(config.read_text().replace('res://Main.tscn', 'res://Review.tscn'))
    (project / 'export_presets.cfg').write_text('''[preset.0]
name="Exit validation"
platform="Linux"
runnable=true
export_filter="all_resources"
include_filter="*.gd,*.json,*.md,*.txt"
exclude_filter=""
[preset.0.options]
binary_format/architecture="x86_64"
binary_format/embed_pck=false
''')
    binary = output / 'wavez.x86_64'
    # Keep the ordinary data home so the externally installed templates remain visible.
    env = dict(os.environ, XDG_CONFIG_HOME=str(output / 'build-config'))
    for name, args in [('import', ['--editor', '--import']), ('export', ['--export-debug', 'Exit validation', str(binary)])]:
        run([godot, '--headless', '--path', str(project), *args], output, name, env)
    return str(binary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--renderer', choices=['forward_plus'], default='forward_plus')
    runtime_mode = parser.add_mutually_exclusive_group()
    runtime_mode.add_argument('--export', action='store_true', help='Build and test a temporary standalone Linux debug executable')
    runtime_mode.add_argument('--packaged', action='store_true', help='Reuse an executable previously built with --export')
    parser.add_argument('--dialog-only', action='store_true', help='Validate the dialog matrix without launching lifecycle/export workers')
    args = parser.parse_args()
    output = args.output_dir.resolve(); output.mkdir(parents=True, exist_ok=False)
    source = output / 'scene.wvz'; scene(source)
    before = hashlib.sha256(source.read_bytes()).hexdigest()
    runtime = package(args.godot, output) if args.export else args.godot
    packaged = args.export or args.packaged
    env = dict(os.environ, XDG_DATA_HOME=str(output / 'profile/data'), XDG_CONFIG_HOME=str(output / 'profile/config'))
    command = [runtime] + ([] if packaged else ['--path', str(ROOT / 'viewer'), '--script', 'ui/shell/test_exit_confirmation.gd'])
    command += ['--rendering-method', args.renderer, '--audio-driver', 'Dummy', '--resolution', '1440x900', '--', str(output), '--exit-confirmation-matrix']
    run(command, output, 'native', env)
    report = json.loads((output / 'report.json').read_text())
    assert not report['failures']
    assert hashlib.sha256(source.read_bytes()).hexdigest() == before
    if args.dialog_only:
        report.update(renderer=args.renderer, packaged=packaged, source_sha256_unchanged=before, lifecycle_not_run=True)
        (output / 'validation.json').write_text(json.dumps(report, indent=2) + '\n')
        print(f'Exit confirmation: {report["checks"]} dialog checks PASS ({args.renderer}, packaged={packaged}); lifecycle not run')
        return
    lifecycle = [sys.executable, str(ROOT / 'tools/validate_exit_menu.py'), '--godot', runtime,
                 '--output-dir', str(output / 'lifecycle'), '--renderer', args.renderer]
    if packaged: lifecycle.append('--packaged')
    run(lifecycle, output, 'lifecycle', env)
    report.update(renderer=args.renderer, packaged=packaged, source_sha256_unchanged=before,
                  lifecycle=json.loads((output / 'lifecycle/report.json').read_text()))
    (output / 'validation.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'Exit confirmation: {report["checks"]} checks and {len(report["lifecycle"]["runs"])} process cases PASS ({args.renderer}, packaged={packaged})')


if __name__ == '__main__':
    main()

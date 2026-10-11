"""Exercise the File/Tools dialog presentation on a small mixed WVZ1 scene."""
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
from validate_simulation_panel import fixture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--renderer', choices=['forward_plus'], required=True)
    parser.add_argument('--export', action='store_true', help='Export and exercise a temporary Linux review package')
    args = parser.parse_args()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=False)
    capture = output / 'mixed.wvz'
    fixture(capture, ['particles', 'volume', 'mesh'])
    before_hash = hashlib.sha256(capture.read_bytes()).hexdigest()
    environment = os.environ.copy()
    environment['XDG_CONFIG_HOME'] = str(output / 'config')
    if args.export:
        project = output / 'export-source'
        shutil.copytree(ROOT / 'viewer', project, ignore=shutil.ignore_patterns('.godot'))
        test = (project / 'ui/shell/test_dialog_coherence.gd').read_text()
        test = test.replace('extends SceneTree', '''extends Node
var root: Window:
\tget: return get_tree().root
var process_frame: Signal:
\tget: return get_tree().process_frame''')
        test = test.replace('func _initialize()', 'func _ready()')
        test = test.replace('create_timer(', 'get_tree().create_timer(').replace('quit(', 'get_tree().quit(')
        (project / 'review_dialog.gd').write_text(test)
        (project / 'review_entry.gd').write_text('extends Node\nfunc _ready():\n\tadd_child(load("res://review_dialog.gd").new())\n')
        (project / 'Review.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://review_entry.gd" id="1"]\n[node name="Review" type="Node"]\nscript = ExtResource("1")\n')
        settings = project / 'project.godot'
        settings.write_text(settings.read_text().replace('res://Main.tscn', 'res://Review.tscn'))
        (project / 'export_presets.cfg').write_text('''[preset.0]
name="Dialog review"
platform="Linux"
runnable=true
export_filter="all_resources"
include_filter="*.gd"
exclude_filter=""
script_export_mode=2
[preset.0.options]
binary_format/architecture="x86_64"
binary_format/embed_pck=false
''')
        binary = output / 'wavez.x86_64'
        for label, flags in [('import', ['--editor', '--import', '--quit']),
                             ('export', ['--export-release', 'Dialog review', str(binary)])]:
            export_run = subprocess.run([args.godot, '--headless', '--path', str(project), *flags],
                                        cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT, timeout=150)
            (output / f'{label}.log').write_text(export_run.stdout)
            if export_run.returncode or 'SCRIPT ERROR:' in export_run.stdout:
                raise RuntimeError(f'Package {label} failed: {output / (label + ".log")}')
        command = [str(binary), '--rendering-method', args.renderer, '--audio-driver', 'Dummy',
                   '--resolution', '1440x900', '--', str(output)]
    else:
        command = [args.godot, '--path', str(ROOT / 'viewer'), '--rendering-method', args.renderer,
                   '--audio-driver', 'Dummy', '--resolution', '1440x900', '--script',
                   'ui/shell/test_dialog_coherence.gd', '--', str(output)]
    environment['XDG_DATA_HOME'] = str(output / 'profile')
    result = subprocess.run(command, cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=150)
    (output / 'native.log').write_text(result.stdout)
    if result.returncode or 'ERROR:' in result.stdout or 'WARNING:' in result.stdout:
        raise RuntimeError(f'Dialog coherence failed: {output / "native.log"}')
    report = json.loads((output / 'dialog-report.json').read_text())
    assert not report['failures'], report['failures']
    assert hashlib.sha256(capture.read_bytes()).hexdigest() == before_hash
    print(f'Dialog coherence: {report["checks"]} PASS ({args.renderer}, packaged={args.export}); source unchanged')


if __name__ == '__main__':
    main()

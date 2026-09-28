"""Build a temporary Linux debug package with a status-test entry scene.

The normal main scene handles child render jobs. No runtime/template is vendored.
"""
import argparse
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--output-dir', required=True, type=Path)
    a = p.parse_args()
    out = a.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    project = out/'project'; shutil.copytree(ROOT/'viewer', project, ignore=shutil.ignore_patterns('.godot'))
    test = (project/'ui/shell/test_viewer_status.gd').read_text()
    test = test.replace('extends SceneTree', 'extends Node\nvar root: Window:\n\tget: return get_tree().root\nvar process_frame: Signal:\n\tget: return get_tree().process_frame')
    test = test.replace('func _initialize()', 'func _ready()').replace('create_timer(', 'get_tree().create_timer(').replace('quit(', 'get_tree().quit(')
    (project/'review_status.gd').write_text(test)
    (project/'review_entry.gd').write_text('''extends Node
func _ready():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--simscope-render-job="):
            add_child(load("res://Main.tscn").instantiate());return
    add_child(load("res://review_status.gd").new())
''')
    (project/'Review.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://review_entry.gd" id="1"]\n[node name="Review" type="Node"]\nscript = ExtResource("1")\n')
    config = project/'project.godot'; config.write_text(config.read_text().replace('res://Main.tscn', 'res://Review.tscn'))
    (project/'export_presets.cfg').write_text('''[preset.0]
name="Review Linux"
platform="Linux"
runnable=true
export_filter="all_resources"
include_filter="*.gd,*.json,*.md,*.txt"
exclude_filter=""
[preset.0.options]
binary_format/architecture="x86_64"
binary_format/embed_pck=false
''')
    binary = out/'SimScope.x86_64'
    for name, flags in [('import', ['--editor', '--import']), ('export', ['--export-debug', 'Review Linux', str(binary)])]:
        with (out/(name+'.log')).open('w') as log:
            subprocess.run([a.godot, '--headless', '--path', str(project)]+flags, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=120)
    print(binary)

if __name__ == '__main__': main()

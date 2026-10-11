"""Audit production dialog actions against an accepted Git archive, with native evidence."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.validate_simulation_panel import fixture
from tools.package_linux import stage, build


def package(godot, output):
    with tempfile.TemporaryDirectory(prefix='wavez-dialog-actions-') as temporary:
        project = Path(temporary) / 'viewer'; stage(project)
        script = (project / 'ui/shell/test_dialog_actions.gd').read_text()
        script = script.replace('extends SceneTree', 'extends Node\nvar root: Window:\n\tget: return get_tree().root\nvar process_frame: Signal:\n\tget: return get_tree().process_frame')
        script = script.replace('func _initialize()', 'func _ready()').replace('create_timer(', 'get_tree().create_timer(').replace('quit(', 'get_tree().quit(')
        (project / 'review_dialog.gd').write_text(script)
        (project / 'Review.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://review_dialog.gd" id="1"]\n[node name="Review" type="Node"]\nscript = ExtResource("1")\n')
        config = project / 'project.godot'; config.write_text(config.read_text().replace('res://Main.tscn', 'res://Review.tscn'))
        binary = output / 'WAVEZ.x86_64'; build(godot, project, binary, output / 'build-logs')
    return str(binary)


def compare(before, after):
    assert before['contracts'].keys() == after['contracts'].keys(), 'Dialog control inventory changed'
    changed = 0
    for key, original in before['contracts'].items():
        candidate = after['contracts'][key]
        assert {k:v for k,v in original.items() if k != 'styles'} == {k:v for k,v in candidate.items() if k != 'styles'}, ('Action geometry/behavior/ink', key)
        for state, style in original['styles'].items():
            current = candidate['styles'][state]
            if state == 'normal' and '-excluded-' not in key and original['role'] in ['Button','SecondaryButton']:
                permitted = ['bg_color','border_color','border_width_left','border_width_top','border_width_right','border_width_bottom']
                assert {k:v for k,v in style.items() if k not in permitted} == {k:v for k,v in current.items() if k not in permitted}, ('Resting metrics changed', key)
                changed += style != current
            else:
                assert style == current, ('Existing state changed', key, state)
    return changed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--baseline', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--renderer', choices=['forward_plus'], required=True)
    parser.add_argument('--package', action='store_true')
    args = parser.parse_args(); output = args.output.resolve(); output.mkdir(parents=True, exist_ok=False)
    capture = output / 'mixed.wvz'; fixture(capture, ['particles','volume','mesh'])
    source_hash = hashlib.sha256(capture.read_bytes()).hexdigest()
    executable = package(args.godot, output) if args.package else args.godot
    reports = {}
    for name, project in [('before',args.baseline / 'viewer'),('after',ROOT / 'viewer')]:
        folder = output / name; folder.mkdir()
        environment = dict(os.environ, XDG_DATA_HOME=str(folder / 'profile'), XDG_CONFIG_HOME=str(folder / 'profile'))
        command = [executable] if args.package and name == 'after' else [args.godot,'--path',str(project),'--script',str(ROOT / 'viewer/ui/shell/test_dialog_actions.gd')]
        command += ['--rendering-method',args.renderer,'--audio-driver','Dummy','--resolution','1440x900','--',str(folder)] + (['baseline'] if name == 'before' else [])
        result = subprocess.run(command,cwd=folder,env=environment,capture_output=True,text=True,timeout=200)
        log = result.stdout + result.stderr; (folder / 'run.txt').write_text(log.rstrip()+'\n')
        if result.returncode or 'ERROR:' in log or 'WARNING:' in log: raise RuntimeError(f'{name} failed: {folder}/run.txt')
        report = json.loads((folder / 'report.json').read_text()); assert not report['failures']
        reports[name] = report; print(name, report['checks'], 'clean checks', flush=True)
    changed = compare(reports['before'], reports['after']); assert changed > 0
    if args.package: assert reports['after']['standalone'], 'Expected standalone runtime'
    pixels = []
    for image in sorted((output / 'before').glob('*-target.png')):
        if any(image.name.endswith('-'+state+'-target.png') for state in ['hover','pressed','disabled']):
            original = Image.open(image); candidate = Image.open(output / 'after' / image.name)
            assert original.size == candidate.size and original.tobytes() == candidate.tobytes(), ('State pixels changed', image.name)
            pixels.append(image.name)
    focus_pixels = []
    for image in sorted((output / 'before').glob('*-focus-target.png')):
        original = Image.open(image); candidate = Image.open(output / 'after' / image.name)
        assert original.size == candidate.size
        width, height = original.size
        # Only the resting underlay changes; the existing expanded focus ring
        # remains pixel-identical outside the button's original bounds.
        for region in [(0,0,width,4),(0,height-4,width,height),(0,4,4,height-4),(width-4,4,width,height-4)]:
            assert original.crop(region).tobytes() == candidate.crop(region).tobytes(), ('Focus ring pixels changed', image.name)
        focus_pixels.append(image.name)
    assert source_hash == hashlib.sha256(capture.read_bytes()).hexdigest()
    summary = dict(renderer=args.renderer, packaged=args.package, checks={k:v['checks'] for k,v in reports.items()}, contract_pairs=len(reports['after']['contracts']), normal_style_changes=changed, preserved_state_pixel_pairs=pixels, preserved_focus_ring_pixel_pairs=focus_pixels, source_sha256=source_hash, source_unchanged=True)
    (output / 'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print('Dialog actions PASS:', json.dumps(summary))


if __name__ == '__main__': main()

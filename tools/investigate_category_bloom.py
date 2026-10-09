"""Observe the accepted global Bloom path for issue #306, without changing it.

Tiny WVZ1 fixtures, native control input, render comparisons and timing telemetry.
This is baseline evidence, not validation of independent category Bloom.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture
from tools.package_linux import stage, build


def fixtures(output):
    for name in ['particles', 'fields', 'meshes', 'mixed']:
        objects = []
        if name in ['particles', 'mixed']:
            objects.append(dict(id='p', kind='particles', identity='persistent_i8', units='m'))
        if name in ['fields', 'mixed']:
            objects.append(dict(id='f', kind='volume', units='m'))
        if name in ['meshes', 'mixed']:
            objects.append(dict(id='m', kind='mesh', identity='none', units='m'))
        with SceneCapture(output / (name + '.wvz'), objects=objects) as writer:
            for obj in objects:
                if obj['kind'] == 'particles':
                    x, y = np.meshgrid(np.linspace(-3.6, -2.6, 7), np.linspace(-.6, .6, 7))
                    positions = np.column_stack([x.ravel(), y.ravel(), np.zeros(x.size)])
                    writer.add_particles('p', 0., positions, ids=np.arange(x.size, dtype='i8'))
                elif obj['kind'] == 'volume':
                    z, y, x = np.mgrid[-1.2:1.2:17j, -1.2:1.2:17j, -1.2:1.2:17j]
                    values = np.exp(-2 * (x*x + y*y + z*z))
                    writer.add_volume('f', 0., {'value': values}, origin=[-1.2]*3, spacing=[.15]*3)
                else:
                    writer.add_mesh('m', 0., [[2.5,-.8,0.], [3.7,-.8,0.], [3.7,.8,0.], [2.5,.8,0.]],
                                    [[0,1,2], [0,2,3]])


def package(godot, output):
    with tempfile.TemporaryDirectory(prefix='wavez-bloom-baseline-') as temporary:
        project = Path(temporary) / 'viewer'
        stage(project)
        script = (project / 'scene/investigate_category_bloom.gd').read_text()
        script = script.replace('extends SceneTree', 'extends Node\nvar root: Window:\n\tget: return get_tree().root\nvar process_frame: Signal:\n\tget: return get_tree().process_frame')
        script = script.replace('func _initialize()', 'func _ready()').replace('create_timer(', 'get_tree().create_timer(').replace('quit(', 'get_tree().quit(')
        (project / 'bloom_baseline.gd').write_text(script)
        (project / 'BloomBaseline.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://bloom_baseline.gd" id="1"]\n[node name="Review" type="Node"]\nscript = ExtResource("1")\n')
        config = project / 'project.godot'
        config.write_text(config.read_text().replace('res://Main.tscn', 'res://BloomBaseline.tscn'))
        binary = output / 'WAVEZ.x86_64'
        build(godot, project, binary, output / 'build-logs')
    return str(binary)


def difference(a, b, box=None):
    if box is not None:
        a, b = a.crop(box), b.crop(box)
    delta = np.abs(np.asarray(a.convert('RGB'), dtype=np.int16) - np.asarray(b.convert('RGB'), dtype=np.int16))
    return dict(changed_pixels=int(np.any(delta != 0, axis=2).sum()),
                mean_absolute_channel_delta=float(delta.mean()), max_channel_delta=int(delta.max()))


def comparisons(output, report):
    rows = []
    for case in report['cases']:
        name = case['name']
        a = Image.open(output / (name + '-zero.png'))
        b = Image.open(output / (name + '-high.png'))
        regions = {kind: difference(a, b, box) for kind, box in case['regions'].items()}
        rows.append(dict(name=name, full=difference(a, b), regions=regions))
        if case['preset'] == 'Scientific' and rows[-1]['full']['changed_pixels']:
            raise RuntimeError('Scientific Bloom comparison changed pixels: ' + name)
        if case['preset'] == 'Cinematic':
            present = ['particles', 'fields', 'meshes'] if case['scene'] == 'mixed' else [case['scene']]
            if any(regions[kind]['changed_pixels'] == 0 for kind in present):
                raise RuntimeError('No observable Cinematic change in a present category: ' + name)
    report['pixel_comparisons'] = rows
    for preset in ['Cinematic', 'Scientific']:
        sheet = Image.new('RGB', (960, 4*228), '#171b22')
        draw = ImageDraw.Draw(sheet)
        for row, scene in enumerate(['particles', 'fields', 'meshes', 'mixed']):
            for column, value in enumerate(['zero', 'default', 'high']):
                name = scene + '-' + preset
                path = output / (name + '-' + value + '.png')
                if not path.exists():
                    continue
                picture = Image.open(path).convert('RGB')
                picture.thumbnail((320, 208))
                sheet.paste(picture, (column*320, row*228+20))
                draw.text((column*320+5, row*228+3), f'{scene} / {preset} / {value}', fill='white')
        sheet.save(output / (preset.lower() + '-comparisons.png'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], required=True)
    parser.add_argument('--package', action='store_true')
    args = parser.parse_args()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=False)
    fixtures(output)
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in output.glob('*.wvz')}
    executable = package(args.godot, output) if args.package else args.godot
    command = [executable]
    if not args.package:
        command += ['--path', str(ROOT / 'viewer'), '--script', 'res://scene/investigate_category_bloom.gd']
    command += ['--rendering-method', args.renderer, '--resolution', '970x640', '--audio-driver', 'Dummy',
                '--disable-vsync', '--', str(output)]
    env = dict(os.environ, XDG_DATA_HOME=str(output/'profile'), XDG_CONFIG_HOME=str(output/'profile'))
    result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=240)
    log = result.stdout + result.stderr
    (output/'native.log').write_text(log)
    if result.returncode or 'ERROR:' in log or 'WARNING:' in log:
        raise RuntimeError(f'Baseline observation failed: {output}/native.log')
    report = json.loads((output/'report.json').read_text())
    if report['failures']:
        raise RuntimeError(report['failures'])
    if hashes != {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in output.glob('*.wvz')}:
        raise RuntimeError('Fixture bytes changed')
    report.update(source_hashes_unchanged=hashes, packaged=args.package,
                  godot=subprocess.check_output([args.godot, '--version'], text=True).strip(),
                  baseline_only=True)
    comparisons(output, report)
    (output/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'Bloom baseline: {report["checks"]} checks PASS ({args.renderer}, package={args.package}); independent Bloom unimplemented')


if __name__ == '__main__':
    main()

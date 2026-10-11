"""Focused native particle-size input, saved-state and dense visual checks (#367)."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.validate_simulation_panel import fixture
from tools.package_linux import stage, build
from wavez_export import SceneCapture


def validation_package(godot, out):
    # Release templates lack --script. Only the temporary entry changes; the
    # production viewer and particle control resources remain identical.
    with tempfile.TemporaryDirectory(prefix='wavez-particle-size-') as temporary:
        project = Path(temporary) / 'viewer'; stage(project)
        script = (project / 'ui/shell/test_particle_size.gd').read_text()
        script = script.replace('extends SceneTree', 'extends Node\nvar root: Window:\n\tget: return get_tree().root\nvar process_frame: Signal:\n\tget: return get_tree().process_frame')
        script = script.replace('func _initialize()', 'func _ready()').replace('create_timer(', 'get_tree().create_timer(').replace('quit(', 'get_tree().quit(')
        (project / 'particle_size_review.gd').write_text(script)
        (project / 'ParticleSizeReview.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://particle_size_review.gd" id="1"]\n[node name="ParticleSizeReview" type="Node"]\nscript = ExtResource("1")\n')
        settings = project / 'project.godot'
        settings.write_text(settings.read_text().replace('res://Main.tscn', 'res://ParticleSizeReview.tscn'))
        binary = out / 'WAVEZ-review.x86_64'
        build(godot, project, binary, out / 'build-logs')
    return str(binary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True, help='External editor or packaged Linux executable')
    parser.add_argument('--output-dir', required=True, type=Path)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--packaged', action='store_true', help='Run an existing validation-entry package')
    mode.add_argument('--export', action='store_true', help='Build a temporary Linux validation-entry package')
    parser.add_argument('--dense', action='store_true', help='Also render 100,000 markers at 1080p and 4K')
    args = parser.parse_args()
    out = args.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    fixture(out / 'mixed.wvz', ['particles', 'volume', 'mesh'])
    if args.dense:
        rng = np.random.default_rng(367)
        positions = rng.uniform(-1, 1, (100000, 3))
        for name, points in [('dense', positions), ('marker', np.zeros((1, 3)))]:
            with SceneCapture(out / (name + '.wvz'), objects=[dict(
                    id='p', kind='particles', identity='persistent_i8', units='m')],
                    metadata={'time_unit': 's', 'position_unit': 'm'}) as writer:
                for time in [0., 1.]:
                    writer.add_particles('p', time, points,
                        ids=np.arange(len(points), dtype='i8') + 9007199254740993,
                        value=np.linspace(0, 1, len(points)))
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.wvz')}
    packaged = args.packaged or args.export
    command = [validation_package(args.godot, out) if args.export else args.godot]
    if not packaged: command += ['--path', str(ROOT / 'viewer'), '--script', 'res://ui/shell/test_particle_size.gd']
    command += ['--audio-driver', 'Dummy', '--rendering-method', 'forward_plus',
                '--rendering-driver', 'vulkan', '--resolution', '1440x900',
                '--log-file', str(out / 'godot.log'), '--', str(out)]
    if args.dense: command += ['dense']
    with (out / 'native.log').open('w') as log:
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=240)
    log = (out / 'native.log').read_text()
    assert result.returncode == 0 and (out / 'report.json').exists(), out / 'native.log'
    report = json.loads((out / 'report.json').read_text())
    assert result.returncode == 0 and not report['failures'], out / 'native.log'
    assert hashes == {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.wvz')}
    report['source_hashes_unchanged'] = hashes
    report['packaged'] = packaged
    (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    assert 'ERROR:' not in log and 'WARNING:' not in log, out / 'native.log'
    print(f'Particle size: {report["checks"]} PASS (Forward+ Vulkan); sources unchanged')


if __name__ == '__main__': main()

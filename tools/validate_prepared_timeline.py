"""Focused resident scene coverage, underflow and visual presence checks."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import hashlib
import numpy as np
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture
from tools.package_linux import stage, build


def fixtures(out):
    out.mkdir(parents=True, exist_ok=True)
    for case in ['particles', 'fields', 'meshes', 'mixed', 'static']:
        objects = []
        if case in ['particles', 'mixed']:objects.append(dict(id='p', kind='particles', units='m', identity='anonymous'))
        if case in ['fields', 'mixed', 'static']:objects.append(dict(id='f', kind='volume', units='m'))
        if case in ['meshes', 'static']:objects.append(dict(id='m', kind='mesh', units='m', identity='stable_topology', static=case == 'static'))
        path = out / (case + '.wvz');path.unlink(missing_ok=True)
        with SceneCapture(path, objects=objects) as w:
            for i in range(41):
                if case in ['particles', 'mixed']:w.add_particles('p', i, np.array([[i*.01, 0, 0], [0, 1, 0]], dtype='f4'), scalar=np.array([i, i+1], dtype='f4'))
                if case in ['fields', 'mixed', 'static']:w.add_volume('f', i, dict(rho=np.full((2, 2, 2), i+1, dtype='f4'), other=np.full((2, 2, 2), i+2, dtype='f4')), origin=[0]*3, spacing=[1]*3)
                if case == 'meshes' or (case == 'static' and i == 5):w.add_mesh('m', i, np.array([[0, 0, 0], [1, 0, 0], [0, 1, i*.01]], dtype='f4'), np.array([[0, 1, 2]], dtype='u4'), vertex_channels=dict(vertex_id=np.arange(3, dtype='i8')))


def validation_package(godot, out):
    # Release templates ignore --script. Convert only the temporary test entry;
    # production viewer resources and the real controllers stay unchanged.
    with tempfile.TemporaryDirectory(prefix='wavez-timeline-review-') as temporary:
        project = Path(temporary) / 'viewer';stage(project)
        base = project / 'prepared_review_base.gd'
        text = (project / 'layers/test_scene_playback.gd').read_text().split('func run() -> void:')[0].replace('extends SceneTree', 'extends Node\nvar root: Window:\n\tget: return get_tree().root\nvar process_frame: Signal:\n\tget: return get_tree().process_frame')
        base.write_text(text.replace('func _initialize()', 'func _ready()')+'func run() -> void:pass\n')
        entry = project / 'ui/shell/test_prepared_timeline.gd'
        entry.write_text(entry.read_text().replace('res://layers/test_scene_playback.gd', 'res://prepared_review_base.gd').replace('quit(', 'get_tree().quit('))
        (project / 'PreparedReview.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://ui/shell/test_prepared_timeline.gd" id="1"]\n[node name="PreparedReview" type="Node"]\nscript = ExtResource("1")\n')
        settings = project / 'project.godot';settings.write_text(settings.read_text().replace('res://Main.tscn', 'res://PreparedReview.tscn'))
        binary = out / 'WAVEZ-review.x86_64';build(godot, project, binary, out / 'build-logs')
    return str(binary)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--output-dir', type=Path, required=True)
    p.add_argument('--renderer', choices=['headless', 'forward_plus'], default='headless')
    mode = p.add_mutually_exclusive_group()
    mode.add_argument('--packaged', action='store_true', help='Existing validation-entry package')
    mode.add_argument('--export', action='store_true', help='Export a temporary validation-entry package')
    a = p.parse_args();out = a.output_dir.resolve();out.mkdir(parents=True, exist_ok=False)
    fixtures(out/'fixtures')
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (out/'fixtures').glob('*.wvz')}
    packaged = a.packaged or a.export
    cmd = [validation_package(a.godot, out) if a.export else a.godot, '--audio-driver', 'Dummy']
    if not packaged:cmd += ['--path', str(ROOT/'viewer'), '--script', 'res://ui/shell/test_prepared_timeline.gd']
    cmd += ['--headless'] if a.renderer == 'headless' else ['--rendering-method', a.renderer, '--resolution', '1440x900']
    cmd += ['--', '--playback-fixture='+str(out/'fixtures')]
    env = dict(os.environ, XDG_DATA_HOME=str(out/'data'), XDG_CONFIG_HOME=str(out/'config'))
    with (out/'native.log').open('w') as log_file:
        r = subprocess.run(cmd, stdout=log_file, stderr=subprocess.STDOUT, timeout=180, env=env)
    log = (out/'native.log').read_text()
    report = json.loads((out/'fixtures'/'prepared-timeline.json').read_text())
    unchanged = hashes == {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (out/'fixtures').glob('*.wvz')}
    (out/'summary.json').write_text(json.dumps(dict(checks=report['checks'], failures=report['failures'], exit_code=r.returncode, renderer=a.renderer, packaged=packaged, source_hashes=hashes, sources_unchanged=unchanged), indent=2)+'\n')
    print(json.dumps(dict(checks=report['checks'], failures=report['failures'], exit_code=r.returncode)))
    if r.returncode or report['failures'] or not unchanged or 'ERROR:' in log:raise SystemExit(1)


if __name__ == '__main__':main()

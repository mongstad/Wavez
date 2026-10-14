"""Focused application preset/Bloom preferences across fresh native processes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.validate_global_bloom import fixtures
from tools.package_linux import stage, build
from wavez_export import SceneCapture


def package(godot, output):
    with tempfile.TemporaryDirectory(prefix='wavez-view-preferences-') as temporary:
        project = Path(temporary) / 'viewer'
        stage(project)
        script = (project/'scene/test_view_preferences.gd').read_text()
        script = script.replace('extends SceneTree', 'extends Node\nvar root: Window:\n\tget: return get_tree().root\nvar process_frame: Signal:\n\tget: return get_tree().process_frame')
        script = script.replace('func _initialize()', 'func _ready()').replace('create_timer(', 'get_tree().create_timer(').replace('quit(', 'get_tree().quit(')
        (project/'preference_review.gd').write_text(script)
        (project/'PreferenceReview.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://preference_review.gd" id="1"]\n[node name="Review" type="Node"]\nscript = ExtResource("1")\n')
        config = project/'project.godot'
        config.write_text(config.read_text().replace('res://Main.tscn', 'res://PreferenceReview.tscn'))
        binary = output/'WAVEZ.x86_64'
        build(godot, project, binary, output/'build-logs')
    return str(binary)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--package', action='store_true')
    a = p.parse_args()
    output = a.output.resolve();output.mkdir(parents=True, exist_ok=False)
    fixtures(output)
    with SceneCapture(output/'named.wvz', objects=[dict(id='p',kind='particles',identity='persistent_i8',units='m')]) as writer:
        for t in [0.,.5,1.]:
            writer.add_particles('p',t,np.array([[0,0,0],[1,0,0]],dtype='f8'),ids=[1,2],temperature=np.array([10,20],dtype='f8'),density=np.array([1,2],dtype='f8'),velocity_magnitude=np.array([.2,.4],dtype='f8'))
    hashes = {f.name: hashlib.sha256(f.read_bytes()).hexdigest() for f in output.glob('*.wvz')}
    profile = output/'profile'
    env = dict(os.environ, XDG_DATA_HOME=str(profile), XDG_CONFIG_HOME=str(profile))
    executable = package(a.godot, output) if a.package else a.godot
    command = [executable] + ([] if a.package else ['--path', str(ROOT/'viewer'), '--script', 'res://scene/test_view_preferences.gd'])
    command += ['--rendering-method', 'forward_plus', '--audio-driver', 'Dummy', '--resolution', '1440x900', '--']
    reports = {}
    for phase in ['fresh', 'restart', 'named', 'corrupt', 'missing']:
        if phase in ['corrupt', 'missing']:
            paths = list(profile.rglob('view_preferences.json'))
            assert len(paths) == 1, paths
            if phase == 'corrupt': paths[0].write_text('{"version":1,"settings":{"preset":"wrong"}}')
            else: paths[0].unlink()
        extra = ['--capture='+str(output/'named.wvz')] if phase == 'named' else []
        result = subprocess.run(command+[str(output),phase]+extra, env=env, capture_output=True, text=True, timeout=110)
        log = result.stdout+result.stderr;(output/(phase+'.log')).write_text(log)
        if result.returncode or 'ERROR:' in log or 'WARNING:' in log: raise RuntimeError(output/(phase+'.log'))
        report = json.loads((output/(phase+'-report.json')).read_text());assert not report['failures']
        reports[phase] = report
        print(phase, report['checks'], 'PASS', flush=True)
    assert hashes == {f.name: hashlib.sha256(f.read_bytes()).hexdigest() for f in output.glob('*.wvz')}
    (output/'summary.json').write_text(json.dumps(dict(packaged=a.package, reports=reports, source_hashes_unchanged=hashes),indent=2)+'\n')


if __name__ == '__main__': main()

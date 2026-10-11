"""Mixed-particle budget, direction, reuse, pressure and coverage contracts."""
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
from wavez_export import SceneCapture
from tools.package_linux import stage, build


def fixture(path):
    with SceneCapture(path, objects=[dict(id='p',kind='particles',identity='persistent_i8',units='m'),dict(id='f',kind='volume',units='m')]) as w:
        for i in range(81):
            n = 256 if i % 7 < 4 else 1024
            pos = np.zeros((n,3),dtype='f4');pos[:,0] = np.arange(n)*.01;pos[:,1] = i*.01
            ids = np.arange(n,dtype='i8');ids[256:] += i*10000
            w.add_particles('p',i*.1,pos,ids=ids,velocity=pos*.1,scalar=np.full(n,i,dtype='f4'))
            if i % 10 == 0:w.add_volume('f',i*.1,dict(rho=np.full((2,2,2),i,dtype='f4')),origin=[0]*3,spacing=[1]*3)


def package(godot, out):
    with tempfile.TemporaryDirectory(prefix='wavez-runway-review-') as tmp:
        project = Path(tmp)/'viewer';stage(project)
        base = project/'runway_review_base.gd'
        text = (project/'layers/test_scene_playback.gd').read_text().split('func run() -> void:')[0].replace('extends SceneTree','extends Node\nvar root: Window:\n\tget: return get_tree().root\nvar process_frame: Signal:\n\tget: return get_tree().process_frame')
        base.write_text(text.replace('func _initialize()','func _ready()')+'func run() -> void:pass\n')
        entry = project/'layers/test_particle_runway.gd'
        entry.write_text(entry.read_text().replace('res://layers/test_scene_playback.gd','res://runway_review_base.gd').replace('quit(','get_tree().quit('))
        (project/'RunwayReview.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://layers/test_particle_runway.gd" id="1"]\n[node name="RunwayReview" type="Node"]\nscript = ExtResource("1")\n')
        settings = project/'project.godot';settings.write_text(settings.read_text().replace('res://Main.tscn','res://RunwayReview.tscn'))
        binary = out/'WAVEZ-review.x86_64';build(godot,project,binary,out/'build-logs')
    return str(binary)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot',required=True);p.add_argument('--output-dir',type=Path,required=True)
    p.add_argument('--renderer',choices=['headless','forward_plus'],default='headless');p.add_argument('--export',action='store_true')
    a = p.parse_args();out = a.output_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    fixture(out/'mixed.wvz');before = hashlib.sha256((out/'mixed.wvz').read_bytes()).hexdigest()
    cmd = [package(a.godot,out) if a.export else a.godot,'--audio-driver','Dummy']
    if not a.export:cmd += ['--path',str(ROOT/'viewer'),'--script','res://layers/test_particle_runway.gd']
    cmd += ['--headless'] if a.renderer == 'headless' else ['--rendering-method',a.renderer,'--resolution','960x640']
    cmd += ['--','--playback-fixture='+str(out)]
    with (out/'native.log').open('w') as log:
        r = subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=180,env=dict(os.environ,XDG_DATA_HOME=str(out/'data'),XDG_CONFIG_HOME=str(out/'config')))
    report = json.loads((out/'particle-runway.json').read_text())
    unchanged = before == hashlib.sha256((out/'mixed.wvz').read_bytes()).hexdigest()
    summary = dict(checks=report['checks'],failures=report['failures'],exit_code=r.returncode,renderer=a.renderer,packaged=a.export,source_sha256=before,source_unchanged=unchanged)
    (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))
    if r.returncode or report['failures'] or not unchanged or 'ERROR:' in (out/'native.log').read_text():raise SystemExit(1)


if __name__ == '__main__':main()

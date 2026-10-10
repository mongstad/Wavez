import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT))
from tools.package_linux import stage,build
p=argparse.ArgumentParser();p.add_argument('--renderer',default='forward_plus');p.add_argument('--package',action='store_true');p.add_argument('--output',type=Path,required=True);a=p.parse_args()
out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
godot=os.environ['GODOT']
profile=out/'profile'
env=dict(os.environ,XDG_DATA_HOME=str(profile),XDG_CONFIG_HOME=str(profile))
script=Path(__file__).with_name('measure.gd')
if a.package:
    with tempfile.TemporaryDirectory(prefix='wavez-316-review-') as temporary:
        project=Path(temporary)/'viewer';stage(project)
        content=script.read_text().replace('extends SceneTree','extends Node\nvar root: Window:\n\tget: return get_tree().root\nvar process_frame: Signal:\n\tget: return get_tree().process_frame')
        content=content.replace('func _initialize()','func _ready()').replace('create_timer(','get_tree().create_timer(').replace('quit(','get_tree().quit(')
        (project/'PinReview.gd').write_text(content)
        (project/'PinReview.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://PinReview.gd" id="1"]\n[node name="Review" type="Node"]\nscript = ExtResource("1")\n')
        settings=project/'project.godot';settings.write_text(settings.read_text().replace('res://Main.tscn','res://PinReview.tscn'))
        binary=out/'WAVEZ.x86_64';build(godot,project,binary,out/'build-logs')
    command=[str(binary)]
else:
    command=[godot,'--path',str(ROOT/'viewer'),'--script',str(script)]
for phase,choice in [('cycle',None),('restart-light','Light'),('restart-dark','Dark')]:
    destination=out if choice is None else out/phase
    destination.mkdir(exist_ok=True)
    args=command+['--rendering-method',a.renderer,'--audio-driver','Dummy','--resolution','1440x900','--',str(destination)]
    if choice:args.append(choice)
    r=subprocess.run(args,cwd=out,env=env,capture_output=True,text=True,timeout=120)
    log=r.stdout+r.stderr;(out/(phase+'.log')).write_text(log)
    if r.returncode or 'ERROR:' in log or 'WARNING:' in log:raise RuntimeError(str(out/(phase+'.log')))
    report=json.loads((destination/'report.json').read_text())
    if choice:assert report['restart']['light']==(choice=='Light')
print('Clean cycle and fresh Light/Dark restarts:',a.renderer,'package=',a.package)

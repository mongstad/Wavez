"""Bounded, opt-in Forward+ Bloom experiment; production code is unchanged."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import shutil
import tempfile
import xml.etree.ElementTree as ET

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture
from tools.verify_wvz import verify
from tools.package_linux import stage,build

def package(godot,output):
    # Validation package plus explicitly external canonical extraction helper.
    with tempfile.TemporaryDirectory(prefix='wavez-306-forward-package-') as temp:
        project=Path(temp)/'viewer';stage(project)
        driver=project/'scene/prototype_category_bloom_forward.gd'
        code=driver.read_text().replace('extends SceneTree','extends Node\nvar root: Window:\n\tget: return get_tree().root\nvar process_frame: Signal:\n\tget: return get_tree().process_frame')
        code=code.replace('func _initialize()','func _ready()').replace('create_timer(','get_tree().create_timer(').replace('quit(','get_tree().quit(')
        driver.write_text(code)
        (project/'BloomForward.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scene/prototype_category_bloom_forward.gd" id="1"]\n[node name="Prototype" type="Node"]\nscript = ExtResource("1")\n')
        config=project/'project.godot';config.write_text(config.read_text().replace('res://Main.tscn','res://BloomForward.tscn'))
        destination=output/'validation-package';(destination/'viewer').mkdir(parents=True,exist_ok=True)
        binary=destination/'viewer/WAVEZ.x86_64';build(godot,project,binary,destination/'build-logs')
    (destination/'tools').mkdir(exist_ok=True)
    shutil.copyfile(ROOT/'tools/extract_surface.py',destination/'tools/extract_surface.py')
    shutil.copytree(ROOT/'wavez_export',destination/'wavez_export',ignore=shutil.ignore_patterns('__pycache__'),dirs_exist_ok=True)
    return str(binary)


def fixtures(output):
    for index,name in enumerate(['particles', 'separated', 'overlap', 'occluded', 'slice', 'iso', 'heavy']):
        rng = np.random.default_rng(306+index)
        if (output/(name+'.wvz')).exists(): continue
        heavy = name == 'heavy'
        objects = [dict(id='p', kind='particles', identity='persistent_i8', units='m')]
        if name != 'particles':
            objects += [dict(id='f', kind='volume', units='m'), dict(id='m', kind='mesh', identity='none', units='m')]
        if heavy:
            objects += [dict(id='f2', kind='volume', units='m'), dict(id='f3', kind='volume', units='m'), dict(id='m2', kind='mesh', identity='none', units='m')]
        count = 100_000 if heavy else 169
        points = rng.uniform([-2.4, -1.8, -1.0], [2.4, 1.8, 1.0], (count, 3)) if heavy else np.array([[x, y, 0.] for x in np.linspace(-.65,.65,13) for y in np.linspace(-.65,.65,13)])
        if name in ['separated', 'particles']: points[:, 0] -= 2.5
        if name in ['occluded', 'slice', 'iso']: points[:, 2] = -1.5
        if name in ['slice','iso']:points[:,:2] *= 2.5
        n = 64 if heavy else 25
        z,y,x = np.mgrid[-1.2:1.2:complex(n), -1.2:1.2:complex(n), -1.2:1.2:complex(n)]
        field = np.exp(-2 * (x*x+y*y+z*z)).astype('f4')
        if heavy:
            axis = np.linspace(-2.5,2.5,101)
            mx,my = np.meshgrid(axis,axis)
            mesh = np.column_stack([mx.ravel(),my.ravel(),np.full(mx.size,-.4)])
            a = np.arange(100)[:,None]*101+np.arange(100)[None,:]
            triangles = np.stack([np.stack([a,a+1,a+102],-1),np.stack([a,a+102,a+101],-1)],-2).reshape(-1,3)
        else:
            center = 2.5 if name == 'separated' else .6
            half = 2.1 if name == 'occluded' else .55
            depth = 2.0 if name == 'occluded' else .6
            mesh = np.array([[center-half,-half,depth],[center+half,-half,depth],[center+half,half,depth],[center-half,half,depth]])
            if name == 'occluded': mesh[:,0] -= center
            triangles = [[0,1,2],[0,2,3]]
        with SceneCapture(output/(name+'.wvz'),objects=objects) as writer:
            for frame in range(8 if heavy else 3):
                t = frame/(7 if heavy else 2)
                shift = np.array([.15*np.sin(t*2),.08*t,0.])
                writer.add_particles('p',t,(points+shift).astype('f4'),ids=np.arange(count,dtype='i8'))
                if name != 'particles':
                    writer.add_volume('f',t,{'value':field},origin=[-1.2]*3,spacing=[2.4/(n-1)]*3)
                    writer.add_mesh('m',t,(mesh+shift).astype('f4'),triangles,vertex_channels={'value':np.linspace(0,1,len(mesh),dtype='f4')})
                if heavy:
                    writer.add_volume('f2',t,{'value':field*.8},origin=[-.5,-1.2,-2.5],spacing=[2.4/(n-1)]*3)
                    writer.add_volume('f3',t,{'value':field*.7},origin=[-2.5,-.8,-1.5],spacing=[2.4/(n-1)]*3)
                    writer.add_mesh('m2',t,(mesh+shift+np.array([.4,.3,-1])).astype('f4'),triangles)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',required=True)
    parser.add_argument('--output-dir',type=Path,required=True)
    parser.add_argument('--project',type=Path,default=ROOT/'viewer')
    parser.add_argument('--baseline',action='store_true')
    parser.add_argument('--smoke',action='store_true')
    parser.add_argument('--fixtures-only',action='store_true')
    parser.add_argument('--renderer',choices=['forward_plus','gl_compatibility'],default='forward_plus')
    parser.add_argument('--isolation-only',action='store_true')
    parser.add_argument('--transitions',action='store_true')
    parser.add_argument('--package',action='store_true')
    args=parser.parse_args()
    output=args.output_dir.resolve(); output.mkdir(parents=True,exist_ok=True)
    fixtures(output)
    if args.fixtures_only: return
    hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in output.glob('*.wvz')}
    verified={p.name:verify(p) for p in output.glob('*.wvz')}
    expected={name+'.wvz':(48 if name=='heavy' else (3 if name=='particles' else 9)) for name in ['particles','separated','overlap','occluded','slice','iso','heavy']}
    assert verified==expected,'All seven complete fixtures are required'
    label='baseline' if args.baseline else ('transitions' if args.transitions else ('smoke' if args.smoke else ('isolation' if args.isolation_only or args.package else 'prototype')))
    command=[args.godot,'--path',str(args.project.resolve()),'--script','res://scene/prototype_category_bloom_forward.gd','--rendering-method',args.renderer,'--audio-driver','Dummy','--disable-vsync','--resolution','960x640','--',str(output),label]
    if args.package:command=[package(args.godot,output)]+command[5:]
    env=dict(os.environ,XDG_DATA_HOME=str(output/(label+'-profile')),XDG_CONFIG_HOME=str(output/(label+'-profile')))
    log_file=(output/(label+'.log')).open('w')
    process=subprocess.Popen(command,cwd=ROOT,env=env,stdout=log_file,stderr=subprocess.STDOUT,text=True)
    started=time.monotonic()
    telemetry=[]
    while process.poll() is None:
        if 'ERROR:' in (output/(label+'.log')).read_text():
            process.terminate();process.wait(timeout=15)
            break
        if time.monotonic()-started>1500:
            process.kill();process.wait();log_file.close()
            raise RuntimeError('Native prototype exceeded its bounded timeout')
        values=subprocess.run(['nvidia-smi','--query-gpu=timestamp,memory.used,memory.free,utilization.gpu','--format=csv,noheader,nounits'],capture_output=True,text=True)
        process_memory=None
        xml=subprocess.run(['nvidia-smi','-q','-x'],capture_output=True,text=True)
        if xml.returncode==0:
            for entry in ET.fromstring(xml.stdout).findall('.//process_info'):
                if entry.findtext('pid')==str(process.pid):process_memory=entry.findtext('used_memory')
        telemetry.append({'time':time.time(),'gpu':values.stdout.strip(),'process_vram':process_memory,'error':values.stderr.strip()})
        time.sleep(.25)
    log_file.close();log=(output/(label+'.log')).read_text()
    (output/(label+'-device-telemetry.json')).write_text(json.dumps(telemetry,indent=2)+'\n')
    if process.returncode or 'ERROR:' in log or 'WARNING:' in log:raise RuntimeError(f'Prototype failed: {output}/{label}.log')
    report=json.loads((output/(label+'.json')).read_text())
    if report['failures']:raise RuntimeError(report['failures'])
    assert hashes=={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in output.glob('*.wvz')}
    report.update(source_hashes_unchanged=hashes,strict_verified_records=verified,device_telemetry_samples=len(telemetry),native_command=command,validation_package=args.package)
    (output/(label+'.json')).write_text(json.dumps(report,indent=2)+'\n')
    print(f'{label}: {report["checks"]} checks; {len(report["failures"])} failures; {len(report["benchmarks"])} benchmarks')


if __name__=='__main__':main()

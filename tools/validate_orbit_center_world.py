"""PR #301 world-anchoring reproduction with stationary transformed scientific landmarks."""
import argparse
import hashlib
import itertools
import json
import os
from pathlib import Path
import subprocess
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture
from tools.package_linux import build, stage


def fixtures(out):
    # The owner coordinates locate this synthetic scene only; they are not a
    # reconstruction of the owner capture. Rotation, nonuniform scale and
    # translation exercise the actual data-to-world path for field and mesh.
    angle = np.deg2rad(23.)
    matrix = np.array([[np.cos(angle), -.8*np.sin(angle), 0., 74.53],
                       [np.sin(angle), .8*np.cos(angle), 0., -67.15],
                       [0., 0., 1.2, -239.17]])
    affine = matrix.ravel().tolist()
    def world(points):
        return np.asarray(points) @ matrix[:, :3].T + matrix[:, 3]
    centers = np.array([[0., 0., 0.], [60., 35., -24.], [-40., -30., 48.]])
    rng = np.random.default_rng(301)
    points = np.concatenate([centers, *[rng.normal(c, [7., 4., 5.], (96, 3)) for c in centers]])
    # Asymmetric wedge with source vertices identified independently of placement.
    vertices = np.array([[0,0,0],[60,35,-24],[-40,-30,48], [0,0,12],[60,35,-12],[-40,-30,60]], dtype='f8')
    triangles = np.array([[0,1,2],[3,5,4],[0,3,4],[0,4,1],[1,4,5],[1,5,2],[2,5,3],[2,3,0]], dtype='i8')
    origin = np.array([-120., -100., -96.]); spacing = np.array([5., 5., 6.])
    zz, yy, xx = np.indices((33, 41, 49))
    xyz = np.stack((xx, yy, zz), axis=-1)*spacing + origin
    density = sum(weight*np.exp(-np.sum(((xyz-c)/width)**2, axis=-1))
                  for c, width, weight in zip(centers, ([17,10,12], [13,20,10], [9,14,18]), (1., .75, .55)))
    corners = world(list(itertools.product(*zip(origin, origin+spacing*[48,40,32]))))
    manifest = {'synthetic_owner_coordinate_context': True, 'data_to_world': affine,
                'field_dimensions': [49,41,33], 'field_origin': origin.tolist(),
                'field_spacing': spacing.tolist(), 'landmarks': {},
                'expected_world_bounds': [corners.min(axis=0).tolist(), corners.max(axis=0).tolist()]}
    for kind in ('particles','mesh','field','mixed'):
        objects = []
        if kind in ('particles','mixed'): objects.append(dict(id='p',kind='particles',identity='persistent_i8',units='m'))
        if kind in ('mesh','mixed'): objects.append(dict(id='mesh',kind='mesh',identity='stable_topology',units='m',data_to_world=affine))
        if kind in ('field','mixed'): objects.append(dict(id='field',kind='volume',units='m',data_to_world=affine))
        with SceneCapture(out / f'world-{kind}.wvz', objects=objects, compression='none') as writer:
            for time in (0.,1.):
                if kind in ('particles','mixed'): writer.add_particles('p',time,world(points),ids=np.arange(len(points),dtype='i8'))
                if kind in ('mesh','mixed'): writer.add_mesh('mesh',time,vertices,triangles,vertex_channels={'feature':np.arange(len(vertices),dtype='f8'),'vertex_id':np.arange(len(vertices),dtype='i8')})
                if kind in ('field','mixed'): writer.add_volume('field',time,{'density':density.astype('f8')},origin=origin,spacing=spacing)
        # A and B are exact source positions; field A is exactly grid [24,20,16],
        # B uses an exact grid node close to the second density maximum.
        manifest['landmarks'][kind] = []
        for index, local in enumerate(centers[:2]):
            grid = np.round((local-origin)/spacing).astype(int)
            manifest['landmarks'][kind].append(dict(name=('A' if index == 0 else 'B'), index=index,
                grid=grid.tolist(), expected_world=world([origin+grid*spacing if kind == 'field' else local])[0].tolist()))
    (out/'world-fixtures.json').write_text(json.dumps(manifest,indent=2)+'\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',required=True)
    parser.add_argument('--output-dir',type=Path,required=True)
    parser.add_argument('--project',type=Path,default=ROOT/'viewer')
    parser.add_argument('--renderer',choices=('headless','forward_plus','gl_compatibility'),default='headless')
    parser.add_argument('--expect-explicit-depth',action='store_true')
    parser.add_argument('--skip-import',action='store_true')
    parser.add_argument('--export',action='store_true',help='Build an external release executable with this validation entry scene')
    parser.add_argument('--packaged',action='store_true',help='Run an already exported validation executable')
    args = parser.parse_args()
    if args.export and args.packaged: parser.error('Choose --export or --packaged')
    out=args.output_dir.resolve();out.mkdir(parents=True,exist_ok=False);fixtures(out)
    hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.wvz')}
    env=dict(os.environ,XDG_CONFIG_HOME=str(out/'config'),XDG_DATA_HOME=str(out/'userdata'))
    executable = args.godot
    package = None
    if args.export:
        project = out / 'export-source'
        inventory = stage(project)
        parent = (project/'ui/shell/test_orbit_center_view.gd').read_text()
        child = (project/'ui/shell/test_orbit_center_world.gd').read_text()
        script = parent[:parent.index('func run() -> void:')] + child.split('\n',1)[1]
        script = script.replace('extends SceneTree', 'extends Node\nvar root: Window:\n\tget: return get_tree().root\nvar process_frame: Signal:\n\tget: return get_tree().process_frame')
        script = script.replace('func _initialize()', 'func _ready()').replace('create_timer(', 'get_tree().create_timer(').replace('quit(', 'get_tree().quit(')
        (project/'ui/shell/orbit_center_world_entry.gd').write_text(script)
        (project/'OrbitCenterWorldValidation.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://ui/shell/orbit_center_world_entry.gd" id="1"]\n[node name="OrbitCenterWorldValidation" type="Node"]\nscript = ExtResource("1")\n')
        config = project/'project.godot'
        config.write_text(config.read_text().replace('run/main_scene="res://Main.tscn"','run/main_scene="res://OrbitCenterWorldValidation.tscn"'))
        binary = out/'WAVEZ-world-validation.x86_64'
        build(args.godot, project, binary, out/'build-logs')
        executable = str(binary); args.packaged = True
        package = dict(test_entry_scene=True, first_party_python=inventory,
                       artifacts={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (binary,binary.with_suffix('.pck'))})
    base = [executable]
    if not args.packaged: base += ['--path',str(args.project.resolve())]
    if not args.skip_import and not args.packaged:
        result=subprocess.run(base+['--headless','--editor','--import'],env=env,capture_output=True,text=True,timeout=180)
        log=result.stdout+result.stderr;(out/'import.log').write_text(log)
        if result.returncode or 'ERROR:' in log: raise RuntimeError(f'Import failed: {out / "import.log"}')
    command=base+(['--headless'] if args.renderer=='headless' else ['--rendering-method',args.renderer])
    command+=['--resolution','1440x900','--audio-driver','Dummy']
    if not args.packaged: command+=['--script','res://ui/shell/test_orbit_center_world.gd']
    command+=['--','--orbit-view-output='+str(out)]
    if args.expect_explicit_depth:command.append('--expect-explicit-depth')
    result=subprocess.run(command,env=env,capture_output=True,text=True,timeout=240)
    log=result.stdout+result.stderr;(out/'native.log').write_text(log)
    path=out/'orbit-world-report.json'
    if not path.is_file():raise RuntimeError(f'No completed report: {out / "native.log"}')
    report=json.loads(path.read_text());report.update(command=command,returncode=result.returncode,source_sha256=hashes,packaged=args.packaged,package_build=package,
       source_hashes_unchanged=hashes=={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.wvz')},
       diagnostics=[line for line in log.splitlines() if 'ERROR:' in line or 'WARNING:' in line])
    report['status']='PASS' if not report['failures'] and not report['diagnostics'] and report['source_hashes_unchanged'] and result.returncode==0 else 'FAIL'
    path.write_text(json.dumps(report,indent=2)+'\n')
    print(f"WORLD ANCHOR: {report['checks']} checks, {len(report['failures'])} failures ({args.renderer}); {report['status']}")
    return 0 if report['status']=='PASS' else 1

if __name__=='__main__':raise SystemExit(main())

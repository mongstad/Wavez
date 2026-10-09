"""Native global Bloom interaction, saved-state regression and pixel evidence."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.package_linux import stage, build
from tools.verify_wvz import verify
from wavez_export import SceneCapture


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
            for time in [0., .5, 1.]:
                for obj in objects:
                    if obj['kind'] == 'particles':
                        x, y = np.meshgrid(np.linspace(-3.6, -2.6, 7), np.linspace(-.6, .6, 7))
                        positions = np.column_stack([x.ravel(), y.ravel(), np.full(x.size, time*.2)])
                        writer.add_particles('p', time, positions, ids=np.arange(x.size, dtype='i8'))
                    elif obj['kind'] == 'volume':
                        z, y, x = np.mgrid[-1.2:1.2:17j, -1.2:1.2:17j, -1.2:1.2:17j]
                        values = np.exp(-2 * (x*x + y*y + z*z)) + time*.1
                        writer.add_volume('f', time, {'value': values}, origin=[-1.2]*3, spacing=[.15]*3)
                    else:
                        writer.add_mesh('m', time, [[2.5,-.8,time*.2], [3.7,-.8,time*.2],
                                                  [3.7,.8,time*.2], [2.5,.8,time*.2]], [[0,1,2], [0,2,3]])


def package(godot, source, output):
    with tempfile.TemporaryDirectory(prefix='wavez-global-bloom-') as temporary:
        project = Path(temporary) / 'viewer'
        stage(project, source)
        script = (ROOT / 'viewer/scene/test_global_bloom.gd').read_text()
        script = script.replace('extends SceneTree', 'extends Node\nvar root: Window:\n\tget: return get_tree().root\nvar process_frame: Signal:\n\tget: return get_tree().process_frame')
        script = script.replace('func _initialize()', 'func _ready()').replace('create_timer(', 'get_tree().create_timer(').replace('quit(', 'get_tree().quit(')
        (project / 'global_bloom.gd').write_text(script)
        (project / 'GlobalBloom.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://global_bloom.gd" id="1"]\n[node name="Review" type="Node"]\nscript = ExtResource("1")\n')
        config = project / 'project.godot'
        config.write_text(config.read_text().replace('res://Main.tscn', 'res://GlobalBloom.tscn'))
        binary = output / 'WAVEZ.x86_64'
        build(godot, project, binary, output / 'build-logs')
    return str(binary)


def pixels(path):
    return np.asarray(Image.open(path).convert('RGB'), dtype=np.int16)


def export_comparison(godot, accepted, fixtures_dir, output):
    """Exercise unchanged production workers and a normal Linux release package."""
    capture = fixtures_dir/'mixed.wvz'
    digest = hashlib.sha256(capture.read_bytes()).hexdigest()
    records = verify(capture)
    results = []
    with tempfile.TemporaryDirectory(prefix='wavez-global-bloom-exports-') as temporary:
        projects = {}
        for label, source in [('accepted',accepted),('candidate',ROOT)]:
            project = Path(temporary)/label/'viewer';stage(project,source);projects[label] = project
            log = output/(label+'-import.log')
            with log.open('w') as stream:
                result = subprocess.run([godot,'--headless','--path',str(project),'--editor','--import'],
                                        stdout=stream,stderr=subprocess.STDOUT,timeout=180,
                                        env=dict(os.environ,XDG_CONFIG_HOME=str(output/(label+'-editor-profile'))))
            assert result.returncode == 0 and 'ERROR:' not in log.read_text(), log
        binary = output/'WAVEZ.x86_64'
        build(godot,projects['candidate'],binary,output/'build-logs')
        for renderer in ['forward_plus','gl_compatibility']:
            for preset in ['Cinematic','Scientific']:
                chosen = json.loads((fixtures_dir/(preset+'-video-state.json')).read_text())
                for label in ['accepted','candidate','package']:
                    name = f'{label}-{renderer}-{preset}';directory = output/name;directory.mkdir()
                    job = dict(version=1,capture_path=str(capture),state=chosen,start_time=0.,end_time=.75,
                               fps=4,playback_rate=1.,width=640,height=360,output_path=str(directory/'result.mp4'),
                               camera_mode='locked',quality='high',keep_frames=True,ffmpeg_path=shutil.which('ffmpeg'))
                    path = directory/'job.json';path.write_text(json.dumps(job,indent=2)+'\n')
                    command = [str(binary)] if label == 'package' else [godot,'--path',str(projects[label])]
                    command += ['--resolution','640x360','--audio-driver','Dummy','--rendering-method',renderer,
                                '--fixed-fps','4','--disable-vsync','--','--wavez-render-job='+str(path)]
                    with (directory/'native.log').open('w') as stream:
                        result = subprocess.run(command,stdout=stream,stderr=subprocess.STDOUT,timeout=150,
                                                env=dict(os.environ,XDG_DATA_HOME=str(directory/'profile'),XDG_CONFIG_HOME=str(directory/'profile')))
                    log = (directory/'native.log').read_text()
                    progress = json.loads((directory/'progress.json').read_text())
                    assert result.returncode == 0 and 'ERROR:' not in log and 'WARNING:' not in log and progress['stage'] == 'complete', directory
                    frames = sorted((directory/'frames').glob('*.png'));assert len(frames) == 3
                    timing = [json.loads(row) for row in (directory/'timing.jsonl').read_text().splitlines()]
                    assert len(timing) == 3 and all(abs(row['capture_time']-n/4) < 1e-12 for n,row in enumerate(timing))
                    metadata = json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_entries',
                        'stream=width,height,nb_frames,avg_frame_rate','-of','json',str(directory/'result.mp4')],text=True))['streams'][0]
                    assert (metadata['width'],metadata['height'],metadata['nb_frames'],metadata['avg_frame_rate']) == (640,360,'3','4/1')
                    hashes = [hashlib.sha256(pixels(frame).tobytes()).hexdigest() for frame in frames]
                    assert len(set(hashes)) > 1, 'Moving source samples must reach the video'
                    results.append(dict(name=name,pixel_hashes=hashes,ffprobe=metadata,
                                        progress=progress,metrics=json.loads((directory/'metrics.json').read_text())))
        for renderer in ['forward_plus','gl_compatibility']:
            for preset in ['Cinematic','Scientific']:
                compared = [r['pixel_hashes'] for r in results if r['name'].endswith(renderer+'-'+preset)]
                assert len(compared) == 3 and compared[0] == compared[1] == compared[2], (renderer,preset)
    assert digest == hashlib.sha256(capture.read_bytes()).hexdigest()
    report = dict(runs=results,source_sha256_unchanged=digest,strict_verified_records=records,
                  all_accepted_candidate_package_pixels_identical=True,
                  worker_sha256=hashlib.sha256((ROOT/'viewer/video/render_worker.gd').read_bytes()).hexdigest(),
                  limitations=['640x360; 3 frames per job; v1 jobs; no long/4K or selection-aware v2 video matrix'])
    (output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Global Bloom exports: 12 native MP4 jobs PASS; accepted/candidate/package pixels identical')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'])
    parser.add_argument('--project-root', type=Path, default=ROOT)
    parser.add_argument('--baseline', action='store_true')
    parser.add_argument('--package', action='store_true')
    parser.add_argument('--compare-with', type=Path)
    parser.add_argument('--exports', action='store_true')
    parser.add_argument('--fixtures-dir', type=Path)
    args = parser.parse_args()
    output = args.output_dir.resolve();output.mkdir(parents=True, exist_ok=False)
    source = args.project_root.resolve()
    if args.exports:
        if not args.fixtures_dir or source == ROOT:
            parser.error('--exports requires --fixtures-dir and an accepted --project-root')
        export_comparison(args.godot,source,args.fixtures_dir.resolve(),output)
        return
    if not args.renderer:
        parser.error('--renderer is required for interaction validation')
    fixtures(output)
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in output.glob('*.wvz')}
    # Accepted-main comparisons use this same harness in an external archive only.
    script = source / 'viewer/scene/test_global_bloom.gd'
    if source != ROOT:
        shutil.copy2(ROOT / 'viewer/scene/test_global_bloom.gd', script)
    executable = package(args.godot, source, output) if args.package else args.godot
    command = [executable]
    if not args.package:
        command += ['--path', str(source / 'viewer'), '--script', 'res://scene/test_global_bloom.gd']
    command += ['--rendering-method', args.renderer, '--resolution', '1440x900', '--audio-driver', 'Dummy',
                '--disable-vsync', '--', str(output)] + (['baseline'] if args.baseline else [])
    env = dict(os.environ, XDG_DATA_HOME=str(output/'profile'), XDG_CONFIG_HOME=str(output/'profile'))
    result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=210)
    log = result.stdout + result.stderr;(output/'native.log').write_text(log)
    if result.returncode or 'ERROR:' in log or 'WARNING:' in log:
        raise RuntimeError(f'Global Bloom test failed: {output}/native.log')
    report = json.loads((output/'report.json').read_text())
    assert not report['failures']
    assert hashes == {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in output.glob('*.wvz')}
    comparisons = []
    for case in report['render_cases']:
        name, preset = case['scene'], case['preset']
        delta = np.abs(pixels(output/f'{name}-{preset}-0.0.png') - pixels(output/f'{name}-{preset}-2.0.png'))
        changed = int(np.any(delta != 0, axis=2).sum())
        assert (changed > 0) == (preset == 'Cinematic'), (name, preset, changed)
        regions = {}
        for kind, (x0,y0,x1,y1) in case['regions'].items():
            region = delta[y0:y1,x0:x1]
            regions[kind] = dict(changed_pixels=int(np.any(region != 0, axis=2).sum()),
                                 mean_delta=float(region.mean()),max_delta=int(region.max()))
            assert (regions[kind]['changed_pixels'] > 0) == (preset == 'Cinematic'), (case,kind)
        comparisons.append(dict(scene=name,preset=preset,changed_pixels=changed,
                                mean_delta=float(delta.mean()),max_delta=int(delta.max()),regions=regions))
    report.update(source_hashes_unchanged=hashes, packaged=args.package, comparisons=comparisons,
                  godot=subprocess.check_output([args.godot, '--version'], text=True).strip())
    if args.compare_with:
        matched = []
        for path in sorted(output.glob('*.png')):
            if 'control' in path.name:
                continue
            reference = args.compare_with / path.name
            assert reference.is_file() and np.array_equal(pixels(path),pixels(reference)), path.name
            matched.append(path.name)
        report['accepted_pixels_identical'] = matched
        reference = json.loads((args.compare_with/'report.json').read_text())
        assert report['renderer'] == reference['renderer']
        for measured, prior in zip(report['timings'],reference['timings']):
            for key in ['scene','texture_bytes','cache_bytes','viewports']:
                assert measured[key] == prior[key], (key, measured, prior)
        report['accepted_texture_cache_viewports_identical'] = True
        report['buffer_allocation_comparison'] = [dict(scene=now['scene'],accepted=before['buffer_bytes'],
                                                      candidate=now['buffer_bytes'])
                                                 for now,before in zip(report['timings'],reference['timings'])]
    (output/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'Global Bloom: {report["checks"]} checks PASS ({args.renderer}, baseline={args.baseline}, package={args.package})')


if __name__ == '__main__':
    main()

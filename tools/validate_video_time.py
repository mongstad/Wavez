"""Focused production export-time presentation and baseline output comparison.

Tests source and a disposable Linux package; external Godot/FFmpeg remain unvendored.
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
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture
from tools.package_linux import stage, build


def package(godot, out):
    with tempfile.TemporaryDirectory(prefix='wavez-time-review-') as temporary:
        project = Path(temporary) / 'viewer'; stage(project)
        script = (project / 'video/test_time_presentation.gd').read_text()
        script = script.replace('extends SceneTree', 'extends Node\nvar root: Window:\n\tget: return get_tree().root\nvar process_frame: Signal:\n\tget: return get_tree().process_frame')
        script = script.replace('func _initialize()', 'func _ready()').replace('create_timer(', 'get_tree().create_timer(').replace('quit(', 'get_tree().quit(')
        (project / 'time_review.gd').write_text(script)
        (project / 'review_entry.gd').write_text('''extends Node
func _ready():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--wavez-render-job="):
            add_child(load("res://Main.tscn").instantiate());return
    add_child(load("res://time_review.gd").new())
''')
        (project / 'Review.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://review_entry.gd" id="1"]\n[node name="Review" type="Node"]\nscript = ExtResource("1")\n')
        config = project / 'project.godot';config.write_text(config.read_text().replace('res://Main.tscn', 'res://Review.tscn'))
        binary = out / 'WAVEZ.x86_64'; build(godot, project, binary, out / 'build-logs')
    return str(binary)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--baseline', type=Path, required=True, help='Accepted repository archive')
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--package', action='store_true')
    p.add_argument('--renderer', default='forward_plus', choices=['forward_plus','gl_compatibility'])
    a = p.parse_args(); out = a.output.resolve();out.mkdir(parents=True, exist_ok=False)
    inputs = out / 'inputs';inputs.mkdir()
    sources = {}
    for name, times in [('scene',[0.,210.]),('hours',[-1.125,3601.125]),('precise',[1.00000001,211.1234567890123]),('short',[-5.125,-4.375]),('still',[-2.5]),('tail',[0.,92.33])]:
        source = inputs / (name+'.wvz')
        with SceneCapture(source,objects=[dict(id='p',kind='particles',units='m',identity='persistent_i8')]) as writer:
            for i,t in enumerate(times):writer.add_particles('p',t,np.array([[-.5+i,0,0],[0,1,0]],'f8'),ids=[1,2],visual_size=np.array([.5,.5],'f4'))
        sources[name]=str(source)
    hashes={path:hashlib.sha256(Path(path).read_bytes()).hexdigest() for path in sources.values()}
    env=dict(os.environ,XDG_DATA_HOME=str(out/'profile'),XDG_CONFIG_HOME=str(out/'profile'))
    reports={};command_suffix=['--rendering-method',a.renderer,'--audio-driver','Dummy','--resolution','1440x900']
    executable = package(a.godot,out) if a.package else a.godot
    for name, project in [('before',a.baseline/'viewer'),('after',ROOT/'viewer')]:
        folder=out/name;folder.mkdir();(folder/'config.json').write_text(json.dumps(sources))
        command=([executable] if a.package and name=='after' else [a.godot,'--path',str(project),'--script',str(ROOT/'viewer/video/test_time_presentation.gd')])
        command+=command_suffix+['--',str(folder)]+(['baseline'] if name=='before' else [])
        result=subprocess.run(command,cwd=folder,env=env,capture_output=True,text=True,timeout=130)
        log=result.stdout+result.stderr;(folder/'run.txt').write_text(log.rstrip()+'\n')
        if result.returncode or 'ERROR:' in log or 'WARNING:' in log:raise RuntimeError(f'{name}: {folder}/run.txt')
        reports[name]=json.loads((folder/'report.json').read_text());assert not reports[name]['failures']
        print(name,reports[name]['checks'],'clean UI checks',flush=True)
    assert reports['before']['matrix']==reports['after']['matrix'], 'Dialog job settings/counts/sample boundaries changed'
    # Render three short jobs through the unchanged production Main/worker boundary.
    exports=[]
    for case in ['fractional','full-fast','final-fraction']:
        outputs={}
        for name, project in [('before',a.baseline/'viewer'),('after',ROOT/'viewer')]:
            folder=out/(case+'-'+name);folder.mkdir()
            job=json.loads((out/name/('tail-settings.json' if case=='final-fraction' else 'export-settings.json')).read_text())
            if case=='full-fast':job.update(start_time=0.,end_time=210.,fps=4,playback_rate=420.)
            job['output_path']=str(folder/'output.mp4')
            (folder/'job.json').write_text(json.dumps(job))
            command=([executable] if a.package and name=='after' else [a.godot,'--path',str(project)])+command_suffix+['--','--wavez-render-job='+str(folder/'job.json')]
            result=subprocess.run(command,cwd=folder,env=env,capture_output=True,text=True,timeout=120)
            log=result.stdout+result.stderr;(folder/'run.txt').write_text(log.rstrip()+'\n')
            assert result.returncode==0 and 'ERROR:' not in log and 'WARNING:' not in log, folder/'run.txt'
            progress=json.loads((folder/'progress.json').read_text());assert progress['stage']=='complete',progress
            timing=[json.loads(row) for row in (folder/'timing.jsonl').read_text().splitlines()]
            expected=4 if case=='fractional' else 2
            assert len(timing)==expected
            for i,row in enumerate(timing):
                assert row['n']==i and row['video_time']==i/job['fps']
                assert row['capture_time']==job['start_time']+i/job['fps']*job['playback_rate']
                assert row['capture_time']<job['end_time']
            if case=='final-fraction':
                assert job['end_time']==92.33 and timing[-1]['capture_time']>92, 'Final partial second omitted'
            probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_entries','stream=width,height,nb_frames,avg_frame_rate','-of','json',job['output_path']]))['streams'][0]
            assert (probe['width'],probe['height'],int(probe['nb_frames']),probe['avg_frame_rate'])==(320,180,expected,'4/1')
            images=[Image.open(f).tobytes() for f in sorted((folder/'frames').glob('*.png'))];assert len(images)==expected
            decoded=subprocess.check_output(['ffmpeg','-v','error','-i',job['output_path'],'-f','rawvideo','-pix_fmt','rgb24','-'])
            outputs[name]=(timing,images,decoded,probe)
        assert outputs['before']==outputs['after'],case+': timestamps, PNG or decoded MP4 changed'
        exports.append(dict(case=case,frames=len(outputs['after'][0]),timestamps=outputs['after'][0],png_pixels_identical=True,decoded_mp4_pixels_identical=True,probe=outputs['after'][3]))
        print(case,'exact timing/PNG/decoded MP4 comparison passed',flush=True)
    assert hashes=={path:hashlib.sha256(Path(path).read_bytes()).hexdigest() for path in sources.values()}
    summary=dict(renderer=a.renderer,packaged=a.package,ui_checks={name:report['checks'] for name,report in reports.items()},settings_matrix_pairs=len(reports['after']['matrix']),exports=exports,source_hashes_unchanged=hashes)
    (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print('Video time presentation PASS',a.renderer,'package=',a.package)


if __name__=='__main__':main()

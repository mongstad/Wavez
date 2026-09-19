"""Native probe visibility, scientific-state, screenshot and video regression."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import numpy as np
from PIL import Image
from simscope_export import SceneCapture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], default='forward_plus')
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    ffmpeg = shutil.which('ffmpeg')
    assert ffmpeg and shutil.which('ffprobe'), 'FFmpeg and ffprobe required'
    source = out/'volume.ssc'
    with SceneCapture(source, objects=[dict(id='field', kind='volume', units='u', identity='grid')], compression='none') as writer:
        z, y, x = np.indices((5, 5, 5))
        for t in [0., 1.]:
            writer.add_volume('field', t, dict(value=(x+2*y+3*z+10*t).astype('f8')), origin=[-2,-2,-2], spacing=[1,1,1])
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    env = os.environ.copy()
    env.update(XDG_DATA_HOME=str(out/'userdata'), XDG_CONFIG_HOME=str(out/'config'))
    def run(name, command):
        result = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True, timeout=150)
        log = result.stdout + result.stderr
        (out/(name+'.log')).write_text(log)
        if result.returncode or any(marker in log for marker in ['ERROR:', 'WARNING:']):
            raise RuntimeError(log[-6000:])
    run('import', [args.godot, '--headless', '--path', 'viewer', '--editor', '--import'])
    command = [args.godot, '--path', 'viewer', '--rendering-method', args.renderer, '--resolution', '640x480', '--audio-driver', 'Dummy']
    run('probe', command+['--script', 'res://layers/test_probe_marker.gd', '--', '--probe-output='+str(out)])
    shown = json.loads((out/'shown-state.json').read_text())
    hidden = json.loads((out/'hidden-state.json').read_text())
    assert shown == hidden, 'Session marker leaked into recipe/video render state'
    def crop(path):
        return np.asarray(Image.open(path).convert('RGB'))[100:380,160:480]
    manifests = []
    for name, state in [('shown', shown), ('hidden', hidden)]:
        directory = out/('video-'+name)
        directory.mkdir()
        job = dict(version=1, capture_path=str(source), state=state, start_time=0., end_time=1., fps=4,
                   playback_rate=1., width=640, height=480, output_path=str(directory/'result.mp4'),
                   camera_mode='locked', quality='high', keep_frames=True, ffmpeg_path=ffmpeg)
        path = directory/'job.json'
        path.write_text(json.dumps(job))
        run('video-'+name, command+['--fixed-fps', '4', '--disable-vsync', '--', '--simscope-render-job='+str(path)])
        assert json.loads((directory/'progress.json').read_text())['stage'] == 'complete'
        frames = sorted((directory/'frames').glob('*.png'))
        assert len(frames) == 4
        assert np.array_equal(crop(frames[0]), crop(out/'baseline.png')), 'Video includes session probe or differs from clean reference'
        manifests.append([json.loads(line) for line in (directory/'timing.jsonl').read_text().splitlines()])
        info = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=width,height,nb_frames,r_frame_rate,duration', '-of', 'json', str(directory/'result.mp4')]))['streams'][0]
        assert (info['width'], info['height'], int(info['nb_frames']), info['r_frame_rate'], float(info['duration'])) == (640,480,4,'4/1',1.)
    assert manifests[0] == manifests[1]
    for a, b in zip(sorted((out/'video-shown/frames').glob('*.png')), sorted((out/'video-hidden/frames').glob('*.png'))):
        assert a.read_bytes() == b.read_bytes(), 'Marker visibility changed exported frame'
    assert hashlib.sha256(source.read_bytes()).hexdigest() == digest, 'Capture bytes changed'
    report = json.loads((out/'probe-report.json').read_text())
    report.update(video='Two four-frame MP4s PASS; identical frames/timing; marker-free baseline match', source_sha256_unchanged=digest)
    (out/'probe-report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()

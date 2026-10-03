"""Real GPU export progress with worker windows minimized/unfocused/covered."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--fixture-dir', type=Path, required=True, help='Completed validate_video.py output containing fixture.wvz and state.json')
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], default='forward_plus')
    parser.add_argument('--baseline-project', type=Path, help='Optional unmodified main viewer checkout for output comparison')
    args = parser.parse_args()
    out = args.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    fixture = args.fixture_dir.resolve()
    source = fixture/'fixture.wvz'
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    state = json.loads((fixture/'state.json').read_text());state['overlay_visible'] = False
    env = os.environ.copy();env.update(XDG_DATA_HOME=str(out/'userdata'), XDG_CONFIG_HOME=str(out/'config'))
    ffmpeg = shutil.which('ffmpeg');assert ffmpeg
    def run(command, log, expected=0):
        result = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True, timeout=150)
        text = result.stdout+result.stderr;log.write_text(text)
        assert result.returncode == expected and 'ERROR:' not in text and 'WARNING:' not in text, text[-4000:]
    run([args.godot, '--headless','--path',str(ROOT/'viewer'),'--editor','--import'],out/'import.log')
    scenarios = ['visible','minimized','unfocused','obscured','background','cancel']
    if args.baseline_project:scenarios.insert(0,'baseline')
    results = {};reference = None
    for scenario in scenarios:
        directory = out/scenario;directory.mkdir()
        job = dict(version=1,capture_path=str(source),state=state,start_time=0.,end_time=1.,fps=30,playback_rate=1.,width=640,height=360,
                   output_path=str(directory/'result.mp4'),camera_mode='orbit',orbit_speed=.2,quality='high',keep_frames=True,
                   ffmpeg_path=ffmpeg,test_frame_delay_ms=40)
        path = directory/'job.json';path.write_text(json.dumps(job))
        project = args.baseline_project.resolve() if scenario == 'baseline' else ROOT/'viewer'
        command = [args.godot,'--path',str(project),'--resolution','640x360','--position','0,0','--rendering-method',args.renderer,'--audio-driver','Dummy','--fixed-fps','30','--disable-vsync']
        if scenario == 'baseline':
            run([args.godot,'--headless','--path',str(project),'--editor','--import'],directory/'import.log')
            command += ['--','--wavez-render-job='+str(path)]
        else:command += ['--script','res://video/test_background_worker.gd','--','--job='+str(path),'--scenario='+scenario]
        run(command,directory/'worker.log',2 if scenario == 'cancel' else 0)
        progress = json.loads((directory/'progress.json').read_text())
        observations = json.loads((directory/'window-observations.json').read_text()) if scenario != 'baseline' else {}
        frames = sorted((directory/'frames').glob('*.png'))
        timing = [json.loads(line) for line in (directory/'timing.jsonl').read_text().splitlines()]
        if scenario == 'cancel':
            assert progress['stage'] == 'cancelled' and 10 <= len(frames) < 30 and not (directory/'result.mp4').exists()
        else:
            assert progress['stage'] == 'complete' and len(frames) == 30
            hashes = [hashlib.sha256(p.read_bytes()).hexdigest() for p in frames]
            if reference is None:reference = (hashes,timing)
            assert reference == (hashes,timing), 'Rendered frames or timing differ: '+scenario
            info = json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_entries','stream=width,height,nb_frames,r_frame_rate,duration','-of','json',str(directory/'result.mp4')]))['streams'][0]
            assert (info['width'],info['height'],int(info['nb_frames']),info['r_frame_rate'],float(info['duration'])) == (640,360,30,'30/1',1.)
        if scenario in ['minimized','background','cancel']:
            assert observations['final_mode'] == 1, observations
            assert all(o['mode'] == 1 for o in observations['observations'] if o['frame'] > 10), observations
        if scenario in ['unfocused','obscured']:
            assert any(o['frame'] >= 20 and not o['focused'] and o['cover_visible'] for o in observations['observations']), observations
        if scenario != 'cancel' and scenario != 'baseline':
            assert any(o['frame'] >= 25 for o in observations['observations']), observations
        results[scenario] = dict(stage=progress['stage'],frames=len(frames),window=observations)
        print(f'{scenario}: {progress["stage"]}, {len(frames)} frames PASS',flush=True)
    assert hashlib.sha256(source.read_bytes()).hexdigest() == digest
    report = dict(renderer=args.renderer,results=results,source_sha256_unchanged=digest,baseline_compared=bool(args.baseline_project))
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')


if __name__ == '__main__':main()

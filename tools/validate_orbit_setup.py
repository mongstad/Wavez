"""Custom orbit interaction, camera state and screenshot isolation on native GPU backends."""
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
from tools.validate_render_pacing import fixtures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], required=True)
    args = parser.parse_args()
    out = args.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    fixtures(out)
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.ssc')}
    env = os.environ.copy()
    env.update(XDG_DATA_HOME=str(out/'userdata'), XDG_CONFIG_HOME=str(out/'config'))
    command = [args.godot, '--path', str(ROOT/'viewer'), '--rendering-method', args.renderer,
               '--resolution', '1440x900', '--audio-driver', 'Dummy',
               '--script', 'res://scene/test_orbit_setup.gd', '--', str(out)]
    result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=170)
    log = result.stdout+result.stderr; (out/'native.log').write_text(log)
    assert result.returncode == 0 and 'ERROR:' not in log and 'WARNING:' not in log, log[-8000:]
    report = json.loads((out/'report.json').read_text())
    assert not report['failures'], report
    # Exercise the real offline worker with both camera modes and UI inclusion.
    state = json.loads((out/'custom-state.json').read_text())
    exports = []
    for mode in ['locked', 'orbit']:
        for overlay in [False, True]:
            folder = out / f'video-{mode}-{overlay}'
            folder.mkdir()
            state['overlay_visible'] = overlay
            job = dict(version=1, capture_path=str(out/'mixed.ssc'), state=state,
                       start_time=0., end_time=.5, fps=4, playback_rate=1.,
                       width=960, height=540, output_path=str(folder/'result.mp4'),
                       camera_mode=mode, orbit_speed=.08, quality='high',
                       keep_frames=True, inspection_sidecars=True, ffmpeg_path=shutil.which('ffmpeg'))
            path = folder/'job.json'; path.write_text(json.dumps(job))
            result = subprocess.run([args.godot, '--path', str(ROOT/'viewer'),
                                     '--rendering-method', args.renderer, '--audio-driver', 'Dummy',
                                     '--script', 'res://scene/test_orbit_video.gd', '--', str(path)],
                                    env=env, capture_output=True, text=True, timeout=90)
            log = result.stdout+result.stderr; (folder/'native.log').write_text(log)
            assert result.returncode == 0 and 'ERROR:' not in log and 'WARNING:' not in log, log[-5000:]
            progress = json.loads((folder/'progress.json').read_text())
            assert progress['stage'] == 'complete', progress
            assert (folder/'result.mp4').stat().st_size > 0
            exports.append(dict(camera=mode, overlay=overlay, complete=True))
    report['custom_camera_exports'] = exports
    assert hashes == {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.ssc')}
    report['source_hashes_unchanged'] = hashes
    (out/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'Orbit setup: {report["checks"]} PASS and 4 custom-camera exports ({args.renderer}); complete fixture hashes unchanged')


if __name__ == '__main__':
    main()

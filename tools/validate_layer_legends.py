"""Focused independent legend, presentation-state and layout regression."""
import argparse
import hashlib
import json
import copy
import shutil
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.validate_simulation_panel import fixture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], default='forward_plus')
    parser.add_argument('--export', action='store_true', help='Also render one multi-layer MP4 frame with overlays on and off.')
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    fixture(out / 'mixed.ssc', ['particles', 'volume', 'mesh'])
    source = out / 'mixed.ssc'
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    result = subprocess.run([args.godot, '--path', str(ROOT / 'viewer'), '--rendering-method', args.renderer,
                             '--audio-driver', 'Dummy', '--resolution', '1440x900', '--script',
                             'ui/shell/test_layer_legends.gd', '--', str(out)], capture_output=True, text=True, timeout=90)
    (out / 'native.log').write_text(result.stdout + result.stderr)
    assert result.returncode == 0 and 'ERROR:' not in result.stdout + result.stderr, out / 'native.log'
    report = json.loads((out / 'report.json').read_text())
    assert not report['failures'], report
    assert hashlib.sha256(source.read_bytes()).hexdigest() == digest
    if args.export:
        assert shutil.which('ffmpeg'), 'FFmpeg required'
        exports = {}
        for enabled in [True, False]:
            directory = out / ('export-on' if enabled else 'export-off')
            directory.mkdir()
            state = copy.deepcopy(json.loads((out / 'state.json').read_text()))
            state['overlay_visible'] = enabled
            state['scene']['legend_visibility'] = {key: True for key in state['scene']['layers']}
            job = dict(version=1, capture_path=str(source), state=state, start_time=0., end_time=.5,
                       fps=2, playback_rate=1., width=1440, height=900, camera_mode='locked',
                       quality='high', keep_frames=True, ffmpeg_path=shutil.which('ffmpeg'),
                       output_path=str(directory / 'result.mp4'))
            path = directory / 'job.json'; path.write_text(json.dumps(job))
            render = subprocess.run([args.godot, '--path', str(ROOT / 'viewer'), '--rendering-method', args.renderer,
                                     '--audio-driver', 'Dummy', '--', '--wavez-render-job=' + str(path)],
                                    capture_output=True, text=True, timeout=90)
            (directory / 'native.log').write_text(render.stdout + render.stderr)
            assert render.returncode == 0 and 'ERROR:' not in render.stdout + render.stderr
            assert json.loads((directory / 'progress.json').read_text())['stage'] == 'complete'
            frames = list((directory / 'frames').glob('*.png')); assert len(frames) == 1
            exports[str(enabled)] = hashlib.sha256(frames[0].read_bytes()).hexdigest()
        assert exports['True'] != exports['False'], 'Overlay inclusion must change pixels'
        report['one_frame_exports'] = exports
        assert hashlib.sha256(source.read_bytes()).hexdigest() == digest
    report['source_sha256_unchanged'] = digest
    (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'Layer legends: {report["checks"]} PASS ({args.renderer}); source unchanged')


if __name__ == '__main__':
    main()

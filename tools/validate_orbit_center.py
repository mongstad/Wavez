"""Compare a temporary orbit editor with accepted-main camera/playback/output behavior."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import numpy as np
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture
from validate_render_pacing import fixtures


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--reference-root', required=True, type=Path,
                        help='Fresh source snapshot of accepted main (no checkout/branch changes).')
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--renderer', required=True, choices=['forward_plus', 'gl_compatibility'])
    args = parser.parse_args()
    out = args.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    # Copy only these test drivers into the reference snapshot; production code stays untouched.
    for name in ['test_orbit_center.gd', 'test_orbit_center_video.gd']:
        shutil.copy2(ROOT/'viewer/ui/shell'/name, args.reference_root/'viewer/ui/shell'/name)
    reports = {}; runs = []
    for name, project in [('reference', args.reference_root), ('candidate', ROOT)]:
        folder = out/name; folder.mkdir(); fixtures(folder)
        for label, scale in [('small', .001), ('large', 10000.)]:
            with SceneCapture(folder/(label+'.ssc'), objects=[dict(id='mesh', kind='mesh', identity='stable_topology', units='m')], compression='none') as writer:
                for time in (0., .5, 1., 1.5, 2.):
                    points = (np.array([[-2, 0, 0], [2, 0, 0], [0, 3, 1]], dtype='f8')+[0, 0, time])*scale
                    writer.add_mesh('mesh', time, points, np.array([[0, 1, 2]]), vertex_channels=dict(vertex_id=np.array([7,8,9], dtype='i8')))
        hashes = {p.name: digest(p) for p in folder.glob('*.ssc')}
        command = [args.godot, '--path', str(project/'viewer'), '--rendering-method', args.renderer,
                   '--audio-driver', 'Dummy', '--resolution', '1440x900', '--log-file', str(folder/'live.log')]
        result = subprocess.run(command+['--script', 'ui/shell/test_orbit_center.gd', '--', str(folder)]+(['--reference'] if name == 'reference' else []), capture_output=True, text=True, timeout=210)
        log = result.stdout+result.stderr; (folder/'native.log').write_text(log)
        assert result.returncode == 0 and 'ERROR:' not in log, log[-8000:]
        reports[name] = json.loads((folder/'orbit-report.json').read_text())
        assert not reports[name]['failures'], reports[name]['failures']
        for mode in ['locked', 'orbit']:
            job_folder = folder/mode; job_folder.mkdir()
            job = json.loads((folder/(mode+'-job.json')).read_text())
            job['output_path'] = str(job_folder/'movie.mp4')
            job_path = job_folder/'job.json'; job_path.write_text(json.dumps(job))
            result = subprocess.run(command+['--script', 'ui/shell/test_orbit_center_video.gd', '--', str(job_path)], capture_output=True, text=True, timeout=120)
            log = result.stdout+result.stderr; (job_folder/'native.log').write_text(log)
            assert result.returncode == 0 and 'ERROR:' not in log, log[-8000:]
            progress = json.loads((job_folder/'progress.json').read_text())
            assert progress['stage'] == 'complete' and progress['current_frame'] == progress['total_frames']
            frames = sorted((job_folder/'frames').glob('*.png'))
            assert len(frames) == 2 and (job_folder/'movie.mp4').stat().st_size > 0
            runs.append(dict(implementation=name, mode=mode, frames=len(frames), exit_code=result.returncode))
        assert hashes == {p.name: digest(p) for p in folder.glob('*.ssc')}
        reports[name]['source_hashes_unchanged'] = hashes
    reference = reports['reference']; candidate = reports['candidate']
    assert reference['camera_trace'] == candidate['camera_trace'], 'Camera behavior differs from main'
    assert reference['playback_trace'] == candidate['playback_trace'], 'Playback/preparation behavior differs from main'
    output_frames = {}
    for mode in ['locked', 'orbit']:
        expected = sorted((out/'reference'/mode/'frames').glob('*.png'))
        actual = sorted((out/'candidate'/mode/'frames').glob('*.png'))
        for a, b in zip(expected, actual, strict=True):
            assert np.array_equal(np.asarray(Image.open(a)), np.asarray(Image.open(b))), f'Export pixels differ: {mode}/{a.name}'
        # Timing sidecars carry the same scientific sample clock.
        assert (out/'reference'/mode/'timing.jsonl').read_text() == (out/'candidate'/mode/'timing.jsonl').read_text()
        output_frames[mode] = len(actual)
    summary = dict(renderer=args.renderer, reference_checks=reference['checks'], candidate_checks=candidate['checks'],
                   camera_samples_equal=len(candidate['camera_trace']), playback_samples_equal=len(candidate['playback_trace']),
                   export_pixel_equal_frames=output_frames, source_hashes_unchanged=candidate['source_hashes_unchanged'],
                   stationary_editor_draws=candidate['idle_draws'], runs=runs, failures=[])
    (out/'comparison.json').write_text(json.dumps(summary, indent=2)+'\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()

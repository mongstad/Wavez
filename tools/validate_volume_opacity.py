"""Focused independent opacity transfer regression on native GPU backends."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture, SceneReader


def run_native(command, out, env):
    result = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True, timeout=240)
    log = result.stdout+result.stderr
    (out/'native.log').write_text(log)
    assert result.returncode == 0 and 'ERROR:' not in log and 'WARNING:' not in log, log[-6000:]


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def real_review(args, out, env):
    """External source is read only; compare explicit mappings on its last sample."""
    source = args.real_capture.resolve()
    before = digest(source)
    out.mkdir()
    with SceneReader(source, cache_bytes=0) as reader:
        fields = [key for key, obj in reader.objects.items() if obj['kind'] == 'volume']
        assert len(fields) == 1, 'Select a capture with one volume for this review'
        field = fields[0]
        row = reader.samples[field][-1]
        arrays = reader.read_sample(field, len(reader.samples[field])-1)
        geometry = row['descriptor']['geometry']
        grid = np.array(geometry['shape'])[::-1]//2
        point = np.array(geometry['origin'])+grid*np.array(geometry['spacing'])
        tx = np.array(reader.objects[field]['data_to_world']).reshape(3, 4)
        world = (tx[:, :3]@point+tx[:, 3]).tolist()
        cases = []
        for channel in ['density', 'psi_real', 'psi_imag']:
            values = arrays[channel]
            bound = float(np.max(np.abs(values)))
            oracle = dict(sha256=hashlib.sha256(values.tobytes()).hexdigest(),
                          probe_world=world, probe_value=float(values[tuple(grid[::-1])]))
            choices = [('linear', 0., 1.)] if channel == 'density' else [
                ('magnitude', .01, bound), ('linear', -bound, bound)]
            for mode, lower, upper in choices:
                name = channel+'-'+('independent' if mode == 'magnitude' else 'legacy')
                changes = dict(lower=0. if channel == 'density' else -bound,
                               upper=1. if channel == 'density' else bound,
                               colormap='viridis' if channel == 'density' else 'coolwarm',
                               opacity_mapping=dict(mode=mode, lower=lower, upper=upper))
                cases.append(dict(name=name, time=row['time'], channel=channel, preset='Scientific',
                                  particles=False, changes=changes, oracle=oracle))
    (out/'job.json').write_text(json.dumps(dict(capture=str(source), field=field, cases=cases, output=str(out))))
    run_native([args.godot, '--path', str(ROOT/'viewer'), '--rendering-method', args.renderer,
                '--resolution', '960x640', '--audio-driver', 'Dummy', '--script',
                'res://layers/review_volume_defaults.gd', '--', '--review-job='+str(out/'job.json')], out, env)
    assert digest(source) == before, 'External capture changed'
    report = json.loads((out/'render-report.json').read_text())
    assert not report['failures']
    report.update(source_file=source.name, source_sha256_unchanged=before, source_bytes=source.stat().st_size)
    (out/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'Real capture: {report["checks"]} checks PASS; {len(cases)} views; source unchanged')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], required=True)
    parser.add_argument('--real-capture', type=Path, help='Optional external density/psi_real/psi_imag capture; read only')
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    source = out / 'opacity.ssc'
    z, y, x = np.meshgrid(*([np.linspace(-2, 2, 33)] * 3), indexing='ij')
    positive = np.exp(-((x-1)**2+y*y+z*z)*4)
    negative = np.exp(-((x+1)**2+y*y+z*z)*4)
    fields = {name: np.full(x.shape, value, dtype='<f8') for name, value in
              [('zero', 0.), ('nearzero', .001), ('positive', .5), ('negative', -.5), ('large', 2.)]}
    fields.update(density=positive+negative, psi_real=positive-negative, psi_imag=negative-positive)
    with SceneCapture(source, objects=[dict(id='field', kind='volume', units='source units')]) as writer:
        for time in [0., 2.]:
            writer.add_volume('field', time, fields, origin=[-2]*3, spacing=[.125]*3, centering='cell')
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    job = dict(capture=str(source), output=str(out), hashes={
        key: hashlib.sha256(value.tobytes()).hexdigest() for key, value in fields.items()})
    (out/'job.json').write_text(json.dumps(job))
    env = os.environ.copy()
    env.update(XDG_DATA_HOME=str(out/'userdata'), XDG_CONFIG_HOME=str(out/'config'))
    command = [args.godot, '--path', str(ROOT/'viewer'), '--rendering-method', args.renderer,
               '--resolution', '960x640', '--audio-driver', 'Dummy', '--script',
               'res://layers/test_volume_opacity.gd', '--', '--opacity-job='+str(out/'job.json')]
    run_native(command, out, env)
    report = json.loads((out/'report.json').read_text())
    assert not report['failures'], report['failures']
    assert hashlib.sha256(source.read_bytes()).hexdigest() == digest, 'Capture bytes changed'
    report['source_sha256_unchanged'] = digest
    # One actual offline MP4 frame must reproduce the configured signed view.
    ffmpeg = shutil.which('ffmpeg')
    assert ffmpeg, 'FFmpeg required for focused export check'
    export = out/'export'
    export.mkdir()
    state = json.loads((out/'export-state.json').read_text())
    job = dict(version=1, capture_path=str(source), state=state, start_time=2., end_time=2.,
               fps=4, playback_rate=1., width=960, height=640, output_path=str(export/'signed.mp4'),
               camera_mode='locked', orbit_speed=0., quality='high', keep_frames=True,
               inspection_sidecars=True, ffmpeg_path=ffmpeg)
    (export/'job.json').write_text(json.dumps(job))
    run_native([args.godot, '--path', str(ROOT/'viewer'), '--rendering-method', args.renderer,
                '--audio-driver', 'Dummy', '--fixed-fps', '4', '--disable-vsync', '--',
                '--wavez-render-job='+str(export/'job.json')], export, env)
    assert json.loads((export/'progress.json').read_text())['stage'] == 'complete'
    assert np.array_equal(np.asarray(Image.open(out/'psi_real.png')),
                          np.asarray(Image.open(export/'frames/frame00000000.png'))), 'Export pixels differ'
    sidecar = json.loads((export/'inspection-00000000.json').read_text())
    assert sidecar['visual']['scene']['layers']['field']['opacity_mapping'] == state['scene']['layers']['field']['opacity_mapping']
    assert hashlib.sha256(source.read_bytes()).hexdigest() == digest
    report['export'] = dict(completed=True, identical_pixels=True, mapping_in_sidecar=True, source_unchanged=True)
    (out/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'{args.renderer}: {report["checks"]} checks PASS; source unchanged')
    if args.real_capture:
        real_review(args, out/'real', env)


if __name__ == '__main__':
    main()

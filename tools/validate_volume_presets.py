"""Opt-in volume preset regression, independent NumPy oracles and native export."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from simscope_export import SceneCapture, SceneReader
from tools.validate_volume_opacity import digest, run_native


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--real-capture', type=Path)
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    source = args.real_capture.resolve() if args.real_capture else out / 'presets.ssc'
    if not args.real_capture:
        z, y, x = np.meshgrid(*([np.linspace(-2, 2, 33)] * 3), indexing='ij')
        positive = np.exp(-((x-0.8)**2+y*y+z*z)*4)
        negative = np.exp(-((x+0.8)**2+y*y+z*z)*4)
        with SceneCapture(source, objects=[dict(id='field', kind='volume', units='u')]) as writer:
            for time in [0., 2.]:
                fields = dict(density=(positive+negative)*(1+time),
                              psi_real=(positive-negative)*(1+time),
                              psi_imag=(negative-positive)*(1+time), zero=np.zeros(x.shape))
                writer.add_volume('field', time, fields, origin=[-2]*3, spacing=[.125]*3, centering='cell')
    before = digest(source)
    with SceneReader(source, cache_bytes=0) as reader:
        field = next(k for k, v in reader.objects.items() if v['kind'] == 'volume')
        row = reader.samples[field][-1]
        arrays = reader.read_sample(field, len(reader.samples[field])-1)
        geometry = row['descriptor']['geometry']
        grid = np.array(geometry['shape'])[::-1]//2
        point = np.array(geometry['origin']) + grid*np.array(geometry['spacing'])
        tx = np.array(reader.objects[field]['data_to_world']).reshape(3, 4)
        world = (tx[:, :3]@point + tx[:, 3]).tolist()
        oracles = {}
        for channel in ['density', 'psi_real', 'psi_imag']:
            values = arrays[channel]
            finite = values[np.isfinite(values)]
            oracles[channel] = dict(minimum=float(finite.min()), maximum=float(finite.max()),
                bound=float(np.abs(finite).max()), percentiles=np.quantile(finite, [.01, .99]).tolist(),
                custom_percentiles=np.quantile(finite, [.05, .95]).tolist(),
                sha256=hashlib.sha256(values.tobytes()).hexdigest(), probe_world=world,
                probe_value=float(values[tuple(grid[::-1])]))
        first_time = reader.samples[field][0]['time']
    job = dict(capture=str(source), field=field, time=row['time'], first_time=first_time,
               oracles=oracles, output=str(out), synthetic=not bool(args.real_capture))
    (out/'job.json').write_text(json.dumps(job))
    env = os.environ.copy()
    env.update(XDG_DATA_HOME=str(out/'userdata'), XDG_CONFIG_HOME=str(out/'config'))
    base = [args.godot, '--path', str(ROOT/'viewer'), '--rendering-method', args.renderer, '--audio-driver', 'Dummy']
    run_native(base + ['--resolution', '960x640', '--script', 'res://layers/test_volume_presets.gd',
                      '--', '--preset-job='+str(out/'job.json')], out, env)
    report = json.loads((out/'report.json').read_text())
    assert not report['failures']
    ffmpeg = shutil.which('ffmpeg')
    assert ffmpeg
    exports = []
    for name in ['density-dense_core', 'density-faint_structure', 'psi_real-signed_field']:
        export = out/('export-'+name)
        export.mkdir()
        state = json.loads((out/(name+'-state.json')).read_text())
        render = dict(version=1, capture_path=str(source), state=state, start_time=row['time'],
            end_time=row['time'], fps=4, playback_rate=1., width=960, height=640,
            output_path=str(export/'preset.mp4'), camera_mode='locked', orbit_speed=0.,
            quality='high', keep_frames=True, inspection_sidecars=True, ffmpeg_path=ffmpeg)
        (export/'job.json').write_text(json.dumps(render))
        run_native(base + ['--fixed-fps', '4', '--disable-vsync', '--',
                          '--simscope-render-job='+str(export/'job.json')], export, env)
        assert json.loads((export/'progress.json').read_text())['stage'] == 'complete'
        assert np.array_equal(np.asarray(Image.open(out/(name+'.png'))),
                              np.asarray(Image.open(export/'frames/frame00000000.png')))
        sidecar = json.loads((export/'inspection-00000000.json').read_text())
        assert sidecar['visual']['scene'] == state['scene']
        exports.append(dict(case=name, completed=True, identical_pixels=True, resolved_state_in_sidecar=True))
    assert digest(source) == before
    report.update(exports=exports, source_file=source.name, source_bytes=source.stat().st_size,
                  source_sha256_unchanged=before, oracles=oracles)
    (out/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'{args.renderer}: {report["checks"]} PASS; three preset exports verified; source unchanged')


if __name__ == '__main__':
    main()

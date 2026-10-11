"""Compare probe treatments over native sparse/dense particles and field colormaps."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--renderer', choices=['forward_plus'], default='forward_plus')
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    source = out / 'dense.wvz'
    rng = np.random.default_rng(32)
    positions = rng.uniform(-2, 2, (20000, 3))
    z, y, x = np.indices((25, 25, 25)) / 24 * 4 - 2
    wave = (.5 + .15 * np.sin(5*x) + .15 * np.cos(4*y) + .15 * np.sin(3*z)).astype('f8')
    objects = [dict(id='p', kind='particles', identity='persistent_i8', units='m'),
               dict(id='field', kind='volume', units='u')]
    with SceneCapture(source, objects=objects, compression='none') as writer:
        writer.add_particles('p', 0., positions, ids=np.arange(20000, dtype='i8'))
        writer.add_volume('field', 0., dict(constant=np.ones_like(wave), wave=wave),
                          origin=[-2,-2,-2], spacing=[1/6]*3, centering='node')
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    env = dict(os.environ, XDG_DATA_HOME=str(out/'profile/data'), XDG_CONFIG_HOME=str(out/'profile/config'))
    command = [args.godot, '--path', str(ROOT/'viewer'), '--rendering-method', args.renderer,
               '--audio-driver', 'Dummy', '--resolution', '960x640', '--script',
               'res://layers/test_probe_visibility.gd', '--', str(out)]
    result = subprocess.run(command, cwd=ROOT, env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=150)
    (out/'native.txt').write_text(result.stdout)
    if result.returncode or 'ERROR:' in result.stdout or 'WARNING:' in result.stdout:
        raise RuntimeError(f'Native visibility check failed: {out}/native.txt')
    report = json.loads((out/'visibility-report.json').read_text())
    assert not report['failures'], report['failures']

    def rgb(name):
        return np.asarray(Image.open(out/(name+'.png')).convert('RGB')).astype(np.int16)

    empty = rgb('empty-hidden')
    mask = np.max(np.abs(rgb('empty-orchid')-empty), axis=2) > 8
    ys, xs = np.where(mask)
    assert len(xs) > 100, 'Marker lacks a readable footprint'
    bounds = np.zeros(mask.shape, dtype=bool)
    bounds[max(0,ys.min()-2):ys.max()+3, max(0,xs.min()-2):xs.max()+3] = True
    metrics = []
    for case in report['cases']:
        name = case['name']
        baseline = rgb(name+'-hidden')
        assert np.array_equal(baseline, rgb(name+'-hidden-after')), name+' hiding did not restore pixels'
        treatments = {}
        for treatment in ['legacy', 'orchid', 'cyan', 'gold']:
            delta = np.max(np.abs(rgb(name+'-'+treatment)-baseline), axis=2)
            changed = delta > 8
            treatments[treatment] = dict(changed_pixels=int(changed.sum()),
                                        strong_contrast_pixels=int((delta > 40).sum()))
            assert not np.any(changed & ~bounds), name+' changed pixels away from probe'
            if treatment != 'legacy':
                assert changed.sum() > 100 and changed.sum() < mask.size*.005, name+' footprint unreadable/excessive'
                assert (delta > 40).sum() > 100, name+' marker has insufficient contrast'
        metrics.append(dict(case=name, treatments=treatments))
    assert metrics[0]['treatments']['orchid']['changed_pixels'] > 2*metrics[0]['treatments']['legacy']['changed_pixels'], 'Stroke not visibly thicker'
    stroke_checks = []
    for name, cx, cy in [('axis-aligned-far-orchid', 480, 320), ('compact-orchid', 320, 240)]:
        pixels = rgb(name)
        assert (np.max(pixels, axis=2) > 40).sum() > 30, name+' marker missing'
        # Isolate the vertical arm, away from the central overlapping axes.
        row = pixels[cy-6, cx-10:cx+11]
        width = int((np.max(row, axis=1) > 8).sum())
        assert 5 <= width <= 8, (name, 'projected stroke width', width)
        stroke_checks.append(dict(case=name, measured_stroke_pixels=width))
    assert hashlib.sha256(source.read_bytes()).hexdigest() == digest, 'Source bytes changed'
    report.update(pixel_cases=metrics, stroke_checks=stroke_checks, source_sha256_unchanged=digest,
                  comparison='Per renderer only; RGB delta thresholds are visibility evidence, not calibrated color.')
    (out/'visibility-report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'Probe visibility: {report["checks"]} native checks, {len(metrics)} pixel cases PASS ({args.renderer}); source unchanged')


if __name__ == '__main__':
    main()

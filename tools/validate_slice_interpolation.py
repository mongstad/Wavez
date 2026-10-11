"""Forward+ slice accuracy/nonfinite regression; optional retained #360 inputs.

NumPy/Pillow and Godot stay externally installed. Outputs must be external.
The baseline is the unchanged hardware sample at the same UV; --baseline-ref
can instead extract the exact accepted shader from Git.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture, SceneReader
from tools.package_linux import stage, build

LIMITS = dict(scalar=0.0002, calibration=2e-6, probe=2e-6, wide=0.012, narrow=0.02)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def production_fixture(out):
    """The four #360 slice geometries, without its volume/performance campaign."""
    out.mkdir(); cases = []
    for name in ['scientific', 'cell', 'transformed']:
        dims = np.array([17, 13, 9]); extent = np.array([1.5, 1., .8])
        origin = -extent / 2; spacing = extent / (dims - 1)
        z, y, x = np.indices(dims[::-1], dtype=float)
        values = .25 + .3*(origin[0]+x*spacing[0]) + .1*(origin[1]+y*spacing[1]) + .12*(origin[2]+z*spacing[2])
        transform = np.column_stack((np.eye(3), np.zeros(3)))
        if name == 'transformed':
            c, s = np.cos(.35), np.sin(.35)
            transform = np.array([[c*1.2, 0, s*1.1, .3], [0, .8, 0, -.2], [-s*1.2, 0, c*1.1, .1]])
        arrays = [values + v for v in ([0., .6, -.8, .2] if name == 'scientific' else [0.])]
        path = out / (name + '.wvz')
        with SceneCapture(path, objects=[dict(id='field', kind='volume', units='1', data_to_world=transform.ravel().tolist())], metadata={'time_unit': 's', 'position_unit': 'm'}) as cap:
            for i, v in enumerate(arrays):
                cap.add_volume('field', i*.125, {'scalar': v}, origin=origin.tolist(), spacing=spacing.tolist(), centering='cell' if name == 'cell' else 'node')
        hashes = []; probes = []
        with SceneReader(path) as reader:
            for i, v in enumerate(arrays):
                assert np.array_equal(reader.read_sample('field', i)['scalar'], v)
                hashes.append(hashlib.sha256(v.tobytes()).hexdigest())
                for p in [np.zeros(3), np.array([.13, -.17, .09])]:
                    world = transform[:, :3] @ p + transform[:, 3]
                    expected = .25 + np.dot([.3, .1, .12], p) + [0., .6, -.8, .2][i]
                    assert abs(reader.probe('field', i, 'scalar', world)-expected) < 1e-12
                    probes.append(dict(sample=i, world=world.tolist(), expected=expected))
        cases.append(dict(name=name, dimensions=dims.tolist(), source_hashes=hashes, probes=probes, gpu_full_bytes=int(np.prod(dims)*4)))
    (out / 'oracle.json').write_text(json.dumps(dict(cases=cases), indent=2)+'\n')
    return out


def scalar_fixture(out):
    out.mkdir(); cases = []; rng = np.random.default_rng(374)
    def add(name, a, g):
        dims = np.array(a.shape[::-1]); uv = ((g+.5)/dims).astype('f4')
        # Independent float64 oracle for all-finite neighborhoods only.
        grid = np.clip(uv.astype('f8')*dims-.5, 0, dims-1)
        lo = np.floor(grid).astype(int); hi = np.minimum(lo+1, dims-1); f = grid-lo
        expected = np.zeros(len(g)); invalid = np.zeros(len(g), dtype=bool)
        for z in range(2):
            for y in range(2):
                for x in range(2):
                    at = np.where([x, y, z], hi, lo)
                    v = a[at[:, 2], at[:, 1], at[:, 0]].astype('f8')
                    invalid |= ~np.isfinite(v)
                    expected += np.where(np.isfinite(v), v, 0)*np.prod(np.where([x, y, z], f, 1-f), axis=1)
        expected[invalid] = np.nan
        padded = np.zeros((int(np.ceil(len(g)/512))*512, 4), dtype='<f4')
        padded[:len(g), :3] = uv; padded[:len(g), 3] = expected
        (out / (name+'.rf')).write_bytes(a.astype('<f4').tobytes())
        (out / (name+'.points')).write_bytes(padded.tobytes())
        (out / (name+'.json')).write_text(json.dumps(dict(expected_f32=expected.tolist(), uv=uv.tolist(), dimensions=dims.tolist()), indent=2)+'\n')
        cases.append(dict(name=name, dimensions=dims.tolist(), count=len(g), points_height=len(padded)//512))
    a = rng.uniform(-2, 4, (3, 5, 7)).astype('f4')
    z, y, x = np.indices(a.shape)
    centers = np.column_stack((x.ravel(), y.ravel(), z.ravel()))
    boundaries = np.array([[x, y, z] for x in [-.5, 0, 6, 6.5] for y in [-.5, 0, 4, 4.5] for z in [-.5, 0, 2, 2.5]])
    add('finite-irregular', a, np.vstack((centers, rng.uniform(0, [6, 4, 2], (2048, 3)), boundaries)))
    for i, v in enumerate([-.5, 0., .5, 1.2, 2.4]):
        add('finite-constant-'+str(i), np.full((3, 5, 7), v, dtype='f4'), boundaries)
    # Power-of-two texture dimensions make exact zero weights representable.
    points = np.array([[x, y, z] for z in [-.5, 0, .25, .5, 1, 1.5, 2, 3, 3.5] for y in [0, 1, 2, 3] for x in [0, 1, 2, 3]])
    for name, v in [('nan', np.nan), ('inf', np.inf), ('negative-inf', -np.inf)]:
        a = np.full((4, 4, 4), .5, dtype='f4'); a[1, 1, 1] = v
        add('nonfinite-'+name, a, points)
    (out / 'cases.json').write_text(json.dumps(cases, indent=2)+'\n')
    return out


def nonfinite_source(out):
    path = out/'nonfinite-source.wvz'; hashes = []
    with SceneCapture(path, objects=[dict(id='field', kind='volume', units='1')], metadata={'time_unit': 's', 'position_unit': 'm'}) as cap:
        for i, invalid in enumerate([np.nan, np.inf, -np.inf]):
            values = np.full((4, 4, 4), .5); values[1, 1, 1] = invalid
            cap.add_volume('field', i*.125, {'scalar': values}, origin=[0., 0., 0.], spacing=[1., 1., 1.], centering='node')
            hashes.append(hashlib.sha256(values.tobytes()).hexdigest())
    return path, hashes


def expected_image(row):
    yy, xx = np.indices((192, 256)); x = (xx+.5-128)*2/192; y = (96-yy-.5)*2/192
    scale = np.array([1.2, .8, 1.1]) if row['case'] == 'transformed' else np.ones(3)
    x /= scale[0]; y /= scale[1]; z = .037/scale[2]
    hx = .75 + (1.5/16/2 if row['case'] == 'cell' else 0)
    hy = .5 + (1/12/2 if row['case'] == 'cell' else 0)
    mask = (abs(x) < hx-2/96/scale[0]) & (abs(y) < hy-2/96/scale[1])
    value = .25+.3*np.clip(x, -.75, .75)+.1*np.clip(y, -.5, .5)+.12*z
    if row['case'] == 'positive-log': value += .6
    state = row['settings']; u = np.clip((value-state['lower'])/(state['upper']-state['lower']), 0, 1)
    if row['mode'] == 'slice-log':
        if row['case'] != 'positive-log': return mask, np.zeros_like(value)
        u = np.clip((np.log(value)-np.log(state['lower']))/(np.log(state['upper'])-np.log(state['lower'])), 0, 1)
    # Independent interpolation of the RGB8 gray LUT in linear space, then sRGB.
    def linear(v): return np.where(v <= .04045, v/12.92, ((v+.055)/1.055)**2.4)
    at = u*255; lo = np.floor(at); hi = np.minimum(lo+1, 255)
    value = linear(lo/255)*(1-(at-lo))+linear(hi/255)*(at-lo)
    return mask, np.where(value <= .0031308, value*12.92, 1.055*value**(1/2.4)-.055)


def assess(out, job):
    result = json.loads((out/'results.json').read_text()); images = []; scalars = []; failures = list(result['failures'])
    holds = [r for r in result['records'] if r['kind'] == 'hold']
    for row in holds:
        index = 0 if row['requested'] < .125 else 1 if row['requested'] < .25 else 2
        if row['a'] != index or row['source_time'] != index*.125 or abs(row['probe']-(.25+[0., .6, -.8][index])) > LIMITS['probe']:
            failures.append('Held source clock/probe '+str(row['requested']))
    if len(holds) != 4: failures.append('Four held source transitions required')
    for row in result['records']:
        if row['kind'] != 'snapshot' or row['case'].startswith('hold-'): continue
        if row['lod'] != (2 if row['case'] == 'scientific-lod' else 1): failures.append('Preview LOD '+row['image'])
        if row['case'] == 'scientific-lod' and row['gpu_bytes'] != 9*7*5*4: failures.append('LOD2 RF allocation '+row['image'])
        if row['case'] == 'nonfinite-source':
            if row['variant'] == 'hardware':
                other = row['image'].replace('-hardware-', '-explicit-')
                same = np.array_equal(np.asarray(Image.open(out/row['image'])), np.asarray(Image.open(out/other)))
                images.append(dict(case=row['case'], sequence=row['sequence'], mode=row['mode'], variant='pair', bytes_identical=same, status='PASS' if same else 'FAIL'))
                if not same: failures.append('Nonfinite slice footprint '+row['image'])
            continue
        mask, expected = expected_image(row)
        actual = np.asarray(Image.open(out/row['image']).convert('RGB')) / 255.
        error = float(np.max(abs(actual[mask]-expected[mask, None])))
        limit = LIMITS['narrow'] if row['mode'] == 'slice-narrow' else LIMITS['wide']
        images.append(dict(case=row['case'], mode=row['mode'], variant=row['variant'], max_rgb_error=error, limit=limit, status='PASS' if error <= limit else 'FAIL'))
        if row['variant'] == 'explicit' and error > limit: failures.append('Candidate image '+row['image'])
    narrow = [r for r in images if r['mode'] == 'slice-narrow' and r['variant'] == 'explicit']
    if len(narrow) != 4: failures.append('Four narrow slice cases required')
    for item in job['scalar_cases']:
        name = item['name']; count = item['count']; source = Path(job['scalars'])
        metadata = json.loads((source/(name+'.json')).read_text())
        codes = []
        for mode in [0, 1, 2]:
            rgb = np.asarray(Image.open(out/f'{name}-{mode}.png').convert('RGB')).reshape(-1, 3).astype('i8')[:count]
            codes.append(rgb @ np.array([65536, 256, 1]))
        a = np.frombuffer((source/(name+'.rf')).read_bytes(), '<f4').reshape(item['dimensions'][::-1])
        dims = np.array(item['dimensions']); uv = np.array(metadata['uv'], dtype='f4')
        # Classify the actual float32 fetch neighborhood, including zero weights.
        g = np.clip(uv*dims.astype('f4')-.5, 0, dims-1); lo = np.floor(g).astype(int); hi = np.minimum(lo+1, dims-1)
        invalid = np.zeros(count, dtype=bool)
        for z in range(2):
            for y in range(2):
                for x in range(2):
                    at = np.where([x, y, z], hi, lo)
                    invalid |= ~np.isfinite(a[at[:, 2], at[:, 1], at[:, 0]])
        same = np.array_equal(codes[0][invalid], codes[1][invalid])
        # Every invalid result's NaN/Inf/finite class must also agree globally.
        classes = lambda code: np.where(code == 16777215, 1, np.where(code == 16777214, 2, 0))
        footprint = np.array_equal(classes(codes[0]), classes(codes[1]))
        expected = np.array(metadata['expected_f32']); finite = ~invalid & np.isfinite(expected)
        errors = [float(np.max(abs((code[finite]/16777215*16-8)-expected[finite]))) if finite.any() else 0 for code in codes]
        if not same or not footprint or errors[1] > LIMITS['scalar'] or errors[2] > LIMITS['calibration']:
            failures.append('Scalar/nonfinite '+name)
        scalars.append(dict(case=name, count=count, invalid_neighborhoods=int(invalid.sum()), fallback_bytes_identical=same, nonfinite_classes_identical=footprint, hardware_max_error=errors[0], candidate_max_error=errors[1], calibration_max_error=errors[2], classifications=[dict(finite=int((classes(c)==0).sum()), nan=int((classes(c)==1).sum()), inf=int((classes(c)==2).sum())) for c in codes[:2]]))
    report = dict(limits=LIMITS, runtime={k: result[k] for k in ['godot', 'renderer', 'driver', 'gpu', 'checks']}, images=images, scalars=scalars, failures=failures)
    (out/'assessment.json').write_text(json.dumps(report, indent=2)+'\n')
    return report


def review_package(godot, out):
    with tempfile.TemporaryDirectory(prefix='wavez-slice-review-') as temporary:
        project = Path(temporary)/'viewer'; stage(project)
        script = (project/'layers/test_slice_interpolation.gd').read_text()
        script = script.replace('extends SceneTree', 'extends Node\nvar root: Window:\n\tget: return get_tree().root\nvar process_frame: Signal:\n\tget: return get_tree().process_frame')
        script = script.replace('func _initialize()', 'func _ready()').replace('create_timer(', 'get_tree().create_timer(').replace('quit(', 'get_tree().quit(')
        (project/'slice_review.gd').write_text(script)
        (project/'SliceReview.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://slice_review.gd" id="1"]\n[node name="SliceReview" type="Node"]\nscript = ExtResource("1")\n')
        settings = project/'project.godot'; settings.write_text(settings.read_text().replace('res://Main.tscn', 'res://SliceReview.tscn'))
        binary = out/'WAVEZ-slice-review.x86_64'; build(godot, project, binary, out/'build-logs')
    return str(binary)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True); p.add_argument('--output-dir', required=True, type=Path)
    p.add_argument('--fixtures-dir', type=Path, help='Reuse #360 production-inputs, read-only')
    p.add_argument('--scalars-dir', type=Path, help='Reuse #360 scalar fixtures, read-only')
    p.add_argument('--baseline-ref', help='Git ref containing the accepted hardware slice shader')
    p.add_argument('--export', action='store_true', help='Run identical checks through an external Linux release template')
    args = p.parse_args(); out = args.output_dir.resolve()
    if out.is_relative_to(ROOT): p.error('Keep generated evidence outside the repository')
    out.mkdir(parents=True, exist_ok=False)
    fixtures = args.fixtures_dir.resolve() if args.fixtures_dir else production_fixture(out/'fixtures')
    scalar_dir = args.scalars_dir.resolve() if args.scalars_dir else scalar_fixture(out/'scalars')
    cases = json.loads((scalar_dir/'cases.json').read_text())
    if args.scalars_dir:
        cases = [c for c in cases if c['name'] in ['original-354', 'irregular-signed', 'smooth', 'nonfinite-nan', 'nonfinite-inf'] or c['name'].startswith('constant-')]
        assert len(cases) == 11, 'Retained #360 scalar cases required'
    # Always include exact-zero-weight and negative-Inf controls.
    if args.scalars_dir:
        extra = scalar_fixture(out/'extra-scalars')
        combined = out/'scalar-inputs'; combined.mkdir()
        for item in cases:
            for suffix in ['rf', 'points', 'json']:
                (combined/(item['name']+'.'+suffix)).write_bytes((scalar_dir/(item['name']+'.'+suffix)).read_bytes())
        for item in json.loads((extra/'cases.json').read_text()):
            if item['name'].startswith('nonfinite-'):
                item['name'] = 'exact-'+item['name']; cases.append(item)
                for suffix in ['rf', 'points', 'json']:
                    (combined/(item['name']+'.'+suffix)).write_bytes((extra/(item['name'].removeprefix('exact-')+'.'+suffix)).read_bytes())
        scalar_dir = combined
    shaders = out/'shaders'; shaders.mkdir()
    candidate = (ROOT/'viewer/layers/slice.gdshader').read_text()
    baseline = subprocess.check_output(['git', 'show', args.baseline_ref+':viewer/layers/slice.gdshader'], cwd=ROOT, text=True) if args.baseline_ref else candidate.replace('float value=slice_value(uv);', 'float value=texture(field_texture,uv).r;')
    (shaders/'slice-hardware.gdshader').write_text(baseline); (shaders/'slice-explicit.gdshader').write_text(candidate)
    nonfinite, hashes = nonfinite_source(out)
    job = dict(source=str(fixtures), output=str(out), shaders=str(shaders), scalars=str(scalar_dir), scalar_cases=cases, nonfinite_source=str(nonfinite), nonfinite_hashes=hashes)
    (out/'job.json').write_text(json.dumps(job, indent=2)+'\n')
    sources = list(fixtures.glob('*.wvz'))+list(scalar_dir.glob('*.rf'))+list(scalar_dir.glob('*.points'))+[nonfinite]
    before = {str(path): digest(path) for path in sources}
    command = [review_package(args.godot, out)] if args.export else [args.godot, '--path', str(ROOT/'viewer'), '--script', 'res://layers/test_slice_interpolation.gd']
    command += ['--audio-driver', 'Dummy', '--rendering-method', 'forward_plus', '--rendering-driver', 'vulkan', '--log-file', str(out/'godot.log'), '--', '--job='+str(out/'job.json')]
    with (out/'native.log').open('w') as log: result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=240)
    (out/'exit.json').write_text(json.dumps(dict(returncode=result.returncode, command=command), indent=2)+'\n')
    assert result.returncode == 0 and (out/'results.json').exists(), out/'native.log'
    report = assess(out, job); report['source_hashes_unchanged'] = before == {str(path): digest(path) for path in sources}
    report['packaged'] = args.export
    (out/'assessment.json').write_text(json.dumps(report, indent=2)+'\n')
    assert report['source_hashes_unchanged'] and not report['failures'], out/'assessment.json'
    log = (out/'native.log').read_text(); assert 'ERROR:' not in log and 'WARNING:' not in log, out/'native.log'
    print(f'Slices: {report["runtime"]["checks"]} native checks; 4/4 narrow cases PASS; scalar/nonfinite PASS; sources unchanged')


if __name__ == '__main__': main()

"""Adaptive mesh RAM admission on a read-only 256x256, 2401-sample capture."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneReader, SceneCapture


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def run(command, out, label, env, timeout=360):
    result = subprocess.run(command, capture_output=True, text=True, env=env, timeout=timeout)
    log = result.stdout + result.stderr
    (out / (label + '.log')).write_text(log)
    # Existing native Wayland decoration fallback, retained verbatim in evidence.
    decor = "libdecor-gtk-WARNING: Failed to initialize GTK\nFailed to load plugin 'libdecor-gtk.so': failed to init\n"
    checked = log.replace(decor, '') if log.count(decor) == 1 else log
    if result.returncode or 'ERROR:' in checked or 'WARNING:' in checked:
        raise RuntimeError(f'{label} failed; see {out / (label + ".log")}')
    return [decor] if checked != log else []


def oracle(capture):
    with SceneReader(capture, strict=True, cache_bytes=0) as reader:
        meshes = [key for key, obj in reader.objects.items() if obj['kind'] == 'mesh']
        assert len(meshes) == 1, 'Expected the single-mesh acceptance capture'
        key = meshes[0]
        assert reader.objects[key]['identity'] == 'stable_topology'
        assert len(reader.samples[key]) == 2401
        result = []
        for index in [0, 1, 400, 1200, 2399, 2400]:
            arrays = reader.read_sample(key, index)
            assert arrays['position'].shape == (256 * 256, 3)
            assert len([v for k, v in arrays.items() if v.ndim == 1 and k != 'vertex_id']) >= 2
            channels = {}
            for name, values in arrays.items():
                # Match the reader's documented native packed representation.
                dtype = ('<i4' if name == 'triangles' else '<f8') if values.dtype.kind == 'u' else values.dtype
                channels[name] = hashlib.sha256(values.astype(dtype).tobytes()).hexdigest()
            result.append(dict(index=index, channels=channels))
        return key, result


def mixed_fixture(capture, out):
    with SceneReader(capture, cache_bytes=0) as reader:
        key = next(key for key, obj in reader.objects.items() if obj['kind'] == 'mesh')
        objects = [dict(id='surface', kind='mesh', units='m', identity='stable_topology'),
                   dict(id='particles', kind='particles', units='m', identity='persistent_i8'),
                   dict(id='field', kind='volume', units='m')]
        with SceneCapture(out, objects=objects, compression='zstd') as writer:
            for index, time in [(0, 0.), (7, .7), (19, 1.9), (30, 3.)]:
                arrays = reader.read_sample(key, index)
                writer.add_mesh('surface', time, arrays['position'], arrays['triangles'],
                                vertex_channels={name: value for name, value in arrays.items() if name not in ['position', 'triangles']})
                writer.add_particles('particles', time, np.array([[time, 0., 0.]], dtype='f8'), ids=np.array([7], dtype='i8'))
                writer.add_volume('field', time, {'rho':np.full((8, 8, 8), time + 1, dtype='f4')}, origin=[0, 0, 0], spacing=[1, 1, 1])


def swap_io():
    path = Path('/proc/vmstat')
    return {key: int(value) for key, value in (line.split() for line in path.read_text().splitlines())
            if key in ['pswpin', 'pswpout']} if path.exists() else {}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--capture', required=True, type=Path)
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--renderer', choices=['headless', 'forward_plus', 'gl_compatibility'], default='headless')
    parser.add_argument('--export', action='store_true')
    args = parser.parse_args()
    out = args.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    capture = args.capture.resolve(); before = digest(capture)
    key, expected = oracle(capture)
    mixed_fixture(capture, out / 'mixed.ssc')
    version = re.search(r'config/version="([^"]+)"', (ROOT / "viewer" / "project.godot").read_text()).group(1)
    config = dict(application_version=version, capture=str(capture), object_id=key, oracle=expected, output=str(out), mixed=str(out / 'mixed.ssc'))
    job = out / 'job.json'; job.write_text(json.dumps(config, indent=2))
    env = os.environ.copy(); env['XDG_CONFIG_HOME'] = str(out / 'config')
    if args.export:
        project = out / 'export-source'
        shutil.copytree(ROOT / 'viewer', project, ignore=shutil.ignore_patterns('.godot'))
        settings = project / 'project.godot'
        settings.write_text(re.sub(r'run/main_scene=.*', 'run/main_scene="res://mesh_budget_validation.tscn"', settings.read_text()))
        (project / 'mesh_budget_validation.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://layers/test_mesh_budget.gd" id="1"]\n[node name="MeshBudgetValidation" type="Node"]\nscript = ExtResource("1")\n')
        (project / 'export_presets.cfg').write_text('[preset.0]\nname="Mesh budget validation"\nplatform="Linux"\nrunnable=true\nexport_filter="all_resources"\ninclude_filter=""\nexclude_filter=""\nscript_export_mode=2\n[preset.0.options]\nbinary_format/architecture="x86_64"\nbinary_format/embed_pck=false\n')
        binary = out / 'wavez.x86_64'
        for label, options in [('import', ['--editor', '--import', '--quit']), ('export', ['--export-release', 'Mesh budget validation', str(binary)])]:
            run([args.godot, '--headless', '--path', str(project), *options], out, label, env)
        command = [str(binary)]
    else:
        command = [args.godot, '--path', str(ROOT / 'viewer'), '--script', 'res://layers/run_mesh_budget_tests.gd']
    env['XDG_DATA_HOME'] = str(out / 'profile')
    command += ['--audio-driver', 'Dummy', '--log-file', str(out / 'godot.log')]
    command += ['--headless'] if args.renderer == 'headless' else ['--rendering-method', args.renderer, '--display-driver', 'wayland', '--resolution', '1440x900']
    swap_before = swap_io()
    diagnostics = run(command + ['--', '--mesh-budget-job=' + str(job)], out, 'native', env)
    swap_after = swap_io()
    report = json.loads((out / 'report.json').read_text())
    assert not report['failures'], report['failures']
    assert report['packaged'] == args.export
    assert digest(capture) == before
    report.update(source_sha256_unchanged=before, source_bytes=capture.stat().st_size, known_engine_diagnostics=diagnostics,
                  system_swap_io_delta={key: swap_after[key] - value for key, value in swap_before.items()})
    (out / 'validation.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'Mesh budget: {report["checks"]} PASS ({args.renderer}, packaged={args.export}); source hash unchanged; callbacks {report["callbacks"]}')


if __name__ == '__main__':
    main()

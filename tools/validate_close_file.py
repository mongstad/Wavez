"""Focused #329 capture disposal and live export ownership on tiny WVZ1 inputs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tests.g4.fixtures import scene
from tools.validate_simulation_panel import fixture
from tools.package_linux import stage, build


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['headless', 'forward_plus', 'gl_compatibility'], default='headless')
    parser.add_argument('--package', action='store_true')
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    for name, kinds in {'particles':['particles'], 'fields':['volume'], 'meshes':['mesh']}.items():
        fixture(out / (name+'.wvz'), kinds)
    scene(out / 'mixed.wvz')
    hashes = {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.wvz')}
    env = dict(os.environ, XDG_CONFIG_HOME=str(out / 'config'), XDG_DATA_HOME=str(out / 'profile'))
    if args.package:
        project = out / 'export-source'
        stage(project)
        (project / 'CloseReview.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://close_review_entry.gd" id="1"]\n[node name="CloseReview" type="Node"]\nscript = ExtResource("1")\n')
        (project / 'close_review_entry.gd').write_text('extends Node\nfunc _ready():\n\tfor arg in OS.get_cmdline_user_args():\n\t\tif arg.begins_with("--wavez-render-job="): add_child(load("res://main.gd").new()); return\n')
        config_path = project / 'project.godot'
        config_path.write_text(config_path.read_text().replace('res://Main.tscn', 'res://CloseReview.tscn'))
        with (project / 'project.godot').open('a') as config:
            config.write('\n[autoload]\nCloseValidation="*res://ui/shell/test_close_file.gd"\n')
        executable = out / 'WAVEZ.x86_64'
        build(args.godot, project, executable, out / 'build-logs')
        command = [str(executable)]
    else:
        command = [args.godot, '--path', str(ROOT / 'viewer'), '--script', 'res://ui/shell/run_close_file_tests.gd']
    command += ['--audio-driver', 'Dummy']
    command += ['--headless'] if args.renderer == 'headless' else ['--rendering-method', args.renderer, '--resolution', '1440x900']
    command += ['--', '--close-output='+str(out)]
    result = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True, timeout=600)
    log = result.stdout + result.stderr
    (out / 'native.log').write_text(log)
    if result.returncode:
        raise RuntimeError(f'Close File failed: {out / "native.log"}\n{log[-5000:]}')
    report = json.loads((out / 'report.json').read_text())
    assert not report['failures'], report
    assert hashes == {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.wvz')}
    # Validate numerical output independently of the UI's completion status.
    numerical = {}
    for name in ['values.csv', 'members.csv']:
        first = out / 'control-data' / name
        second = out / 'refused-data' / name
        if first.exists():
            assert first.read_bytes() == second.read_bytes(), name
            numerical[name] = hashlib.sha256(first.read_bytes()).hexdigest()
    assert 'values.csv' in numerical
    video = {}
    if args.renderer != 'headless':
        for prefix in ['ordinary', 'selected']:
            decoded = []
            for suffix in ['control', 'closed']:
                path = out / (prefix+'-'+suffix+'.mp4')
                frames = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path), '-f', 'framemd5', '-'], text=True)
                (out / (path.stem+'.framemd5')).write_text(frames)
                decoded.append(frames)
            assert decoded[0] == decoded[1], prefix+' decoded frames/timestamps differ'
            video[prefix] = {'decoded_frames_and_timestamps_identical':True, 'framemd5_sha256':hashlib.sha256(decoded[0].encode()).hexdigest()}
        # Inspection sidecars preserve worker scientific clocks and snapshots.
        for prefix in ['ordinary', 'selected']:
            entries = [item for item in report['exports'] if item['name'].startswith(prefix)]
            sidecars = [sorted(Path(item['directory']).glob('inspection-*.json')) for item in entries]
            assert len(sidecars[0]) == len(sidecars[1]) and sidecars[0], sidecars
            for first, second in zip(*sidecars):
                values = [json.loads(path.read_text()) for path in [first, second]]
                assert values[0] == values[1], first.name
            assert (Path(entries[0]['directory']) / 'timing.jsonl').read_bytes() == (Path(entries[1]['directory']) / 'timing.jsonl').read_bytes()
            video[prefix]['identical_inspection_sidecars'] = len(sidecars[0])
            video[prefix]['ordinary_visual_records'] = True
            video[prefix]['timing_trace_byte_identical'] = True
    summary = dict(checks=report['checks'], renderer=args.renderer, packaged=args.package,
                   source_sha256_unchanged=hashes, numerical_outputs_identical=numerical,
                   video_comparison=video, headless_video_skipped=args.renderer == 'headless', report=report,
                   process_exit_code=result.returncode, runtime_log_clean='ERROR:' not in log and 'WARNING:' not in log)
    if args.package:
        summary['artifacts'] = {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [executable, executable.with_suffix('.pck')]}
    (out / 'validation.json').write_text(json.dumps(summary, indent=2)+'\n')
    if not summary['runtime_log_clean']:
        raise RuntimeError(f'Close File: {report["checks"]} runtime checks and export comparisons passed, but diagnostics prevent a clean run. See {out / "native.log"} and {out / "validation.json"}')
    print(f'Close File: {report["checks"]} PASS ({args.renderer}, packaged={args.package}); source hashes and export comparisons verified')


if __name__ == '__main__':
    main()

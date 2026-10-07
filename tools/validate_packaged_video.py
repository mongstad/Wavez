"""#93: production video dialog and real children in development and Linux release.

The instrumented release changes only the parent entry scene. Worker invocations
use the unchanged Main.tscn. Staging is removed before running, cwd is unrelated,
PYTHONPATH is empty, and PATH has no Godot editor. External dependencies remain
Python/NumPy and FFmpeg. Generated WVZ1 inputs are hashed before and after.
"""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from package_linux import stage, build
from validate_video_current import fixtures

ROOT = Path(__file__).resolve().parents[1]


def run(command, folder, env, cwd, timeout=100, hide_pack=False):
    held = None
    process = None
    try:
        with (folder / 'native.log').open('w') as log:
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, env=env, cwd=cwd)
            if hide_pack:
                deadline = time.monotonic() + 30
                while not (folder / 'ready-to-launch.json').exists() and process.poll() is None and time.monotonic() < deadline:
                    time.sleep(.02)
                if not (folder / 'ready-to-launch.json').exists(): raise RuntimeError('Parent did not reach startup-failure barrier')
                pack = Path(command[0]).with_suffix('.pck')
                held = pack.with_suffix('.held')
                pack.rename(held)
                (folder / 'continue').touch()
            deadline = time.monotonic() + timeout
            alert_dismissed = False
            while process.poll() is None and time.monotonic() < deadline:
                launched = folder / 'launched.json'
                if hide_pack and not alert_dismissed and launched.exists():
                    # Restore the parent's pack before it loads the failure icon.
                    # The child has already emitted its startup refusal.
                    if held is not None and b'.pck file missing' in (folder / 'native.log').read_bytes():
                        held.rename(held.with_suffix('.pck')); held = None
                    child = json.loads(launched.read_text())['pid']
                    children = Path(f'/proc/{child}/task/{child}/children')
                    if children.exists():
                        for pid in children.read_text().split():
                            cmdline = Path(f'/proc/{pid}/cmdline')
                            if cmdline.exists():
                                arguments = cmdline.read_bytes().split(b'\0')
                                if Path(os.fsdecode(arguments[0])).name == 'zenity' and any(b'.pck file missing' in a for a in arguments):
                                    os.kill(int(pid), signal.SIGTERM)
                                    alert_dismissed = True
                time.sleep(.02)
            if process.poll() is None: raise subprocess.TimeoutExpired(command, timeout)
    finally:
        if process is not None and process.poll() is None: process.kill(); process.wait()
        if held is not None and held.exists(): held.rename(held.with_suffix('.pck'))
    return process.returncode, (folder / 'native.log').read_text()


def test_package(godot, output):
    with tempfile.TemporaryDirectory(prefix='wavez-video-test-') as temporary:
        project = Path(temporary) / 'viewer'
        inventory = stage(project)
        script = (project / 'video/test_packaged_export.gd').read_text()
        script = script.replace('extends SceneTree', 'extends Node\nvar root: Window:\n\tget: return get_tree().root\nvar process_frame: Signal:\n\tget: return get_tree().process_frame')
        script = script.replace('func _initialize()', 'func _ready()').replace('create_timer(', 'get_tree().create_timer(').replace('quit(', 'get_tree().quit(')
        (project / 'review_video.gd').write_text(script)
        (project / 'review_entry.gd').write_text('''extends Node
func _ready():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--wavez-render-job="):
            add_child(load("res://Main.tscn").instantiate());return
    add_child(load("res://review_video.gd").new())
''')
        (project / 'Review.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://review_entry.gd" id="1"]\n[node name="Review" type="Node"]\nscript = ExtResource("1")\n')
        config = project / 'project.godot'
        config.write_text(config.read_text().replace('res://Main.tscn', 'res://Review.tscn'))
        binary = output / 'WAVEZ.x86_64'
        build(godot, project, binary, output / 'build-logs')
    (output / 'python-inventory.json').write_text(json.dumps(inventory, indent=2) + '\n')
    return str(binary)


def decoded(path):
    return subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path), '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], required=True)
    parser.add_argument('--export', action='store_true')
    parser.add_argument('--cases', nargs='+', help='Run named cases only')
    parser.add_argument('--compare-source', type=Path, help='Compare completed output pixels/timing with a source run on the same renderer')
    args = parser.parse_args()
    output = args.output_dir.resolve(); output.mkdir(parents=True, exist_ok=False)
    inputs = output / 'inputs'; inputs.mkdir(); fixtures(inputs)
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs.glob('*.wvz')}
    executable = test_package(args.godot, output) if args.export else args.godot
    cwd = output / 'unrelated working directory'; cwd.mkdir()
    # A neighboring project must never be selected by the release executable.
    (cwd / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Unrelated project"\n')
    env = dict(os.environ, PYTHONPATH='', PATH='/usr/bin:/bin',
               XDG_DATA_HOME=str(output / 'profile/data'), XDG_CONFIG_HOME=str(output / 'profile/config'))
    ffmpeg = shutil.which('ffmpeg'); assert ffmpeg
    bad = output / 'failed ffmpeg'; bad.write_text('#!/bin/sh\nif [ "$1" = "-version" ]; then exec ' + ffmpeg + ' -version; fi\nexit 1\n'); bad.chmod(0o755)
    slow = output / 'slow ffmpeg'; slow.write_text('#!' + sys.executable + '\nimport os,sys,time\na=sys.argv[1:]\nif a == ["-version"]: os.execv(' + repr(ffmpeg) + ',["ffmpeg","-version"])\ntime.sleep(3)\nos.execv(' + repr(ffmpeg) + ',["ffmpeg"]+a)\n'); slow.chmod(0o755)
    cases = [
        ('particles-off', 'particles', {}), ('particles-on', 'particles', dict(overlays=True, orbit=True)),
        ('mixed-off', 'mixed', {}), ('mixed-on', 'mixed', dict(overlays=True)),
        ('selection', 'particles', dict(selection=True, overlays=True)),
        ('cancel-rendering', 'particles', dict(cancel='rendering', expected='cancelled')),
        ('cancel-encoding', 'particles', dict(cancel='encoding', expected='cancelled', ffmpeg=str(slow))),
        ('failed-encoder', 'particles', dict(expected='failed', ffmpeg=str(bad))),
        ('missing-encoder', 'particles', dict(missing=True, ffmpeg='/missing/ffmpeg')),
        ('parent-shutdown', 'particles', dict(cancel='shutdown', expected='cancelled')),
    ]
    if args.export: cases.append(('startup-failure', 'particles', dict(startup_failure=True, expected='failed')))
    reports = []; checks = []
    def check(ok, label):
        checks.append(dict(ok=bool(ok), label=label))
        if not ok: print('FAIL: ' + label, flush=True)
    for name, kind, changes in cases:
        if args.cases and name not in args.cases: continue
        folder = output / name; folder.mkdir()
        config = dict(source=str(inputs / (kind + '.wvz')), packaged=args.export, ffmpeg=ffmpeg, **{})
        config.update(changes); (folder / 'config.json').write_text(json.dumps(config))
        command = [executable] + ([] if args.export else ['--path', str(ROOT / 'viewer'), '--script', 'video/test_packaged_export.gd'])
        command += ['--rendering-method', args.renderer, '--audio-driver', 'Dummy', '--resolution', '960x640', '--', str(folder)]
        code, native = run(command, folder, env, cwd, hide_pack=changes.get('startup_failure',False))
        report = json.loads((folder / 'report.json').read_text()); report['name'] = name; reports.append(report)
        # Preserve the accepted encoder-kill diagnostic; do not hide other errors.
        encoder_pid = int(report.get('progress', {}).get('encoder_pid', -1))
        # Match only the retained terminal encoder's PID. Release templates omit
        # the GDScript backtrace; source builds include it.
        known = (rf'ERROR: The process {encoder_pid} does not exist or is not a child of the calling process\.\n'
                 r'   at: _check_pid_is_running \(drivers/unix/os_unix.cpp:\d+\)\n'
                 r'(?:   GDScript backtrace \(most recent call first\):\n'
                 r'       \[0\] (?:finish|_exit_tree) \(res://video/render_worker.gd:\d+\)\n'
                 r'(?:       \[1\] encode \(res://video/render_worker.gd:\d+\)\n)?)?')
        report['known_encoder_cleanup_diagnostics'] = re.findall(known, native)
        native_checked = re.sub(known, '', native)
        if changes.get('startup_failure',False):
            # The withheld-PCK child emits this exact engine diagnostic, then its
            # test-owned native alert is dismissed so the parent can observe exit.
            prefix = f"ERROR: Error: Couldn't load project data at path \"{output}\". Is the .pck file missing?"
            expected = prefix + "\n\nIf you've renamed the executable, the associated .pck file should also be renamed to match the executable's name (without the extension).\n\n   at: setup (main/main.cpp:2130)\n"
            startup_pattern = re.escape(expected).replace('2130',r'\d+')
            check(re.search(startup_pattern,native_checked) is not None, name + ': missing-PCK startup diagnostic is preserved')
            native_checked = re.sub(startup_pattern,'',native_checked)
        check(code == 0 and 'ERROR:' not in native_checked and 'WARNING:' not in native_checked, name + ': parent exits with only expected diagnostics')
        for item in report['checks']: check(item['ok'], name + ': ' + item['label'])
        if report.get('parent_shutdown'):
            directory = Path(report['directory']); deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                p = directory / 'progress.json'
                if p.exists() and json.loads(p.read_text()).get('stage') == 'cancelled': break
                time.sleep(.1)
            progress = json.loads(p.read_text())
            check((directory / 'cancel').exists() and progress['stage'] == 'cancelled', name + ': parent teardown requests and worker acknowledges cancellation')
            check(not (folder / 'result.mp4').exists(), name + ': no MP4 is published')
        if report['directory'] and not changes.get('startup_failure',False):
            directory = Path(report['directory'])
            log = (directory / 'renderer.log').read_text()
            known_diagnostics = re.findall(known, log)
            report['known_encoder_cleanup_diagnostics'] += known_diagnostics
            check('ERROR:' not in re.sub(known, '', log) and 'WARNING:' not in log, name + ': clean worker log apart from retained known encoder cleanup diagnostic')
        if (folder / 'result.mp4').exists():
            probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=codec_name,width,height,nb_frames,avg_frame_rate', '-of', 'json', str(folder / 'result.mp4')]))['streams'][0]
            check((probe['codec_name'], probe['width'], probe['height'], int(probe['nb_frames']), probe['avg_frame_rate']) == ('h264', 320, 180, 2, '4/1'), name + ': ffprobe verifies H.264, resolution, FPS and two frames')
            sidecars = sorted(Path(report['directory']).glob('inspection-*.json'))
            check(len(sidecars) == 2, name + ': required inspection sidecars retained')
            if name == 'selection':
                records = [json.loads(p.read_text()) for p in sidecars]
                check(all(r.get('kind') == 'wavez-inspection' and r.get('version') == 3 for r in records), name + ': portable version-3 inspection records')
        print(name + ': ' + ('PASS' if all(c['ok'] for c in checks) else 'see failures'), flush=True)
    check(hashes == {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs.glob('*.wvz')}, 'All synthetic source bytes unchanged')
    for kind in ['particles', 'mixed']:
        off, on = output / (kind + '-off/result.mp4'), output / (kind + '-on/result.mp4')
        if off.exists() and on.exists():
            check(decoded(off) != decoded(on), kind + ': enabled overlays/orbit affect exported pixels')
    if args.compare_source:
        for report in reports:
            name = report['name']; movie = output / name / 'result.mp4'
            if not movie.exists(): continue
            source_movie = args.compare_source / name / 'result.mp4'
            check(decoded(movie) == decoded(source_movie), name + ': release pixels match development')
            source_report = json.loads((args.compare_source / name / 'report.json').read_text())
            check((Path(report['directory']) / 'timing.jsonl').read_bytes() ==
                  (Path(source_report['directory']) / 'timing.jsonl').read_bytes(), name + ': release source-time/sample/camera trace matches development')
    if args.export:
        analysis_root = output / 'profile/data/godot/app_userdata/WAVEZ/analysis-workers'
        check(not list(analysis_root.glob('*/python-runtime')), 'Materialized first-party Python files are removed at shutdown')
    failures = sum(not c['ok'] for c in checks)
    (output / 'report.json').write_text(json.dumps(dict(renderer=args.renderer, packaged=args.export, checks=checks, runs=reports, source_hashes=hashes, failures=failures), indent=2) + '\n')
    print(f'Packaged video: {len(checks)} checks, {failures} failures ({args.renderer}, packaged={args.export})', flush=True)
    raise SystemExit(bool(failures))


if __name__ == '__main__': main()

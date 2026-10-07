"""#285: focused ETA snapshots, actual Details, and real export lifecycle.

Runs an externally paced three-minute renderer, plus short render
and encoder cancellation/failure cases. Production worker/render timing is intact.
The release harness replaces only the parent entry and delay-bearing dialog;
children dispatch through unchanged Main.tscn. Godot and FFmpeg stay external.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import signal
import time
import sys
import tempfile
from application_version import read_version
from package_linux import stage, build
from validate_video_current import fixtures

ROOT = Path(__file__).resolve().parents[1]


def package(godot, out):
    with tempfile.TemporaryDirectory(prefix='wavez-eta-review-') as temporary:
        project = Path(temporary) / 'viewer'
        stage(project)
        script = (project / 'video/test_eta.gd').read_text()
        script = script.replace('extends SceneTree', 'extends Node\nvar root: Window:\n\tget: return get_tree().root\nvar process_frame: Signal:\n\tget: return get_tree().process_frame')
        script = script.replace('func _initialize()', 'func _ready()').replace('create_timer(', 'get_tree().create_timer(').replace('quit(', 'get_tree().quit(')
        (project / 'review_eta.gd').write_text(script)
        (project / 'review_entry.gd').write_text('''extends Node
func _ready():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--wavez-render-job="):
            add_child(load("res://Main.tscn").instantiate());return
    add_child(load("res://review_eta.gd").new())
''')
        (project / 'Review.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://review_entry.gd" id="1"]\n[node name="Review" type="Node"]\nscript = ExtResource("1")\n')
        p = project / 'project.godot'
        p.write_text(p.read_text().replace('res://Main.tscn', 'res://Review.tscn'))
        binary = out / 'WAVEZ.x86_64'
        build(godot, project, binary, out / 'build-logs')
    return str(binary)


def run(command, folder, env, cwd, long_run):
    # Apply external wall-clock load to the real child. The worker's existing
    # delay hook uses fixed-fps simulated time, so it alone cannot prove a soak.
    stopped = None
    worker = None
    began = None
    resume_at = 0
    with (folder/'native.log').open('w') as log:
        process = subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,env=env,cwd=cwd)
        deadline = time.monotonic()+290
        try:
            while process.poll() is None and time.monotonic()<deadline:
                now = time.monotonic()
                if stopped is not None and now>=resume_at:
                    try:os.kill(stopped,signal.SIGCONT)
                    except ProcessLookupError:pass
                    stopped = None
                launched = folder/'launched.json'
                if long_run and launched.exists():
                    launch = json.loads(launched.read_text());worker = int(launch['pid'])
                    progress_path = Path(launch['directory'])/'progress.json'
                    try:progress = json.loads(progress_path.read_text())
                    except (FileNotFoundError,json.JSONDecodeError):progress = {}
                    if progress.get('stage')=='rendering':
                        if began is None:began = now
                        target = began + float(progress['current_frame'])*1.7
                        if stopped is None and now<target:
                            os.kill(worker,signal.SIGSTOP);stopped = worker;resume_at = target
                time.sleep(.005)
            if process.poll() is None:raise subprocess.TimeoutExpired(command,290)
        finally:
            if stopped is not None:
                try:os.kill(stopped,signal.SIGCONT)
                except ProcessLookupError:pass
            if process.poll() is None:
                process.kill();process.wait()
                if worker is not None:
                    try:os.kill(worker,signal.SIGTERM)
                    except ProcessLookupError:pass
    return process.returncode,(folder/'native.log').read_text()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], required=True)
    parser.add_argument('--export', action='store_true')
    parser.add_argument('--short-only', action='store_true')
    args = parser.parse_args()
    out = args.output_dir.resolve();out.mkdir(parents=True, exist_ok=False)
    inputs = out / 'inputs';inputs.mkdir();fixtures(inputs)
    source = inputs / 'particles.wvz'
    initial_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    executable = package(args.godot, out) if args.export else args.godot
    # Make encoding observable without changing the worker or FFmpeg output.
    slow = out / 'delayed ffmpeg'
    slow.write_text('#!' + sys.executable + '\nimport os,sys,time\na=sys.argv[1:]\nif a != ["-version"]:time.sleep(3)\nos.execv("/usr/bin/ffmpeg",["ffmpeg"]+a)\n');slow.chmod(0o755)
    failed = out / 'failed ffmpeg'
    failed.write_text('#!/bin/sh\nif [ "$1" = "-version" ]; then exec /usr/bin/ffmpeg -version; fi\nexit 1\n');failed.chmod(0o755)
    cases = [('complete', dict(long=not args.short_only, delay_ms=1500 if not args.short_only else 150)),
             ('cancel-render', dict(cancel='rendering', expected='cancelled', delay_ms=5000)),
             ('cancel-encoder', dict(cancel='encoding', expected='cancelled')),
             ('failed-encoder', dict(expected='failed', ffmpeg=str(failed)))]
    env = dict(os.environ, PYTHONPATH='', PATH='/usr/bin:/bin', XDG_DATA_HOME=str(out/'profile/data'), XDG_CONFIG_HOME=str(out/'profile/config'))
    cwd = out / 'unrelated cwd';cwd.mkdir()
    reports = [];validation = []
    def check(ok, label):
        validation.append(dict(ok=bool(ok), label=label))
        if not ok:print('FAIL: '+label,flush=True)
    for name, changes in cases:
        folder = out / name;folder.mkdir()
        config = dict(source=str(source), packaged=args.export, ffmpeg=str(slow))
        config.update(changes);(folder/'config.json').write_text(json.dumps(config))
        command = [executable] + ([] if args.export else ['--path',str(ROOT/'viewer'),'--script','video/test_eta.gd'])
        command += ['--rendering-method',args.renderer,'--audio-driver','Dummy','--resolution','1200x800','--',str(folder)]
        code, log = run(command,folder,env,cwd,changes.get("long",False))
        report = json.loads((folder/'report.json').read_text())
        details = report['measurements']['integration']
        directory = Path(details['directory'])
        encoder_pid = int(details['progress'].get('encoder_pid',-1))
        known = (rf'ERROR: The process {encoder_pid} does not exist or is not a child of the calling process\.\n'
                 r'   at: _check_pid_is_running \(drivers/unix/os_unix.cpp:\d+\)\n'
                 r'(?:   GDScript backtrace \(most recent call first\):\n'
                 r'       \[0\] (?:finish|_exit_tree) \(res://video/render_worker.gd:\d+\)\n'
                 r'(?:       \[1\] encode \(res://video/render_worker.gd:\d+\)\n)?)?')
        known_count = len(re.findall(known,log))
        check(code == 0 and 'ERROR:' not in re.sub(known,'',log) and 'WARNING:' not in log, name+': clean parent exit apart from accepted encoder teardown diagnostic')
        worker_log = (directory/'renderer.log').read_text()
        known_count += len(re.findall(known,worker_log))
        check('ERROR:' not in re.sub(known,'',worker_log) and 'WARNING:' not in worker_log,name+': worker has only accepted teardown diagnostics')
        failures = [c for c in report['checks'] if not c['ok']]
        check(not failures,name+': all focused GDScript checks pass')
        samples = details.pop('samples')
        render_samples = [s for s in samples if s['stage']=='rendering' and s['progress']]
        check(all(s['details'].startswith('Rendering frame %d / %d (%d%%)' % (s['progress']['current_frame'],s['progress']['total_frames'],100*s['progress']['current_frame']//s['progress']['total_frames'])) for s in render_samples),name+': frame count/percentage track each observed snapshot')
        def duration(line):
            h,m,s = map(int,line.split(': ',1)[1].split(':'));return h*3600+m*60+s
        check(all(duration(s['details'].splitlines()[1]) >= int(s['progress']['elapsed_seconds']) for s in render_samples),name+': live elapsed never trails worker elapsed')
        terminal_elapsed = duration(details['details'].splitlines()[1])
        check(terminal_elapsed == int(details['progress']['elapsed_seconds']),name+': terminal elapsed retains exact worker value')
        trace = [json.loads(line) for line in (directory/'timing.jsonl').read_text().splitlines()]
        job = json.loads((directory/'job.json').read_text())
        check(all(row['n']==i and abs(row['video_time']-i/job['fps'])<1e-9 and abs(row['capture_time']-i/job['fps'])<1e-9 for i,row in enumerate(trace)),name+': deterministic capture/video frame timing unchanged')
        if name=='complete':
            probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_entries','stream=codec_name,width,height,nb_frames,avg_frame_rate','-of','json',str(folder/'result.mp4')]))['streams'][0]
            count=120 if changes['long'] else 8
            check((probe['codec_name'],probe['width'],probe['height'],int(probe['nb_frames']),probe['avg_frame_rate'])==('h264',320,180,count,'60/1' if changes['long'] else '4/1'),name+': FFprobe verifies exact MP4 output')
            check('encoding' in details['stages'],name+': real encoding stage was observed')
        if name.startswith('cancel'):
            check(details['progress']['stage']=='cancelled' and (directory/'cancel').exists(),name+': cooperative cancellation acknowledged')
        reports.append(dict(name=name,checks=len(report['checks']),failures=failures,known_encoder_cleanup_diagnostics=known_count,measurements=report['measurements']))
        print(name+': '+str(len(report['checks']))+' checks, '+str(len(failures))+' failures, '+str(details['runtime_ms'])+' ms',flush=True)
    check(hashlib.sha256(source.read_bytes()).hexdigest()==initial_hash,'Source WVZ1 bytes unchanged')
    summary=dict(renderer=args.renderer,packaged=args.export,version=read_version()['full'],cases=reports,validation=validation)
    (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print('Python checks: '+str(len(validation))+'; failures: '+str(sum(not c['ok'] for c in validation)),flush=True)
    return int(any(not c['ok'] for c in validation))

if __name__=='__main__':sys.exit(main())

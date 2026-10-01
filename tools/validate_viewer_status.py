"""Native persistent status and existing job lifecycle checks."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import shutil
import time
import re
import numpy as np
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tests.g4.fixtures import scene
from wavez_export import SceneCapture


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--output-dir', type=Path, required=True)
    p.add_argument('--packaged', action='store_true', help='Run a standalone executable with its adjacent PCK')
    p.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], default='forward_plus')
    a = p.parse_args()
    out = a.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    source = scene(out / 'scene.ssc')
    fields = out / 'fields.ssc'
    with SceneCapture(fields, objects=[dict(id='field', kind='volume', units='u')]) as capture:
        for i in range(20):
            data = np.full((16,16,16), 1+i/20, dtype='f4')
            capture.add_volume('field', i*.1, dict(density=data, psi_real=data-1, psi_imag=1-data), origin=[0]*3, spacing=[1]*3)
    sources = [source, fields]
    hashes = {str(s): hashlib.sha256(s.read_bytes()).hexdigest() for s in sources}
    ffmpeg = shutil.which('ffmpeg'); assert ffmpeg
    bad = out/'bad-ffmpeg'; bad.write_text('#!/bin/sh\nexit 1\n'); bad.chmod(0o755)
    slow = out/'slow-ffmpeg'
    slow.write_text('#!'+sys.executable+'\nimport os,sys\na=sys.argv[1:];a.insert(a.index("-i"),"-re")\nos.execv('+repr(ffmpeg)+',["ffmpeg"]+a)\n');slow.chmod(0o755)
    (out/'config.json').write_text(json.dumps({'source': str(source), 'fields': str(fields), 'ffmpeg': ffmpeg, 'bad_ffmpeg': str(bad), 'slow_ffmpeg': str(slow)}))
    cmd = [a.godot]+([] if a.packaged else ['--path', str(ROOT/'viewer')])+['--rendering-method', a.renderer,
           '--log-file', str(out/'native.log'), '--audio-driver', 'Dummy', '--resolution', '1440x900', '--script', 'res://ui/shell/test_viewer_status.gd',
           '--', '--status-output='+str(out)]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    log = result.stdout + result.stderr; (out/'godot.log').write_text(log)
    # Existing render_worker cleanup rechecks an encoder PID immediately after kill.
    # Keep this known diagnostic visible; every other engine error still fails.
    cleanup_pattern = r'ERROR: The process \d+ does not exist or is not a child of the calling process\.\n   at: _check_pid_is_running \(drivers/unix/os_unix.cpp:\d+\)\n   GDScript backtrace \(most recent call first\):\n       \[0\] (?:finish|_exit_tree) \(res://video/render_worker.gd:\d+\)\n(?:       \[1\] encode \(res://video/render_worker.gd:\d+\)\n)?'
    known_cleanup = re.findall(cleanup_pattern, log)
    checked_log = re.sub(cleanup_pattern, '', log)
    if result.returncode or 'ERROR:' in checked_log or 'WARNING:' in checked_log:
        raise RuntimeError(f'Status validation failed: {out}/godot.log')
    report = json.loads((out/'report.json').read_text())
    report['known_encoder_cleanup_diagnostics'] = known_cleanup
    assert not report['failures'], report['failures']
    if a.packaged: assert report['standalone'], 'Expected standalone runtime'
    progress = Path(report['parent_directory'])/'progress.json'
    deadline = time.monotonic()+30
    while time.monotonic()<deadline:
        if progress.exists() and json.loads(progress.read_text()).get('stage') == 'cancelled': break
        time.sleep(.1)
    else: raise AssertionError('Parent-close worker did not acknowledge cancellation')
    report['parent_close_acknowledged'] = True
    assert hashes == {str(s): hashlib.sha256(s.read_bytes()).hexdigest() for s in sources}
    report['source_hashes_unchanged'] = hashes
    (out/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'Status: {report["checks"]} checks PASS ({a.renderer}); sources unchanged')


if __name__ == '__main__':
    main()

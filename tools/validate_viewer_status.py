"""Native persistent status and existing job lifecycle checks."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import shutil
import time
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tests.g4.fixtures import scene


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--output-dir', type=Path, required=True)
    p.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], default='forward_plus')
    a = p.parse_args()
    out = a.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    source = scene(out / 'scene.ssc')
    sources = [source]
    hashes = {str(s): hashlib.sha256(s.read_bytes()).hexdigest() for s in sources}
    ffmpeg = shutil.which('ffmpeg'); assert ffmpeg
    bad = out/'bad-ffmpeg'; bad.write_text('#!/bin/sh\nexit 1\n'); bad.chmod(0o755)
    (out/'config.json').write_text(json.dumps({'source': str(source), 'ffmpeg': ffmpeg, 'bad_ffmpeg': str(bad)}))
    cmd = [a.godot, '--path', str(ROOT/'viewer'), '--rendering-method', a.renderer,
           '--log-file', str(out/'native.log'), '--audio-driver', 'Dummy', '--resolution', '1440x900', '--script', 'ui/shell/test_viewer_status.gd',
           '--', '--status-output='+str(out)]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    log = result.stdout + result.stderr; (out/'godot.log').write_text(log)
    if result.returncode or 'ERROR:' in log or 'WARNING:' in log:
        raise RuntimeError(f'Status validation failed: {out}/godot.log')
    report = json.loads((out/'report.json').read_text())
    assert not report['failures'], report['failures']
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

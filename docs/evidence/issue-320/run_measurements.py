"""Run the review-only native renderer measurements in an isolated profile."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
from tools.validate_simulation_panel import fixture
p = argparse.ArgumentParser()
p.add_argument('--godot', required=True)
p.add_argument('--project', type=Path, default=ROOT / 'viewer')
p.add_argument('--renderer', default='forward_plus')
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
out = a.output.resolve(); out.mkdir(parents=True, exist_ok=False)
fixture(out / 'mixed.wvz', ['particles', 'volume', 'mesh'])
digest = hashlib.sha256((out / 'mixed.wvz').read_bytes()).hexdigest()
env = dict(os.environ, XDG_DATA_HOME=str(out / 'profile'), XDG_CONFIG_HOME=str(out / 'profile'))
command = [a.godot, '--path', str(a.project), '--script', str(Path(__file__).with_name('measure.gd')), '--rendering-method', a.renderer, '--audio-driver', 'Dummy', '--resolution', '1440x900', '--', str(out)]
r = subprocess.run(command, cwd=out, env=env, capture_output=True, text=True, timeout=180)
log = r.stdout + r.stderr; (out / 'run.txt').write_text(log)
assert not r.returncode and 'ERROR:' not in log and 'WARNING:' not in log, log[-3500:]
report = json.loads((out / 'report.json').read_text())
assert report['committed_fixture']['ok'] and report['committed_fixture']['objects'] >= 3
assert all(report['pin_keyboard'].values())
assert hashlib.sha256((out / 'mixed.wvz').read_bytes()).hexdigest() == digest
(out / 'fixture-sha256.txt').write_text(digest + '\n')
print('Committed mixed fixture, unchanged capture bytes, three keyboard pin toggles:', a.renderer)

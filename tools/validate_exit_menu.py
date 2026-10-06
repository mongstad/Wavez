"""Exercise real File -> Exit and graceful export cancellation in native window modes."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time
import os
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tests.g4.fixtures import scene


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--output-dir', required=True, type=Path)
    p.add_argument('--renderer', required=True, choices=['forward_plus', 'gl_compatibility'])
    p.add_argument('--packaged', action='store_true', help='Run the temporary exit-test executable with its baked entry scene')
    a = p.parse_args(); out = a.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    source = out/'scene.wvz'; scene(source); before = hashlib.sha256(source.read_bytes()).hexdigest()
    runs = []
    for mode in ['windowed', 'maximized', 'fullscreen']:
        for work in ['idle', 'active']:
            for route in (['menu','button','native'] if mode == 'windowed' else ['menu']):
                folder = out/(mode+'-'+work+'-'+route); folder.mkdir()
                result = subprocess.run([a.godot] + ([] if a.packaged else ['--path', str(ROOT/'viewer'), '--script', 'ui/shell/test_exit_menu.gd']) + ['--rendering-method', a.renderer,
                                         '--audio-driver', 'Dummy', '--resolution', '1440x900',
                                         '--', str(folder), str(source), mode, work, route], capture_output=True, text=True, timeout=40)
                log = result.stdout+result.stderr; (folder/'native.log').write_text(log)
                assert result.returncode == 0 and 'ERROR:' not in log and 'WARNING:' not in log, log
                closed = json.loads((folder/'closed.json').read_text()); assert closed['normal_teardown']
                assert json.loads((folder/'before.json').read_text())['exit_enabled']
                if work == 'active':
                    assert closed['cancel_requested']
                    confirmation = json.loads((folder/'confirmation.json').read_text())
                    assert confirmation['safe_default'] and confirmation['cancel_retained_worker'] and confirmation['background_reopened']
                    progress = Path(closed['job_directory'])/'progress.json'; deadline = time.monotonic()+30
                    while time.monotonic() < deadline:
                        if progress.exists() and json.loads(progress.read_text()).get('stage') == 'cancelled': break
                        time.sleep(.1)
                    else: raise AssertionError('Worker did not acknowledge graceful cancellation')
                    renderer_pid = confirmation['renderer_pid']
                    deadline = time.monotonic()+10
                    while time.monotonic() < deadline:
                        try:
                            os.kill(renderer_pid, 0)
                            stat = Path(f'/proc/{renderer_pid}/stat')
                            if stat.exists() and stat.read_text().split(') ',1)[1].startswith('Z '): break
                        except ProcessLookupError: break
                        time.sleep(.1)
                    else: raise AssertionError(f'Export renderer {renderer_pid} remains running after shutdown')
                runs.append(dict(mode=mode, work=work, route=route, exit_code=0, teardown=True, cancelled=work == 'active'))
    assert hashlib.sha256(source.read_bytes()).hexdigest() == before
    report = dict(renderer=a.renderer, packaged=a.packaged, runs=runs, source_hash_unchanged=before, failures=[])
    (out/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'Application exit: {len(runs)} native process cases PASS ({a.renderer}), including {sum(r["cancelled"] for r in runs)} graceful worker cancellations')


if __name__ == '__main__': main()

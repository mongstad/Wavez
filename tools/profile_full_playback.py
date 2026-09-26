"""Complete native playback (fresh and repeat), frame tails, stalls and resource telemetry.

No OS page-cache flush. Captures are read-only; hashing occurs AFTER timing.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--capture', type=Path, required=True)
    p.add_argument('--output-dir', type=Path, required=True)
    p.add_argument('--viewer', type=Path, default=ROOT / 'viewer')
    p.add_argument('--script', type=Path, default=ROOT / 'viewer/layers/profile_full_playback.gd')
    p.add_argument('--renderer', default='forward_plus', choices=['forward_plus', 'gl_compatibility'])
    p.add_argument('--runs', type=int, default=2)
    p.add_argument('--wall-limit', type=float, default=1200)
    a = p.parse_args()
    out = a.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    source = a.capture.resolve(); initial = source.stat()
    cmd = [a.godot, '--path', str(a.viewer.resolve()), '--rendering-method', a.renderer,
           '--audio-driver', 'Dummy', '--resolution', '1280x800', '--script', str(a.script.resolve()),
           '--', str(source), str(out / 'playback.json'), str(a.runs), str(a.wall_limit)]
    metadata = dict(command=cmd, capture=str(source), bytes=initial.st_size,
                    clock_ticks=os.sysconf('SC_CLK_TCK'), page_cache='uncontrolled; no pre-timing integrity read',
                    cpu_count=os.cpu_count(), started=time.time())
    (out / 'run.json').write_text(json.dumps(metadata, indent=2))
    gpu = None
    with (out / 'gpu.csv').open('w') as gpu_log, (out / 'native.log').open('w') as log, (out / 'resources.jsonl').open('w') as resources:
        try:
            gpu = subprocess.Popen(['nvidia-smi', '--query-gpu=timestamp,name,memory.total,memory.used,utilization.gpu,utilization.memory,power.draw', '--format=csv', '-lms', '1000'], stdout=gpu_log, stderr=gpu_log)
        except FileNotFoundError:
            gpu_log.write('nvidia-smi unavailable\n')
        process = subprocess.Popen(cmd, stdout=log, stderr=log)
        started = time.monotonic()
        try:
            while process.poll() is None:
                row = dict(wall_s=time.monotonic()-started)
                for name in ['status', 'stat', 'io']:
                    try:
                        row[name] = Path(f'/proc/{process.pid}/{name}').read_text()
                    except OSError:
                        pass
                resources.write(json.dumps(row)+'\n'); resources.flush()
                if row['wall_s'] > a.runs*a.wall_limit+120:
                    process.terminate(); raise TimeoutError('Native playback timed out')
                time.sleep(.5)
        finally:
            if process.poll() is None:
                process.terminate(); process.wait(timeout=30)
            if gpu is not None:
                gpu.terminate(); gpu.wait(timeout=10)
    final = source.stat()
    with source.open('rb') as f:
        sha = hashlib.file_digest(f, 'sha256').hexdigest()
    stable = (initial.st_size, initial.st_mtime_ns, initial.st_ctime_ns) == (final.st_size, final.st_mtime_ns, final.st_ctime_ns)
    (out / 'source.json').write_text(json.dumps(dict(path=str(source), sha256=sha, metadata_unchanged=stable), indent=2))
    text = (out / 'native.log').read_text()
    if process.returncode or 'ERROR:' in text or not stable:
        raise SystemExit('Native execution/integrity failed; see native.log and source.json')
    result = json.loads((out / 'playback.json').read_text())
    for run in result['runs']:
        print(json.dumps({k: run[k] for k in ['complete', 'preparation_ms', 'wall_s', 'advanced', 'frame_ms', 'commit_ms', 'error']}))
        print('interruptions:', len(run['interruptions']))


if __name__ == '__main__':
    main()

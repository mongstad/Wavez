"""Launch the real Wavez viewer with opt-in manual resize and desktop telemetry.

The owner uses the normal viewer. Write a phase label to output/phase.txt to
mark intervals, and create output/stop when finished. No WVZ1 file is changed.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.profile_parallel_preparation import process_sample


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], default='forward_plus')
    parser.add_argument('--display-driver', choices=['wayland', 'x11'], default='wayland')
    parser.add_argument('--packaged', action='store_true', help='Launch a packaged Wavez binary instead of the source project')
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    (out / 'phase.txt').write_text('empty_idle\n')
    command = [args.godot]
    if not args.packaged:
        command += ['--path', str(ROOT / 'viewer')]
    command += ['--display-driver', args.display_driver,
                '--rendering-method', args.renderer, '--audio-driver', 'Dummy']
    (out / 'command.json').write_text(json.dumps(command, indent=2) + '\n')
    env = os.environ.copy()
    env['WAVEZ_RESIZE_PROFILE_OUTPUT'] = str(out / 'app.jsonl')
    kwin_pids = subprocess.check_output(['pgrep', '-x', 'kwin_wayland'], text=True).split()
    kwin_pid = int(kwin_pids[0]) if kwin_pids else None
    with (out / 'godot.log').open('w') as log, (out / 'system.jsonl').open('w') as system:
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, env=env)
        (out / 'pid').write_text(str(process.pid) + '\n')
        try:
            until = time.monotonic() + 30
            while not (out / 'app.jsonl').exists() or (out / 'app.jsonl').stat().st_size == 0:
                assert process.poll() is None, (out / 'godot.log').read_text()[-3000:]
                assert time.monotonic() < until, 'Viewer diagnostic did not start'
                time.sleep(.1)
            print(f'READY pid={process.pid} output={out}', flush=True)
            stopped_at = None
            while process.poll() is None:
                row = {'unix_seconds': time.time(),
                       'phase': (out / 'phase.txt').read_text().strip()}
                try:
                    row['wavez'] = process_sample(process.pid)
                    if kwin_pid is not None:
                        row['kwin'] = process_sample(kwin_pid)
                    gpu = subprocess.run(['nvidia-smi', '--query-gpu=utilization.gpu,memory.used',
                                          '--format=csv,noheader,nounits'], capture_output=True,
                                         text=True, timeout=2)
                    if gpu.returncode == 0:
                        row['gpu_percent'], row['gpu_mib'] = map(float, gpu.stdout.strip().split(', '))
                except (FileNotFoundError, ProcessLookupError, ValueError, subprocess.TimeoutExpired):
                    pass
                system.write(json.dumps(row) + '\n')
                system.flush()
                if (out / 'stop').exists():
                    if stopped_at is None:
                        stopped_at = time.monotonic()
                    elif time.monotonic() - stopped_at > 10:
                        process.terminate()
                time.sleep(.5)
            print(f'EXIT status={process.returncode} output={out}', flush=True)
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=10)


if __name__ == '__main__':
    main()

"""Measure saturated, bounded mesh preparation; this is not transport timing."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def cpu_snapshot():
    path = Path('/proc/stat')
    if not path.exists():
        return {}
    result = {}
    for line in path.read_text().splitlines():
        if line.startswith('cpu'):
            name, *values = line.split()
            values = list(map(int, values[:8]))
            result[name] = [sum(values), values[3] + values[4]]
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--viewer', type=Path, default=ROOT / 'viewer')
    parser.add_argument('--workers', type=int, choices=range(1, 5), nargs='+', default=[1, 2, 3, 4])
    parser.add_argument('--pairs', type=int, default=1000)
    parser.add_argument('--first', type=int, default=100)
    parser.add_argument('--channels', nargs='+', default=['fixed', 'radius'])
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    for count in args.workers:
        for channel in args.channels:
            folder = out / f'{count}-{channel}'
            folder.mkdir()
            config = dict(capture=str(args.capture.resolve()), output=str(folder / 'report.json'),
                          pairs=args.pairs, first=args.first, channel='' if channel == 'fixed' else channel, timeout=600)
            job = folder / 'job.json'
            job.write_text(json.dumps(config, indent=2))
            env = os.environ.copy()
            env.update(WAVEZ_MESH_WORKERS=str(count), XDG_CONFIG_HOME=str(folder / 'config'), XDG_DATA_HOME=str(folder / 'data'))
            command = [args.godot, '--headless', '--audio-driver', 'Dummy', '--path', str(args.viewer.resolve()),
                       '--script', 'layers/profile_mesh_pipeline.gd', '--', '--mesh-pipeline-job=' + str(job)]
            before = cpu_snapshot()
            began = time.monotonic()
            process_cpu_s = 0.0
            with (folder / 'native.log').open('w') as log:
                process = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT)
                while process.poll() is None:
                    if time.monotonic() - began > 660:
                        process.kill(); process.wait()
                        raise TimeoutError(folder)
                    try:
                        fields = Path(f'/proc/{process.pid}/stat').read_text().rsplit(')', 1)[1].split()
                        process_cpu_s = (int(fields[11]) + int(fields[12])) / os.sysconf('SC_CLK_TCK')
                    except (FileNotFoundError, ProcessLookupError):
                        pass
                    time.sleep(.5)
            after = cpu_snapshot()
            wall = time.monotonic() - began
            telemetry = dict(process_wall_s=wall, process_cpu_s=process_cpu_s,
                             process_mean_core_equivalents=process_cpu_s / wall,
                             host_core_busy_percent={name: 100 * (1 - (after[name][1] - value[1]) / max(1, after[name][0] - value[0]))
                                                     for name, value in before.items()})
            (folder / 'cpu.json').write_text(json.dumps(telemetry, indent=2) + '\n')
            log_text = (folder / 'native.log').read_text()
            if process.returncode or 'ERROR:' in log_text:
                raise RuntimeError(folder)
            result = json.loads((folder / 'report.json').read_text())
            assert result['consumed'] == args.pairs, folder
            print(f'{count} workers, {channel}: {result["pairs_per_second"]:.3f} pairs/s', flush=True)


if __name__ == '__main__':
    main()

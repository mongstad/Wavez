"""Interactive paused-rendering phases with optional Linux/NVIDIA telemetry."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import statistics
import subprocess
import time
from profile_parallel_preparation import ROOT, SceneReader, identity, process_sample


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--viewer-dir', type=Path, default=ROOT/'viewer')
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], default='forward_plus')
    parser.add_argument('--resolution', default='1440x900')
    parser.add_argument('--seconds', type=float, default=60)
    parser.add_argument('--actions', action='store_true')
    parser.add_argument('--full-playback', action='store_true')
    parser.add_argument('--hash-source', action='store_true', help='Verify whole-file SHA-256 before and after the native run; may take minutes')
    parser.add_argument('--disable-vsync', action='store_true', help='Diagnostic uncontrolled-rate comparison; not the production default')
    parser.add_argument('--orbit', action='store_true', help='Keep the camera moving during paused/playback phases; also measure a stationary phase')
    parser.add_argument('--owner-settings', action='store_true', help='Production field psi_imag/magnitude opacity and all particles colored by color_value')
    parser.add_argument('--zoom', type=float, default=1, help='Multiplier of the normal Frame scene camera distance')
    args = parser.parse_args()
    out = args.output_dir.resolve();out.mkdir(parents=True, exist_ok=False)
    source = args.capture.resolve();before = identity(source)
    source_hash = None
    if args.hash_source:
        print('Hashing complete source before native run', flush=True)
        with source.open('rb') as stream:source_hash = hashlib.file_digest(stream, 'sha256').hexdigest()
    command = [args.godot, '--path', str(args.viewer_dir.resolve()), '--audio-driver', 'Dummy',
               '--rendering-method', args.renderer, '--resolution', args.resolution]
    if args.disable_vsync:command.append('--disable-vsync')
    command += ['--script', str(ROOT/'viewer/layers/profile_paused_rendering.gd'), '--', str(source),
               str(out/'result.json'), str(args.seconds), str(args.actions).lower(), str(args.full_playback).lower(),
               str(args.orbit).lower(), str(args.owner_settings).lower(), str(args.zoom)]
    (out/'command.json').write_text(json.dumps(command, indent=2)+'\n')
    rows = [];started = time.monotonic();phase = 'open';position = 0
    gpu = shutil.which('nvidia-smi')
    with (out/'native.log').open('w') as log:
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
        try:
            while process.poll() is None:
                if time.monotonic()-started > 2400:raise TimeoutError('Native paused profile')
                with (out/'native.log').open() as progress:
                    progress.seek(position)
                    for line in progress:
                        if line.startswith('PHASE '):phase = line.strip()[6:];print(line.strip(), flush=True)
                    position = progress.tell()
                row = dict(seconds=time.monotonic()-started, phase=phase)
                try:row.update(process_sample(process.pid))
                except (FileNotFoundError, ProcessLookupError):pass
                if gpu:
                    reading = subprocess.run([gpu, '--query-gpu=utilization.gpu,power.draw,clocks.gr,clocks.mem,memory.used',
                                              '--format=csv,noheader,nounits'], capture_output=True, text=True, timeout=5)
                    try:
                        row.update(zip(['gpu_percent','power_w','graphics_mhz','memory_mhz','gpu_mib'],
                                       map(float, reading.stdout.splitlines()[0].split(', '))))
                    except (ValueError, IndexError):row['gpu_error'] = reading.stderr.strip()
                rows.append(row)
                time.sleep(.5)
        finally:
            if process.poll() is None:process.kill();process.wait()
            (out/'telemetry.json').write_text(json.dumps(rows)+'\n')
    log = (out/'native.log').read_text()
    assert process.returncode == 0 and 'ERROR:' not in log, log[-6000:]
    assert 'PAUSED RENDERING:' in log, 'Viewer ended before completing the profile; discard this run.'
    report = json.loads((out/'result.json').read_text());assert report.get('complete') and not report['failures']
    with SceneReader(source, cache_bytes=0) as reader:
        for row in report['scientific']:
            sample = reader.read_sample(row['object'], row['index'])
            assert row['time'] == reader.samples[row['object']][row['index']]['time']
            assert row['hashes'] == {key:hashlib.sha256(value.tobytes()).hexdigest() for key,value in sample.items()}
    assert identity(source) == before
    if source_hash is not None:
        print('Hashing complete source after native run', flush=True)
        with source.open('rb') as stream:assert hashlib.file_digest(stream, 'sha256').hexdigest() == source_hash
    phases = {}
    for name, data in report['phases'].items():
        samples = [row for row in rows if row['phase'] == name]
        # Drop the first two seconds of GPU samples to separate driver sampling windows.
        stable = [row for row in samples if row['seconds'] >= samples[0]['seconds']+2] if samples else []
        metrics = {key:statistics.mean(row[key] for row in stable if key in row)
                   for key in ('gpu_percent','power_w','graphics_mhz','memory_mhz') if any(key in row for row in stable)}
        if samples and all('cpu_seconds' in row for row in (samples[0],samples[-1])) and len(samples)>1:
            metrics['cpu_percent_one_core'] = (samples[-1]['cpu_seconds']-samples[0]['cpu_seconds'])/(samples[-1]['seconds']-samples[0]['seconds'])*100
        metrics['peak_rss'] = max((row.get('VmRSS',0) for row in samples), default=0)
        metrics['swap'] = max((row.get('VmSwap',0) for row in samples), default=0)
        phases[name] = {key:value for key,value in data.items() if key not in ('timeline','profile','committed')}
        phases[name].update(metrics)
        phases[name]['profile'] = data['profile']
    summary = dict(settings=report['settings'], phases=phases, checks=report['checks'], failures=report['failures'],
                   source_stat=before, unchanged_stat=True, strict_selected_oracles=len(report['scientific']),
                   source_sha256=source_hash, source_sha256_unchanged=source_hash is not None,
                   telemetry_scope='GPU is whole-device including desktop, not process-attributed. Fresh process; uncontrolled desktop and OS cache. Selected strict field hashes and stat invariance; optional whole-file SHA-256 is reported separately. This is not an all-record strict payload verification scan.')
    (out/'summary.json').write_text(json.dumps(summary, indent=2)+'\n')
    print(json.dumps({name:{key:value for key,value in data.items() if key!='profile'} for name,data in phases.items()}, indent=2))


if __name__ == '__main__':main()

"""Fresh-process Auto/fixed comparison, startup gate and controller telemetry."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
from profile_parallel_preparation import ROOT, SceneReader, identity, process_sample


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--capture', type=Path, required=True)
    p.add_argument('--output-dir', type=Path, required=True)
    p.add_argument('--viewer-dir', type=Path, default=ROOT/'viewer', help='Optional immutable baseline source snapshot with the same profiling script')
    p.add_argument('--workers', choices=['auto', '1', '2', '3', '4'], default='auto')
    p.add_argument('--actions', action='store_true', help='Exercise seeks, channels, pressure, reverse, loop and reopen')
    p.add_argument('--speed', type=int, choices=[1, 2, 4], default=1)
    p.add_argument('--seconds', type=float, default=0, help='Zero plays the full capture')
    p.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility', 'headless'], default='forward_plus')
    a = p.parse_args();out = a.output_dir.resolve();out.mkdir(parents=True, exist_ok=False)
    source = a.capture.resolve();before = identity(source)
    cmd = [a.godot, '--path', str(a.viewer_dir.resolve()), '--audio-driver', 'Dummy']
    cmd += ['--headless'] if a.renderer == 'headless' else ['--rendering-method', a.renderer, '--resolution', '960x640']
    cmd += ['--script', 'layers/profile_dynamic_actions.gd' if a.actions else 'layers/profile_dynamic_preparation.gd', '--', str(source), str(out/'result.json'), str(a.speed), str(a.seconds)]
    telemetry = [];started = time.monotonic()
    with (out/'native.log').open('w') as log:
        process = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT, env=dict(os.environ, WAVEZ_FIELD_WORKERS=a.workers))
        while process.poll() is None:
            if time.monotonic()-started > 1000:
                process.kill();process.wait();raise TimeoutError('Native profile')
            try:telemetry.append(dict(seconds=time.monotonic()-started, **process_sample(process.pid)))
            except (FileNotFoundError, ProcessLookupError):pass
            time.sleep(.1)
    (out/'telemetry.json').write_text(json.dumps(telemetry)+'\n')
    log = (out/'native.log').read_text()
    assert process.returncode == 0 and 'ERROR:' not in log, log[-6000:]
    report = json.loads((out/'result.json').read_text());assert not report['failures']
    with SceneReader(source, cache_bytes=0) as reader:
        for row in report['scientific']:
            sample = reader.read_sample('field', row['index'])
            assert row['time'] == reader.samples['field'][row['index']]['time']
            assert row['hashes'] == {k:hashlib.sha256(v.tobytes()).hexdigest() for k,v in sample.items()}
    assert identity(source) == before
    def timing(values):
        s = sorted(values)
        if not s:return None
        return dict(count=len(s), **{k:s[min(len(s)-1, int(len(s)*q))] for k,q in [('p50',.5),('p95',.95),('p99',.99),('max',1)]}, over_50_ms=sum(v>50 for v in s), over_100_ms=sum(v>100 for v in s))
    summary = dict(actions=report['actions'], close_ms=report['close_ms'], checks=report['checks']) if a.actions else {k:report[k] for k in ['mode','speed','open_seconds','ready_seconds','startup','wall_seconds','committed_seconds','complete','field_waits','particle_waits','field_wait_seconds','particle_wait_seconds','checks']}
    summary.update(draw_ms=timing(report['draws']) if 'draws' in report else None, callback_ms=timing(report['callbacks']) if 'callbacks' in report else None,
                   peak_rss=max(r.get('VmHWM',0) for r in telemetry), process_swap=max(r.get('VmSwap',0) for r in telemetry),
                   cpu_percent_one_core=(telemetry[-1]['cpu_seconds']-telemetry[0]['cpu_seconds'])/(telemetry[-1]['seconds']-telemetry[0]['seconds'])*100,
                   presented=len(report.get('presented',[])), events=report['final']['concurrency']['events'],
                   source_stat=before, unchanged_stat=True, strict_selected_oracles=len(report['scientific']), cache_state='Uncontrolled OS cache; fresh native process')
    if not a.actions:
        summary.update(initial_runway=report['initial_runway'], initial_policy=report['initial_policy'],
                       cpu_runway_holds=report['cpu_runway_holds'], cpu_runway_seconds=report['cpu_runway_seconds'],
                       playback_draw_ms=timing(report['playback_draws']), advancing_draw_ms=timing(report['advancing_draws']),
                       playback_callback_ms=timing(report['playback_callbacks']), field_presentation_ms=timing(report['field_presentations_ms']),
                       playback_observations=[r for r in report['timeline'] if r['started']],
                       final_cache={k:report['final']['cache'][k] for k in ['bytes','limit','completed','evictions','cancelled','source_reuses','pressure_events']})
    (out/'summary.json').write_text(json.dumps(summary, indent=2)+'\n');print(json.dumps(summary, indent=2))


if __name__ == '__main__':main()

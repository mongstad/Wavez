"""Read-only mixed-scene replay: fill admitted caches while paused, then play at 2x."""
import argparse
import json
import math
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneReader


def identity(path):
    stat = path.stat()
    return dict(bytes=stat.st_size, mtime_ns=stat.st_mtime_ns, ctime_ns=stat.st_ctime_ns)


def summarize(rows):
    start = next((row for row in rows if row.get('event') == 'cache_filled_before_play'), None)
    playing = [row for row in rows if start and row['wall'] >= start['wall'] and row['playing']]
    holds = []
    for row in playing:
        if not row['reason'] or row['time'] <= 0:
            continue
        if not holds or holds[-1]['time'] != row['time']:
            holds.append(dict(time=row['time'], first_observation=row['wall'], last_observation=row['wall'],
                              field_lead_seconds=row['field']['demand']['ahead_seconds'],
                              particle_buffering=row['particle']['buffering'],
                              particle_admitted=row['particle']['admitted'],
                              particle_failures=row['particle']['state']['failures'],
                              field_waiting=row['field']['session_waiting'],
                              field_producer=row['field'].get('concurrency', {}).get('producer'),
                              consumer=row['field']['demand']['consumer'], reason=row['reason']))
        else:
            holds[-1]['last_observation'] = row['wall']
    return dict(play_start=start, final=rows[-1], holds=holds,
                cache_peak_rss=max(row['memory']['process_rss'] for row in rows),
                process_peak_swap=max(row['memory']['process_swap'] for row in rows),
                particle_budget_min=min(row['particle']['decoded_limit']+row['particle']['prepared_limit'] for row in playing) if playing else None,
                particle_budget_max=max(row['particle']['decoded_limit']+row['particle']['prepared_limit'] for row in playing) if playing else None,
                particle_failures=[row['particle']['state']['failures'] for row in rows if row['particle']['state']['failures']],
                errors=[row['error'] or row['field']['error'] for row in rows if row['error'] or row['field']['error']])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--viewer', type=Path, default=ROOT/'viewer')
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], default='forward_plus')
    parser.add_argument('--speed', type=float, default=2.)
    parser.add_argument('--wall-limit', type=float, default=240.)
    args = parser.parse_args()
    if not all(math.isfinite(value) and value > 0 for value in [args.speed, args.wall_limit]):
        parser.error('speed and wall limit must be finite and positive')
    out = args.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    source = args.capture.resolve(); before = identity(source)
    with SceneReader(source, cache_bytes=0) as reader:
        kinds = {obj['kind'] for obj in reader.objects.values()}
        if not {'particles', 'volume'} <= kinds:
            parser.error('capture must contain both particles and fields')
        end_time = max(rows[-1]['time'] for rows in reader.samples.values() if rows)
    command = [args.godot, '--path', str(args.viewer.resolve()), '--rendering-method', args.renderer,
               '--audio-driver', 'Dummy', '--resolution', '960x640', '--script',
               str(ROOT/'viewer/layers/profile_mixed_playback.gd'), '--', str(source),
               str(out/'trace.jsonl'), str(args.wall_limit), '-1', str(args.speed)]
    with (out/'native.log').open('w') as log:
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=args.wall_limit+60,
                                env=dict(os.environ, XDG_DATA_HOME=str(out/'data'), XDG_CONFIG_HOME=str(out/'config')))
    rows = [json.loads(line) for line in (out/'trace.jsonl').read_text().splitlines()]
    summary = summarize(rows)
    summary.update(source=str(source), source_identity=before, source_metadata_unchanged=identity(source)==before,
                   speed=args.speed, renderer=args.renderer, playhead_reached_end=summary['final']['time'] >= end_time,
                   completion_criterion='Requested playhead reached end; committed presentation may lag one display step.',
                   sampling='One-second observations; hold durations are approximate. No simulated RAM reservation.')
    (out/'summary.json').write_text(json.dumps(summary, indent=2)+'\n')
    print(json.dumps({key:summary[key] for key in ['playhead_reached_end','speed','renderer','source_metadata_unchanged','particle_budget_min','particle_budget_max','cache_peak_rss','process_peak_swap','holds','errors']}, indent=2))
    if result.returncode or 'ERROR:' in (out/'native.log').read_text() or not summary['playhead_reached_end'] or summary['errors'] or summary['particle_failures'] or not summary['source_metadata_unchanged']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()

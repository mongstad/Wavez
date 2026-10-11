"""Read-only paused fill, sustained 1x and optional scrub comparison on Forward+.

Frame wall times include scheduling/rendering/instrumentation; they are not GPU
hardware timings. Hold transitions are observed on each real playback tick.
"""
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


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--capture', type=Path, required=True)
    p.add_argument('--output-dir', type=Path, required=True)
    p.add_argument('--viewer', type=Path, default=ROOT/'viewer')
    p.add_argument('--wall-limit', type=float, default=240.)
    p.add_argument('--scrub', action='store_true')
    p.add_argument('--play-seconds',type=float,default=0.,help='Bounded source-time traversal; zero requires the whole recording')
    a = p.parse_args()
    if not math.isfinite(a.wall_limit) or a.wall_limit <= 0 or not math.isfinite(a.play_seconds) or a.play_seconds < 0:p.error("wall-limit must be positive and play-seconds nonnegative")
    out = a.output_dir.resolve();out.mkdir(parents=True, exist_ok=False)
    source = a.capture.resolve();before = identity(source)
    with SceneReader(source, cache_bytes=0) as r:
        metadata = dict(objects=list(r.objects.values()), samples={key:len(value) for key,value in r.samples.items()})
    cmd = [a.godot, '--path', str(a.viewer.resolve()), '--rendering-method', 'forward_plus', '--audio-driver', 'Dummy', '--resolution', '960x640', '--script', str(ROOT/'viewer/layers/profile_particle_runway.gd'), '--', str(source), str(out/'trace.jsonl'), str(a.wall_limit)]
    cmd += ['--scrub' if a.scrub else '--no-scrub',str(a.play_seconds)]
    with (out/'native.log').open('w') as log:
        result = subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT, timeout=a.wall_limit+180, env=dict(os.environ, XDG_DATA_HOME=str(out/'data'), XDG_CONFIG_HOME=str(out/'config')))
    rows = [json.loads(line) for line in (out/'trace.jsonl').read_text().splitlines()]
    fill = next((r for r in rows if r.get('event') == 'paused_filled'), None)
    final = next(r for r in rows if r.get('event') == 'playback_final')
    metrics = rows[-1]
    playback = [r for r in rows if 'memory' in r and fill and fill['wall'] <= r['wall'] <= final['wall']]
    scrub_failures = [r['target_time'] for r in metrics['scrubs'] if not r['accepted'] or r.get('committed') is None or not math.isclose(r['committed'],r['target_time'],abs_tol=1e-5)]
    worker_failures = [r['particle']['state']['failures'] for r in rows if 'particle' in r and r['particle']['state']['failures']]
    summary = dict(scrub_failures=scrub_failures, worker_failures=worker_failures, source=str(source), source_identity=before, source_metadata_unchanged=before==identity(source), metadata=metadata, viewer=str(a.viewer.resolve()), exit_code=result.returncode, paused=fill, final=final, metrics=metrics,
                   peak_rss=max(r['memory']['process_rss'] for r in rows if 'memory' in r), peak_swap=max(r['memory']['process_swap'] for r in rows if 'memory' in r),
                   ahead={key:dict(min=min(r[key] for r in playback), max=max(r[key] for r in playback)) for key in ['particle_ahead','field_ahead','scene_ahead']} if playback else {},
                   errors=[r.get('error') or r.get('field',{}).get('error') for r in rows if r.get('error') or r.get('field',{}).get('error')],
                   measurement='1x, real RAM, sequential viewer. Per-tick hold transitions. Frame wall includes rendering/scheduling and instrumentation; no GPU hardware timing. Source stat identity only, not full production-file hash.')
    (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps({k:summary[k] for k in ['exit_code','source_metadata_unchanged','peak_rss','peak_swap','ahead','errors']},indent=2))
    print('Reached recording end:', final['reached_end'], 'Criterion met:', final.get('criterion_met',final['reached_end']), 'Holds:', metrics['holds'])
    if result.returncode or 'ERROR:' in (out/'native.log').read_text() or not final.get('criterion_met',final['reached_end']) or summary['errors'] or scrub_failures or worker_failures or not summary['source_metadata_unchanged']:raise SystemExit(1)


if __name__ == '__main__':main()

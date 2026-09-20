"""Measure SIMSCP3 main-thread stalls without changing playback/sampling policies.

Run a short real-renderer profile, or analyze a retained profile.json. Outputs go
into a new directory; captures are read-only. No per-frame log writes occur.
"""
import argparse
import csv
import hashlib
import json
import math
import statistics
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ['viewer/main.gd', 'viewer/layers/scene_layers.gd',
           'viewer/layers/scene_reader.gd', 'viewer/scene/playback_profile.gd',
           'viewer/data/source_stamp.gd', 'viewer/layers/profile_scene_stalls.gd',
           'tools/profile_scene_stalls.py']


def median(values):
    return statistics.median(values) if values else None


def analyze(path, threshold=50.0):
    data = json.loads(path.read_text())
    summaries, stalls, stages = [], [], []
    for case in data['cases']:
        name = case['config']['name']
        rows = case['callbacks']
        slow = [r for r in rows if r['duration_ms'] >= threshold]
        trace = case.get('trace', {})
        events = trace.get('events', [])
        polls = [r for r in events if r['name'] == 'g3_tail_poll']
        pair_known = all('particle_pair_before' in r for r in rows)
        changes = [r for r in rows if r.get('particle_pair_before') != r.get('particle_pair_after')]
        intervals = [(b['wall_start_us']-a['wall_start_us'])/1e6 for a,b in zip(slow,slow[1:])]
        elapsed = (case['wall_end_us']-case['wall_start_us'])/1e6
        summary = dict(case=name,
                       playing=case['config'].get('playing', True),
                       configured_rate=case['config'].get('rate',1),
                       seconds=elapsed, callbacks=len(rows), stall_threshold_ms=threshold,
                       stalls=len(slow), pair_changes=len(changes) if pair_known else None,
                       stalls_with_pair_change=sum(r in changes for r in slow) if pair_known else None,
                       stalls_with_tail_poll=sum(r['tail_due'] for r in slow),
                       stall_median_ms=median([r['duration_ms'] for r in slow]),
                       stall_max_ms=max([r['duration_ms'] for r in slow],default=0),
                       stall_interval_median_seconds=median(intervals),
                       poll_count=len(polls),poll_max_ms=max([r['duration_ms'] for r in polls],default=0),
                       reload_events=sum(e['name']=='g3_reload_source' for e in events),
                       trace_dropped=trace.get('dropped',0),
                       source_units_per_wall_second=(rows[-1]['source_time_after']-rows[0]['source_time_before'])/elapsed if rows else 0,
                       engine_delta_sum=sum(r['engine_delta'] for r in rows))
        summaries.append(summary)
        for r in slow:
            stalls.append(dict(case=name,wall_seconds=(r['wall_start_us']-case['wall_start_us'])/1e6,**r))
        for key,value in case['stages'].items():
            stages.append(dict(case=name,stage=key,**value))
    output = dict(capture=data['capture'],threshold_ms=threshold,source_size=data.get('source_size'),
                  hidden_scientific_rendering=data['hidden_scientific_rendering'],
                  backend=data['backend'],device=data['device'],cases=summaries,
                  interpretation_scope='Callback durations are inclusive; nested stage totals must not be added. A coincident poll and stall is not causal attribution; inspect nested poll spans. First fractional sample can change the pair without changing the lower union index.')
    (path.parent/'analysis.json').write_text(json.dumps(output,indent=2)+'\n')
    for filename,table in [('cases.csv',summaries),('stalls.csv',stalls),('stages.csv',stages)]:
        with (path.parent/filename).open('w',newline='') as stream:
            if table:
                writer=csv.DictWriter(stream,fieldnames=list(table[0]));writer.writeheader();writer.writerows(table)
    return output


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--analyze',type=Path,help='Analyze an existing profile instead of running Godot')
    parser.add_argument('--capture',type=Path)
    parser.add_argument('--godot',type=Path)
    parser.add_argument('--output-dir',type=Path)
    parser.add_argument('--seconds',type=float,default=8)
    parser.add_argument('--start-time',type=float,default=16)
    parser.add_argument('--renderer',choices=['gl_compatibility','forward_plus'],default='gl_compatibility')
    parser.add_argument('--no-trace',action='store_true')
    parser.add_argument('--threshold-ms',type=float,default=50)
    args=parser.parse_args()
    if not math.isfinite(args.threshold_ms) or args.threshold_ms<=0:parser.error('threshold must be positive')
    if args.analyze:
        print(json.dumps(analyze(args.analyze.resolve(),args.threshold_ms),indent=2));return
    if not all([args.capture,args.godot,args.output_dir]):parser.error('capture, godot and output-dir required')
    if not math.isfinite(args.seconds) or not 0.5<=args.seconds<=20:parser.error('seconds must be 0.5..20 per case')
    if not math.isfinite(args.start_time):parser.error('start-time must be finite')
    sys.path.insert(0,str(ROOT))
    from simscope_export import SceneReader
    source=args.capture.resolve();stamp=source.stat()
    with SceneReader(source,cache_bytes=0) as reader:
        if not reader.times or args.start_time<reader.times[0] or args.start_time+2*args.seconds>reader.times[-1]:
            parser.error('Choose a start time/duration with room for the fastest case through start+2*seconds')
    out=args.output_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    cases=[dict(name='paused',playing=False),dict(name='physical_slow',rate=.25),
           dict(name='physical_fast',rate=2),
           dict(name='paused_inspector_hidden',playing=False,inspector=False),
           dict(name='physical_slow_shifted_poll',rate=.25,tail_phase=.5)]
    for case in cases:case.update(seconds=args.seconds,start_time=args.start_time)
    job=dict(capture=str(source),output=str(out/'profile.json'),cases=cases,trace=not args.no_trace)
    (out/'job.json').write_text(json.dumps(job,indent=2)+'\n')
    hashes={name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in SOURCES}
    (out/'source-sha256.json').write_text(json.dumps(hashes,indent=2)+'\n')
    command=[str(args.godot.resolve()),'--path',str(ROOT/'viewer'),'--resolution','960x640',
             '--audio-driver','Dummy','--rendering-method',args.renderer,'--disable-vsync','--max-fps','120',
             '--log-file',str(out/'godot.log'),'--script','layers/profile_scene_stalls.gd','--',
             '--stall-job='+str(out/'job.json')]
    with (out/'stdout.log').open('w') as stream:
        result=subprocess.run(command,stdout=stream,stderr=subprocess.STDOUT,timeout=180)
    log=(out/'stdout.log').read_text()
    if result.returncode or 'ERROR:' in log:raise RuntimeError('Godot profile failed; inspect '+str(out/'stdout.log'))
    final=source.stat()
    unchanged=(stamp.st_dev,stamp.st_ino,stamp.st_size,stamp.st_mtime_ns,stamp.st_ctime_ns)==(final.st_dev,final.st_ino,final.st_size,final.st_mtime_ns,final.st_ctime_ns)
    (out/'source-preservation.json').write_text(json.dumps(dict(path=str(source),unchanged=unchanged,size=stamp.st_size),indent=2)+'\n')
    if not unchanged:raise RuntimeError('Capture changed during measurement; results require review')
    report=analyze(out/'profile.json',args.threshold_ms)
    if any(c['trace_dropped'] for c in report['cases']):raise RuntimeError('Trace truncated; use a shorter case')
    print(json.dumps(report,indent=2))

if __name__=='__main__':main()

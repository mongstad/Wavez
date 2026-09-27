"""Matched read-only preparation/playback profile; independent strict Python oracles."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from simscope_export import SceneReader


def identity(path):
    st = path.stat()
    return [st.st_dev, st.st_ino, st.st_size, st.st_mtime_ns, st.st_ctime_ns]


def process_sample(pid):
    # Linux telemetry. CPU percent uses 100% for one fully occupied logical core.
    status = {}
    for line in Path(f'/proc/{pid}/status').read_text().splitlines():
        key, _, value = line.partition(':')
        if key in ('VmRSS', 'VmHWM', 'VmSwap'):status[key] = int(value.split()[0])*1024
    fields = Path(f'/proc/{pid}/stat').read_text().rsplit(')', 1)[1].split()
    status['cpu_seconds'] = (int(fields[11])+int(fields[12]))/os.sysconf('SC_CLK_TCK')
    return status


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--capture', type=Path, required=True)
    p.add_argument('--output-dir', type=Path, required=True)
    p.add_argument('--viewer-dir', type=Path, default=ROOT/'viewer', help='Optional immutable baseline source snapshot')
    p.add_argument('--renderer', choices=['headless', 'forward_plus', 'gl_compatibility'], default='forward_plus')
    p.add_argument('--samples', type=int, default=64)
    p.add_argument('--first', type=int, default=100)
    p.add_argument('--cache-mib', type=int, default=2048)
    p.add_argument('--play-seconds', type=float, default=10)
    a = p.parse_args();out = a.output_dir.resolve();out.mkdir(parents=True, exist_ok=False)
    source = a.capture.resolve();before = identity(source)
    command = [a.godot, '--path', str(a.viewer_dir.resolve()), '--audio-driver', 'Dummy']
    command += ['--headless'] if a.renderer == 'headless' else ['--rendering-method', a.renderer, '--resolution', '960x640']
    command += ['--script', 'layers/profile_payload_integrity.gd', '--', str(source), str(out/'result.json'), str(a.samples), str(a.first), str(a.cache_mib), str(a.play_seconds)]
    telemetry = [];started = time.monotonic();phase = 'startup';position = 0
    with (out/'native.log').open('w') as log:
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
        while process.poll() is None:
            if time.monotonic()-started > 600:process.kill();raise TimeoutError('Native benchmark')
            with (out/'native.log').open() as progress:
                progress.seek(position)
                for line in progress:
                    if line.startswith('PHASE '):phase = line.strip()[6:]
                position = progress.tell()
            try:telemetry.append(dict(seconds=time.monotonic()-started, phase=phase, **process_sample(process.pid)))
            except (FileNotFoundError, ProcessLookupError):pass
            time.sleep(.1)
    (out/'telemetry.json').write_text(json.dumps(telemetry, indent=2)+'\n')
    assert process.returncode == 0 and 'ERROR:' not in (out/'native.log').read_text(), (out/'native.log').read_text()
    report = json.loads((out/'result.json').read_text());assert not report['failures']
    with SceneReader(source, cache_bytes=0) as reader:
        for row in report['scientific']:
            sample = reader.read_sample('field', row['index'])
            assert row['time'] == reader.samples['field'][row['index']]['time']
            assert row['hashes'] == {k:hashlib.sha256(v.tobytes()).hexdigest() for k,v in sample.items()}
    assert identity(source) == before
    phases = {}
    for name in sorted({r['phase'] for r in telemetry}):
        rows = [r for r in telemetry if r['phase'] == name]
        wall = rows[-1]['seconds']-rows[0]['seconds'];cpu = rows[-1]['cpu_seconds']-rows[0]['cpu_seconds']
        phases[name] = dict(observed_wall_seconds=wall, cpu_seconds=cpu, cpu_percent_one_core=cpu/wall*100 if wall else None,
                           peak_rss=max(r.get('VmRSS',0) for r in rows), process_swap=max(r.get('VmSwap',0) for r in rows))
    summary = dict(path=str(source), source_stat=before, unchanged_stat=True, independent_oracles=True,
                   phases=phases, peak_rss=max(r.get('VmHWM',0) for r in telemetry), process_swap=max(r.get('VmSwap',0) for r in telemetry),
                   cache_state='Uncontrolled OS cache; no privileged cache drop. Fresh process each run.',
                   scope='Selected full-channel Python checksum oracles and stat invariance, not a whole-file digest.')
    (out/'summary.json').write_text(json.dumps(summary, indent=2)+'\n')
    print(json.dumps(dict(checks=report['checks'], sequential=report['sequential']|{'rows':None}, telemetry=summary), indent=2))


if __name__ == '__main__':main()

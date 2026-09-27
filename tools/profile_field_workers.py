"""Read-only 1–4 worker CPU scaling experiment on an identical field window."""
import argparse
import json
from pathlib import Path
import subprocess
import time

from profile_payload_integrity import ROOT, identity, process_sample


def cores():
    return {line.split()[0]: [int(x) for x in line.split()[1:9]]
            for line in Path('/proc/stat').read_text().splitlines()
            if line.startswith('cpu') and line.split()[0] != 'cpu'}


def run(command, out):
    telemetry = []; phase = 'startup'; position = 0; start = time.monotonic()
    with (out/'native.log').open('w') as log:
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
        while process.poll() is None:
            if time.monotonic()-start > 600:
                process.kill(); process.wait(); raise TimeoutError('Native scaling probe')
            with (out/'native.log').open() as progress:
                progress.seek(position)
                for line in progress:
                    if line.startswith('PHASE '): phase = line.strip()[6:]
                position = progress.tell()
            try:
                telemetry.append(dict(seconds=time.monotonic()-start, phase=phase,
                                      cores=cores(), **process_sample(process.pid)))
            except (FileNotFoundError, ProcessLookupError): pass
            time.sleep(.05)
    (out/'telemetry.json').write_text(json.dumps(telemetry)+'\n')
    assert process.returncode == 0 and 'ERROR:' not in (out/'native.log').read_text(), (out/'native.log').read_text()
    rows = [r for r in telemetry if r['phase'] == 'prepare']
    wall = rows[-1]['seconds']-rows[0]['seconds']
    cpu = rows[-1]['cpu_seconds']-rows[0]['cpu_seconds']
    utilization = {}
    for core, first in rows[0]['cores'].items():
        delta = [b-a for a,b in zip(first, rows[-1]['cores'][core])]
        utilization[core] = 100*(sum(delta)-delta[3]-delta[4])/max(1,sum(delta))
    return dict(cpu_percent_one_core=100*cpu/wall, process_swap=max(r.get('VmSwap',0) for r in telemetry),
                peak_rss=max(r.get('VmHWM',0) for r in telemetry),
                observed_prepare_rss_peak=max(r.get('VmRSS',0) for r in rows),
                per_core_system_busy_percent=utilization,
                per_core_scope='System-wide utilization; not process attribution',
                telemetry_interval_seconds=.05)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--capture', type=Path, required=True)
    p.add_argument('--output-dir', type=Path, required=True)
    p.add_argument('--workers', type=int, nargs='+', default=[1,2,3,4])
    p.add_argument('--first', type=int, default=100)
    p.add_argument('--samples', type=int, default=128)
    a = p.parse_args(); out = a.output_dir.resolve(); out.mkdir(parents=True,exist_ok=False)
    source = a.capture.resolve(); before = identity(source); results = []
    for index, workers in enumerate(a.workers):
        destination = out/f'{index}-{workers}'; destination.mkdir()
        command = [a.godot, '--headless', '--path', str(ROOT/'viewer'), '--audio-driver','Dummy',
                   '--script','layers/profile_field_workers.gd','--',str(source),str(destination/'result.json'),
                   str(workers),str(a.first),str(a.samples)]
        telemetry = run(command, destination)
        report = json.loads((destination/'result.json').read_text()); assert not report['failures']
        report.pop('rows'); report.update(telemetry); results.append(report)
        assert identity(source) == before
        print(json.dumps(report),flush=True)
    (out/'summary.json').write_text(json.dumps(dict(results=results,source_stat=before,unchanged_stat=True,
        cache_state='Uncontrolled OS file cache; fresh process per configuration; repeat in reverse order.'),indent=2)+'\n')


if __name__ == '__main__': main()

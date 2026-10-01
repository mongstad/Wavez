"""Cross-language metadata capacity, integrity and >32 MiB export regression."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneReader, MetadataCapacityError
from wavez_export.analysis import SourceSnapshot, Context, AnalysisError
from tests.metadata_fixture import generate
from tools.verify_ssc import verify


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    path = out/'long.ssc'
    report = generate(path)
    (out/'fixture.json').write_text(json.dumps(report, indent=2))
    before = hashlib.sha256(path.read_bytes()).hexdigest()
    assert verify(path) == report['records']
    with SceneReader(path, cache_bytes=0) as reader:
        report['python_metadata_used'] = reader.metadata_budget.used
        report['python_metadata_peak'] = reader.metadata_budget.peak
    context = Context()
    with SourceSnapshot(path, context=context) as source:
        assert source.record_count == report['records']
        with source.read_sample('field', report['records']-1) as sample:
            assert hashlib.sha256(sample.arrays['field_63'].tobytes()).hexdigest() == report['oracle'][-1]['sha256']
    assert context.used == 0
    report['analysis_peak'] = context.peak
    for kind in ('descriptor', 'commit', 'payload'):
        corrupted = out/(kind+'.ssc')
        shutil.copyfile(path, corrupted)
        with corrupted.open('r+b') as f:
            offset = report['last'][kind]+(16 if kind == 'commit' else 0)
            f.seek(offset);value = f.read(1);f.seek(offset);f.write(bytes([value[0]^1]))
        try:
            with SceneReader(corrupted, cache_bytes=0) as reader:
                reader.read_sample('field', report['records']-1)
        except ValueError as exc:
            assert 'checksum' in str(exc).lower(), str(exc)
        else:raise AssertionError(kind+' corruption was accepted')
    oversized = out/'oversized.ssc'
    shutil.copyfile(path, oversized)
    with oversized.open('r+b') as f:
        f.seek(report['last']['header']+4);f.write(struct.pack('<I', 4*1024**2+1))
    try:SceneReader(oversized)
    except ValueError as exc:assert 'allocation limit' in str(exc)
    else:raise AssertionError('Oversized descriptor accepted')
    for limit in (128, 1024**2):
        try:SceneReader(path, metadata_bytes=limit)
        except MetadataCapacityError:pass
        else:raise AssertionError('Reader exceeded metadata budget')
        context = Context()
        try:SourceSnapshot(path, context=context, metadata_bytes=limit)
        except AnalysisError as exc:assert exc.code == 'memory_limit'
        else:raise AssertionError('Analysis exceeded metadata budget')
        assert context.used == 0
    command = [args.godot, '--headless', '--path', str(ROOT/'viewer'), '--script',
               'layers/test_metadata_budget.gd', '--', str(out)]
    result = subprocess.run(command, capture_output=True, text=True, timeout=180)
    log = result.stdout+result.stderr
    (out/'native.log').write_text(log)
    print(log)
    assert result.returncode == 0 and 'ERROR:' not in log
    assert hashlib.sha256(path.read_bytes()).hexdigest() == before
    report['native'] = json.loads((out/'native-metadata.json').read_text())
    report['source_sha256'] = before
    report['all_payloads_and_statistics_verified'] = True
    report['capacity_and_corruption_checks_passed'] = True
    (out/'summary.json').write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))


if __name__ == '__main__':main()

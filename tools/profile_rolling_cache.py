"""Read-only full forward/reverse rolling-cache measurement on an existing capture."""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneReader


def identity(path):
    stat = path.stat()
    return dict(bytes=stat.st_size, mtime_ns=stat.st_mtime_ns, inode=stat.st_ino)


def verify(source, report):
    scientific = report['scientific']
    with SceneReader(source) as reader:
        sample = reader.read_sample('field', scientific['source_index'])
        hashes = {key: hashlib.sha256(value.tobytes()).hexdigest()
                  for key, value in sample.items()}
    assert hashes == scientific['hashes']
    return hashes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--capture', required=True, type=Path)
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--renderer', choices=['headless', 'forward_plus'], default='forward_plus')
    parser.add_argument('--cache-mib', type=int, default=0, help='Optional test ceiling; zero uses adaptive system capacity')
    args = parser.parse_args()
    source = args.capture.resolve(); out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    before = identity(source)
    command = [args.godot, '--path', str(ROOT/'viewer'), '--audio-driver', 'Dummy']
    command += ['--headless'] if args.renderer == 'headless' else ['--rendering-method', args.renderer, '--resolution', '960x640']
    command += ['--script', 'layers/profile_rolling_cache.gd', '--', str(source), str(out/'result.json'), str(args.cache_mib)]
    with (out/'native.log').open('w') as log:
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=2400)
    assert not result.returncode and 'ERROR:' not in (out/'native.log').read_text()
    report = json.loads((out/'result.json').read_text())
    assert not report['failures']
    hashes = verify(source, report)
    assert identity(source) == before
    (out/'source.json').write_text(json.dumps(dict(path=str(source), identity=before,
        unchanged_stat=True, independent_source_hashes=hashes,
        scope='Stat identity plus independent full-channel oracle for the reported sample; not a whole-file hash.'), indent=2)+'\n')
    print(f'Production rolling cache: {report["checks"]} checks passed; independent source hashes match')


if __name__ == '__main__':
    main()

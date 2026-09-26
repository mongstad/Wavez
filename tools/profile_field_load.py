"""Read-only native SSC startup profile with source integrity and optional playback checks."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], required=True)
    parser.add_argument('--viewer', type=Path, default=ROOT / 'viewer')
    parser.add_argument('--exercise', action='store_true')
    args = parser.parse_args()
    source = args.capture.resolve()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=False)
    # Integrity reads warm filesystem caches; timings are explicitly warm-cache.
    before = digest(source)
    command = [args.godot, '--path', str(args.viewer.resolve()), '--rendering-method', args.renderer,
               '--audio-driver', 'Dummy', '--resolution', '1280x800', '--script',
               'layers/profile_field_load.gd', '--', str(source), str(output / 'profile.json')]
    if args.exercise:
        command.append('--exercise')
    result = subprocess.run(command, capture_output=True, text=True, timeout=300)
    log = result.stdout + result.stderr
    (output / 'native.log').write_text(log)
    unchanged = before == digest(source)
    (output / 'source.json').write_text(json.dumps(dict(path=str(source), bytes=source.stat().st_size,
                                                      sha256=before, unchanged=unchanged), indent=2))
    print(log)
    if result.returncode or 'ERROR:' in log or not unchanged:
        raise SystemExit(1)


if __name__ == '__main__':
    main()

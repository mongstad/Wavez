"""Native Round 2 seek, speed, relocated actions and custom chrome regressions."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tests.g4.fixtures import scene
from simscope_export import SceneCapture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], default='forward_plus')
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    scene(out / 'scene.ssc')
    with SceneCapture(out / 'clock.ssc', objects=[dict(id='p', kind='particles', units='m', identity='persistent_i8')], metadata={'time_unit': 's'}) as capture:
        for time in [100.0, 160.0, 220.0, 3800.0]:
            capture.add_particles('p', time, [[0., 0., 0.]], ids=[1])
    hashes = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in out.glob('*.ssc')}
    command = [
        args.godot, '--path', str(ROOT / 'viewer'), '--rendering-method', args.renderer,
        '--resolution', '1440x900', '--audio-driver', 'Dummy', '--script', 'ui/shell/test_violet_round2.gd', '--', str(out),
    ]
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=120)
    except subprocess.TimeoutExpired as error:
        log = (error.stdout or b'') + (error.stderr or b'')
        (out / 'godot.log').write_bytes(log)
        raise RuntimeError(f'Round 2 timed out; see {out / "godot.log"}') from error
    log = result.stdout + result.stderr
    (out / 'godot.log').write_text(log)
    if result.returncode or 'ERROR:' in log or 'WARNING:' in log:
        raise RuntimeError(f'Round 2 failed; see {out / "godot.log"}')
    report = json.loads((out / 'report.json').read_text())
    assert not report['failures'], report['failures']
    assert hashes == {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in out.glob('*.ssc')}
    report['source_hashes_unchanged'] = hashes
    (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'Round 2: {report["checks"]} checks PASS ({args.renderer}); sources unchanged')


if __name__ == '__main__':
    main()

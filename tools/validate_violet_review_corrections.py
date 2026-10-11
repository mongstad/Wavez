"""Native owner-review corrections, including menu dispatch in real Fullscreen."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tests.g4.fixtures import scene
from wavez_export import SceneCapture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['forward_plus'], default='forward_plus')
    parser.add_argument('--display-driver', choices=['wayland', 'x11'])
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    scene(out / 'scene.wvz')
    with SceneCapture(out / 'clock.wvz', objects=[dict(id='p', kind='particles', units='m', identity='persistent_i8')]) as capture:
        for time in [100.125, 205.875, 3800.625]:
            capture.add_particles('p', time, [[0., 0., 0.]], ids=[1])
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.wvz')}
    command = [args.godot, '--path', str(ROOT / 'viewer'), '--rendering-method', args.renderer,
               '--resolution', '1440x900', '--audio-driver', 'Dummy', '--script',
               'ui/shell/test_violet_review_corrections.gd']
    if args.display_driver:
        command.extend(['--display-driver', args.display_driver])
    command.extend(['--', str(out)])
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=120)
    except subprocess.TimeoutExpired as error:
        (out / 'godot.log').write_bytes((error.stdout or b'') + (error.stderr or b''))
        raise RuntimeError(f'Review corrections timed out: {out / "godot.log"}') from error
    log = result.stdout + result.stderr
    (out / 'godot.log').write_text(log)
    startup_warning = 'libdecor-gtk-WARNING: Failed to initialize GTK'
    clean_log = log.replace(startup_warning, '')
    if result.returncode or any(token in clean_log for token in ['ERROR:', 'WARNING:']):
        raise RuntimeError(f'Review corrections failed: {out / "godot.log"}')
    report = json.loads((out / 'report.json').read_text())
    assert not report['failures'], report['failures']
    assert hashes == {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.wvz')}
    report.update(source_hashes_unchanged=hashes, requested_display_driver=args.display_driver or 'default',
                  known_libdecor_gtk_startup_warning=startup_warning in log)
    (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'Review corrections: {report["checks"]} checks PASS ({args.renderer}, {report["display_driver"]}); sources unchanged')


if __name__ == '__main__':
    main()

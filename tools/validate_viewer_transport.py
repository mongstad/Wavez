"""Native persistent transport checks using existing unequal-cadence fixtures."""
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
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--output-dir', type=Path, required=True)
    p.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], default='forward_plus')
    p.add_argument('--real-capture', type=Path)
    a = p.parse_args()
    out = a.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    source = scene(out / 'scene.ssc')
    offset = out/'offset.ssc'; single = out/'single.ssc'
    for path, times in [(offset, [100.0, 100.25, 102.0]), (single, [72.5])]:
        with SceneCapture(path, objects=[dict(id='p', kind='particles', units='m', identity='persistent_i8')], metadata={'time_unit': 'ms'}) as writer:
            for t in times: writer.add_particles('p', t, [[0., 0., 0.]], ids=[1])
    sources = [source, offset, single] + ([a.real_capture.resolve()] if a.real_capture else [])
    hashes = {str(s): hashlib.sha256(s.read_bytes()).hexdigest() for s in sources}
    (out/'config.json').write_text(json.dumps({'source': str(source), 'offset': str(offset), 'single': str(single), 'real': str(a.real_capture.resolve()) if a.real_capture else ''}))
    cmd = [a.godot, '--path', str(ROOT/'viewer'), '--rendering-method', a.renderer,
           '--audio-driver', 'Dummy', '--resolution', '1440x900', '--script', 'ui/shell/test_viewer_transport.gd',
           '--', '--transport-output='+str(out)]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    log = result.stdout + result.stderr; (out/'godot.log').write_text(log)
    if result.returncode or 'ERROR:' in log or 'WARNING:' in log:
        raise RuntimeError(f'Transport validation failed: {out}/godot.log')
    report = json.loads((out/'report.json').read_text())
    assert not report['failures'], report['failures']
    assert hashes == {str(s): hashlib.sha256(s.read_bytes()).hexdigest() for s in sources}
    report['source_hashes_unchanged'] = hashes
    (out/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'Transport: {report["checks"]} checks PASS ({a.renderer}); sources unchanged')


if __name__ == '__main__':
    main()

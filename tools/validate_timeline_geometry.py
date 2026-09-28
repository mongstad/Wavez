"""Pixel-level timeline endpoints, coverage, pointer and keyboard regression."""
import argparse
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--output-dir', type=Path, required=True)
    p.add_argument('--renderer', choices=['forward_plus', 'gl_compatibility'], default='forward_plus')
    p.add_argument('--baseline', action='store_true', help='Measure old endpoint error without requiring zero error')
    a = p.parse_args(); out = a.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    cmd = [a.godot, '--path', str(ROOT/'viewer'), '--audio-driver', 'Dummy', '--rendering-method', a.renderer, '--resolution', '1440x900', '--script', 'res://ui/shell/test_timeline_geometry.gd', '--', str(out)]
    if a.baseline: cmd.append('--baseline')
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    log = r.stdout+r.stderr; (out/'native.log').write_text(log)
    assert r.returncode == 0 and 'ERROR:' not in log and 'WARNING:' not in log, out/'native.log'
    report = json.loads((out/'geometry.json').read_text()); assert not report['failures']
    print(f'Geometry: {report["checks"]} checks PASS ({a.renderer})')

if __name__ == '__main__': main()

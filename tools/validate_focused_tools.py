"""Native focused-tool navigation, shared drafts, probe provenance and layout checks."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))


from validate_simulation_panel import fixture


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--output-dir', required=True, type=Path)
    p.add_argument('--renderer', choices=['forward_plus'], default='forward_plus')
    args = p.parse_args()
    out = args.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    fixture(out/'mixed.wvz', ['particles','volume','mesh'])
    fixture(out/'fields.wvz', ['volume'])
    fixture(out/'particles.wvz', ['particles'])
    hashes = {f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in out.glob('*.wvz')}
    run = subprocess.run([args.godot, '--path', str(ROOT/'viewer'), '--rendering-method', args.renderer,
                          '--audio-driver','Dummy','--resolution','1440x900', '--script',
                          'ui/shell/test_focused_tools.gd','--',str(out)], text=True,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=210)
    (out/'native.log').write_text(run.stdout)
    if run.returncode or 'ERROR:' in run.stdout or 'WARNING:' in run.stdout:
        raise RuntimeError(f'Focused tool regression failed: {out}/native.log')
    report = json.loads((out/'report.json').read_text())
    assert not report['failures'],report['failures']
    assert hashes == {f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in out.glob('*.wvz')}
    report['source_hashes_unchanged'] = hashes
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'Focused tools: {report["checks"]} PASS ({args.renderer}); sources unchanged')

if __name__ == '__main__':
    main()

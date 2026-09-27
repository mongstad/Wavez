"""Controller hysteresis and real-pool resizing against independent value oracles."""
import argparse
import hashlib
from pathlib import Path
import subprocess
from validate_field_session import ROOT, fixture


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--output-dir', type=Path, required=True)
    a = p.parse_args();out = a.output_dir.resolve();out.mkdir(parents=True, exist_ok=False)
    source = fixture(out);before = hashlib.sha256(source.read_bytes()).hexdigest()
    cmd = [a.godot, '--headless', '--path', str(ROOT/'viewer'), '--script', 'layers/test_field_concurrency.gd', '--', str(out)]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    log = result.stdout+result.stderr;(out/'native.log').write_text(log);print(log)
    assert not result.returncode and 'ERROR:' not in log
    assert hashlib.sha256(source.read_bytes()).hexdigest() == before


if __name__ == '__main__':main()

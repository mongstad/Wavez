"""Read-only UX3 workflow and bounded native measurements on a mixed SSC source.

Without --capture, creates a tiny fixture. No scientific solver is invoked.
The paired cases vary only dock visibility, not renderer or scientific settings.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tests.g4.fixtures import scene


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--capture", type=Path)
    parser.add_argument("--renderer", choices=["forward_plus", "gl_compatibility"], default="forward_plus")
    args = parser.parse_args()
    out = args.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    source = args.capture.resolve() if args.capture else scene(out / "scene.ssc")
    before = digest(source)
    command = [args.godot, "--path", str(ROOT / "viewer"), "--rendering-method", args.renderer,
               "--resolution", "1440x900", "--audio-driver", "Dummy", "--disable-vsync", "--max-fps", "60",
               "--script", "ui/shell/test_ux3_integration.gd", "--",
               "--integration-source=" + str(source), "--integration-output=" + str(out)]
    result = subprocess.run(command, capture_output=True, text=True, timeout=240)
    log = result.stdout + result.stderr; (out / "godot.log").write_text(log)
    assert result.returncode == 0 and "ERROR:" not in log and "WARNING:" not in log, log[-5000:]
    report = json.loads((out / "report.json").read_text())
    assert not report["failures"], report["failures"]
    assert digest(source) == before, "Source changed"
    report.update(source_sha256=before, source_unchanged=True, command=command)
    (out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f'UX3 integration: {report["checks"]} checks PASS ({args.renderer}); source unchanged')


if __name__ == "__main__":
    main()

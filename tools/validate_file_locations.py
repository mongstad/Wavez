"""Focused File Locations preferences and export admission validation."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--renderer", choices=("headless", "gl_compatibility", "forward_plus"), default="headless")
    args = parser.parse_args()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=False)
    source = output / "small scene.wvz"
    with SceneCapture(source, objects=[dict(id="particles", kind="particles", identity="persistent_i8", units="m")], metadata=dict(time_unit="s")) as writer:
        for time in (0.0, 1.0):
            writer.add_particles("particles", time, np.array([[time, 0, 0]], dtype="f4"), ids=np.array([7], dtype="i8"))
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise RuntimeError("This focused validation requires a PATH-installed FFmpeg")
    custom = output / "FFmpeg tools" / "ffmpeg custom"
    custom.parent.mkdir()
    custom.symlink_to(ffmpeg)
    environment = os.environ.copy()
    environment["XDG_DATA_HOME"] = str(output / "data")
    environment["XDG_CONFIG_HOME"] = str(output / "config")
    command = [str(args.godot.resolve()), "--path", str(ROOT / "viewer"), "--audio-driver", "Dummy"]
    command += ["--headless"] if args.renderer == "headless" else ["--rendering-method", args.renderer, "--resolution", "1440x900"]
    command += ["--script", "ui/test_file_locations.gd", "--",
                "--locations-output=" + str(output), "--locations-source=" + str(source), "--locations-ffmpeg=" + str(custom)]
    result = subprocess.run(command, cwd=ROOT, env=environment, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
    (output / "godot.log").write_text(result.stdout)
    # The same two GL texture cleanup diagnostics occur in the existing native
    # session-log and shortcut harnesses after freeing a small viewer fixture.
    cleanup_pattern = r"ERROR: Texture with GL ID of \d+: leaked 349524 bytes\.\n   at: ~Utilities \(drivers/gles3/storage/utilities\.cpp:82\)\n"
    cleanup = re.findall(cleanup_pattern, result.stdout) if args.renderer == "gl_compatibility" else []
    checked = re.sub(cleanup_pattern, "", result.stdout) if len(cleanup) == 2 else result.stdout
    if result.returncode or "ERROR:" in checked or "WARNING:" in checked:
        raise RuntimeError(f"File Locations regression failed; see {output / 'godot.log'}")
    report = json.loads((output / "report.json").read_text())
    assert not report["failures"], report["failures"]
    print(f"File Locations: {report['checks']} checks PASS ({args.renderer}); {len(cleanup)} known Compatibility cleanup diagnostics")


if __name__ == "__main__":
    main()

"""Exercise per-session logs with small particle, volume and mixed WVZ1 scenes."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture


def capture(path: Path, kind: str) -> None:
    objects = []
    if kind in ("particles", "mixed"):
        objects.append(dict(id="particles", kind="particles", identity="persistent_i8", units="m"))
    if kind in ("volume", "mixed"):
        objects.append(dict(id="field", kind="volume", units="m"))
    with SceneCapture(path, objects=objects, metadata=dict(time_unit="s")) as writer:
        for time in (0.0, 1.0):
            if kind in ("particles", "mixed"):
                writer.add_particles("particles", time, np.array([[time, 0, 0], [1 + time, 0, 0]]), ids=np.array([7, 9], dtype="i8"))
            if kind in ("volume", "mixed"):
                writer.add_volume("field", time, {"density": np.full((2, 2, 2), time + 1, dtype="f4")}, origin=[0, 0, 0], spacing=[1, 1, 1])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--renderer", choices=("headless", "gl_compatibility", "forward_plus"), default="headless")
    args = parser.parse_args()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=False)
    for kind in ("particles", "volume", "mixed"):
        capture(output / f"{kind}.wvz", kind)
    environment = os.environ.copy()
    environment["XDG_DATA_HOME"] = str(output / "user-data")
    environment["XDG_CONFIG_HOME"] = str(output / "config")
    log_directory = output / "user-data" / "godot" / "app_userdata" / "WAVEZ" / "logs"
    log_directory.mkdir(parents=True)
    for index in range(33):
        old = log_directory / f"wavez-2000-01-01_00-00-{index:02d}-1-0000000000000001.log"
        with old.open("wb") as stream:
            stream.truncate(40 * 1048576 if index < 2 else 20)
    command = [str(args.godot.resolve()), "--path", str(ROOT / "viewer"), "--audio-driver", "Dummy"]
    command += ["--headless"] if args.renderer == "headless" else ["--rendering-method", args.renderer, "--resolution", "1440x900"]
    command += ["--script", "ui/test_session_log.gd", "--",
               "--session-log-output=" + str(output)]
    result = subprocess.run(command, cwd=ROOT, env=environment, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
    (output / "stdout.log").write_text(result.stdout)
    if result.returncode or "ERROR:" in result.stdout or "WARNING:" in result.stdout:
        raise RuntimeError(f"Session log regression failed; see {output / 'stdout.log'}")
    report = json.loads((output / "report.json").read_text())
    assert not report["failures"], report["failures"]
    retained = list(log_directory.glob("wavez-*.log"))
    assert len(retained) <= 30, "Session count was not bounded"
    assert sum(path.stat().st_size for path in retained) <= 64 * 1048576, "Log directory bytes were not bounded"
    assert all(Path(path).exists() for path in report["logs"]), "A current session was pruned"
    assert not (log_directory / "wavez-2000-01-01_00-00-00-1-0000000000000001.log").exists(), "Oldest log survived pruning"
    blocked_data = output / "blocked-data"
    blocked_user = blocked_data / "godot" / "app_userdata" / "WAVEZ"
    blocked_user.mkdir(parents=True)
    (blocked_user / "logs").write_text("This path is a file, so logging cannot create its directory.")
    blocked_environment = environment.copy()
    blocked_environment["XDG_DATA_HOME"] = str(blocked_data)
    blocked = subprocess.run([str(args.godot.resolve()), "--headless", "--path", str(ROOT / "viewer"),
                              "--audio-driver", "Dummy", "--quit-after", "20"],
                             cwd=ROOT, env=blocked_environment, text=True,
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
    (output / "blocked-stdout.log").write_text(blocked.stdout)
    assert blocked.returncode == 0, "Viewer failed to start when session logging was unavailable"
    print(f"Session logging: {report['checks']} checks PASS; three capture logs; caps and unavailable storage handled")


if __name__ == "__main__":
    main()

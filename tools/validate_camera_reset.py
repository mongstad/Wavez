"""Focused Reset Camera regression on off-origin WVZ1 fixtures."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture


def fixture(path, kind, scale=1.0):
    offset = np.array([40.0, -25.0, 30.0]) * scale
    particles = np.array([[-2., 0., 0.], [2., 0., 0.], [0., 3., 1.]]) * scale + offset
    mesh = np.vstack((particles, offset + np.array([0., 0., 3.]) * scale))
    objects = []
    if kind in ("particles", "mixed"):
        objects.append(dict(id="particles", kind="particles", identity="persistent_i8", units="units"))
    if kind in ("field", "mixed"):
        objects.append(dict(id="field", kind="volume", identity="grid", units="units"))
    if kind in ("mesh", "mixed"):
        objects.append(dict(id="mesh", kind="mesh", identity="stable_topology", units="units"))
    with SceneCapture(path, objects=objects, compression="none") as writer:
        if kind in ("particles", "mixed"):
            writer.add_particles("particles", 0.0, particles, ids=np.array([1, 2, 3], dtype="i8"))
        if kind in ("field", "mixed"):
            values = np.ones((3, 3, 3), dtype="f4")
            writer.add_volume("field", 0.0, {"value": values}, origin=offset + np.array([-2., -2., -2.]) * scale, spacing=[scale] * 3)
        if kind in ("mesh", "mixed"):
            writer.add_mesh("mesh", 0.0, mesh, np.array([[0, 1, 2], [0, 1, 3], [0, 2, 3], [1, 2, 3]]), vertex_channels={"value": np.arange(4, dtype="f4"), "vertex_id": np.arange(4, dtype="i8")})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--renderer", choices=["headless", "forward_plus"], default="headless")
    parser.add_argument("--capture", type=Path)
    parser.add_argument("--export", action="store_true")
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    for name in ("particles", "field", "mesh", "mixed"):
        fixture(out / (name + ".wvz"), name)
    fixture(out / "small.wvz", "mesh", .001)
    fixture(out / "large.wvz", "mesh", 10000.0)
    capture = args.capture.resolve() if args.capture else None
    paths = list(out.glob("*.wvz")) + ([capture] if capture else [])
    sources = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    env = os.environ.copy()
    # Keep Godot's installed export templates visible during import/export.
    env["XDG_CONFIG_HOME"] = str(out / "config")
    def run(label, command):
        completed = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True, timeout=120)
        log = completed.stdout + completed.stderr
        (out / (label + ".log")).write_text(log)
        if completed.returncode:
            raise RuntimeError(log[-6000:])
    if args.export:
        project = out / "export-source"
        shutil.copytree(ROOT / "viewer", project, ignore=shutil.ignore_patterns(".godot"))
        with (project / "project.godot").open("a") as config:
            config.write('\n[autoload]\nResetValidation="*res://scene/test_camera_reset.gd"\n')
        (project / "export_presets.cfg").write_text('[preset.0]\nname="Camera reset validation"\nplatform="Linux"\nrunnable=true\nexport_filter="all_resources"\ninclude_filter=""\nexclude_filter=""\nscript_export_mode=2\n[preset.0.options]\nbinary_format/architecture="x86_64"\nbinary_format/embed_pck=false\n')
        run("import", [args.godot, "--headless", "--path", str(project), "--editor", "--import", "--quit"])
        binary = out / "wavez.x86_64"
        run("export", [args.godot, "--headless", "--path", str(project), "--export-release", "Camera reset validation", str(binary)])
        command = [str(binary)]
    else:
        run("import", [args.godot, "--headless", "--path", "viewer", "--editor", "--import", "--quit"])
        command = [args.godot, "--path", "viewer", "--script", "res://scene/run_camera_reset_tests.gd"]
    display = ["--headless"] if args.renderer == "headless" else ["--rendering-method", args.renderer, "--display-driver", "wayland"]
    env["XDG_DATA_HOME"] = str(out / "data")
    command += [*display, "--resolution", "960x640", "--audio-driver", "Dummy", "--", "--reset-output=" + str(out)]
    if capture: command.append("--reset-capture=" + str(capture))
    run("reset", command)
    report = json.loads((out / "reset-report.json").read_text())
    assert not report["failures"], report["failures"]
    assert report["packaged"] == args.export
    assert sources == {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    print(f'Camera reset: {report["checks"]} checks PASS ({args.renderer}, packaged={args.export}); source hashes unchanged')


if __name__ == "__main__":
    main()

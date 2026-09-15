"""Validate the opt-in UX2 foundation against independent float64 bits and native Godot controls."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import random
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BASELINE = "7037f5f"


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def oracle():
    texts = [
        "-0.0", "0.0", "1.2345678901234567e-19", "2.2250738585072014e-308",
        "4.9406564584124654e-324", "1.7976931348623157e308",
        "1.00000000000000011102230246251565404236316680908203125",
        "1.00000000000000033306690738754696212708950042724609375",
        "2.5e-324", "2.225073858507201e-308", "1e-300", "0.1",
        "+.125", "12.", "00001.25", "-3.141592653589793238462643383279502884",
        "1." + "0" * 700 + "1", "0." + "0" * 307 + "22250738585072014",
    ]
    rng = random.Random(20260913)
    while len(texts) < 300:
        value = struct.unpack("<d", rng.getrandbits(64).to_bytes(8, "little"))[0]
        if math.isfinite(value) and value:
            texts.append(format(value, ".17g"))
    return [dict(text=text, little_endian_hex=struct.pack("<d", float(text)).hex()) for text in texts]


def source_invariance():
    paths = subprocess.check_output([
        "git", "ls-tree", "-r", "--name-only", BASELINE, "--", "viewer", "simscope_export", "examples", "tests"
    ], cwd=ROOT, text=True).splitlines()
    rows = []
    for name in paths:
        old = subprocess.check_output(["git", "show", f"{BASELINE}:{name}"], cwd=ROOT)
        current = (ROOT / name).read_bytes()
        rows.append(dict(path=name, identical=old == current, sha256=hashlib.sha256(current).hexdigest()))
    assert all(row["identical"] for row in rows), "Existing production source changed during UX2"
    return dict(baseline=BASELINE, files=rows, identical=len(rows))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--renderer", choices=["forward_plus", "gl_compatibility"], default="forward_plus")
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    write(out / "float64-oracle.json", oracle())
    env = os.environ.copy()
    env.update(XDG_DATA_HOME=str(out / "userdata"), XDG_CONFIG_HOME=str(out / "config"),
               PYTHONDONTWRITEBYTECODE="1", PYTHON_BIN=sys.executable,
               PATH=str(Path(sys.executable).parent) + os.pathsep + env.get("PATH", ""))
    commands = []

    def run(name, command, timeout=180):
        result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=timeout)
        log = result.stdout + result.stderr
        (out / (name + ".log.txt")).write_text(log)
        clean = result.returncode == 0 and not any(marker in log for marker in ["SCRIPT ERROR:", "ERROR:", "WARNING:"])
        commands.append(dict(name=name, command=command, exit_code=result.returncode, clean_log=clean))
        print(f"{name}: {'PASS' if clean else 'FAIL'}", flush=True)
        if not clean:
            raise RuntimeError(log[-5000:])

    try:
        run("import", [args.godot, "--headless", "--path", "viewer", "--editor", "--import"])
        for module, name in [("examples.scene_demo", "scene"), ("examples.identity_demo", "identity")]:
            run(name, [sys.executable, "-m", module] + (["--small"] if name == "scene" else []) + ["--output", str(out / (name + ".ssc"))])
        native = [args.godot, "--path", "viewer", "--rendering-method", args.renderer, "--script"]
        run("native", native + ["res://ui/lab/test_ui_foundation.gd", "--", f"--ux2-output={out / 'native'}"])
        run("isolation", native + ["res://ui/lab/test_viewer_isolation.gd", "--", f"--ux2-output={out / 'isolation'}", f"--ux2-fixture={out / 'scene.ssc'}"])
        run("hud", native + ["res://scene/test_hud_layout.gd", "--", f"--hud-output={out / 'hud'}", f"--hud-fixture={out / 'identity.ssc'}"])
        write(out / "source-invariance.json", source_invariance())
        native_result = json.loads((out / "native/validation.json").read_text())
        assert native_result["display"] != "headless", "Native rendering validation requires a display"
        assert not native_result["failures"]
        report = dict(status="PASS", renderer=args.renderer, commands=commands, native_checks=len(native_result["checks"]),
                      contrast_pairs=len(native_result["contrast"]), oracle_cases=300,
                      isolated_checks=6, hud_cases=6, source_baseline=BASELINE)
    except Exception as error:
        report = dict(status="FAIL", commands=commands, error=f"{type(error).__name__}: {error}")
    write(out / "summary.json", report)
    print(json.dumps(report, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())

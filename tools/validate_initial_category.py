"""Validate source-kind Simulation category selection in source and Linux package runs."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.validate_simulation_panel import fixture

CASES = {
    "particles": ["particles"],
    "fields": ["volume"],
    "meshes": ["mesh"],
    "particle-fields": ["particles", "volume"],
    "particle-meshes": ["particles", "mesh"],
    "field-meshes": ["volume", "mesh"],
    "mixed": ["particles", "volume", "mesh"],
}


def run(command, output, label, env):
    result = subprocess.run(command, capture_output=True, text=True, env=env, timeout=180)
    log = result.stdout + result.stderr
    (output / f"{label}.log").write_text(log)
    if result.returncode or "ERROR:" in log or "WARNING:" in log:
        raise RuntimeError(f"{label} failed; inspect {output / (label + '.log')}")
    return log


def check_report(directory, packaged, offline):
    report = json.loads((directory / "report.json").read_text())
    assert not report["failures"], report["failures"]
    assert report["packaged"] == packaged and report["offline"] == offline, report
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--package", action="store_true")
    parser.add_argument("--real-capture", nargs=2, action="append", default=[], metavar=("PATH", "CATEGORY_INDEX"),
                        help="Open an existing real WVZ capture and check its initial category (0=Particles, 1=Fields, 2=Meshes)")
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    for name, kinds in CASES.items():
        fixture(out / f"{name}.wvz", kinds)
    hashes = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in out.glob("*.wvz")}
    source = [args.godot, "--path", str(ROOT / "viewer"), "--script", "res://ui/shell/run_initial_category_tests.gd"]
    package = None
    if args.package:
        project = out / "export-source"
        shutil.copytree(ROOT / "viewer", project, ignore=shutil.ignore_patterns(".godot"))
        with (project / "project.godot").open("a") as settings:
            settings.write('\n[autoload]\nInitialCategoryTest="*res://ui/shell/test_initial_category.gd"\n')
        (project / "export_presets.cfg").write_text(
            '[preset.0]\nname="Initial category validation"\nplatform="Linux"\nrunnable=true\n'
            'export_filter="all_resources"\ninclude_filter=""\nexclude_filter=""\nscript_export_mode=2\n'
            '[preset.0.options]\nbinary_format/architecture="x86_64"\nbinary_format/embed_pck=false\n'
        )
        build_env = os.environ.copy()
        for label, options in [("package-import", ["--editor", "--import", "--quit"]),
                               ("package-export", ["--export-release", "Initial category validation", str(out / "wavez.x86_64")])]:
            run([args.godot, "--headless", "--path", str(project), *options], out, label, build_env)
        package = [str(out / "wavez.x86_64")]
    results = {}
    for name, command, packaged in [("source", source, False)] + ([ ("package", package, True) ] if package else []):
        for renderer in ["forward_plus"]:
            label = f"{name}-{renderer}"
            directory = out / label
            directory.mkdir()
            env = os.environ.copy()
            env["XDG_CONFIG_HOME"] = str(directory / "config")
            env["XDG_DATA_HOME"] = str(directory / "profile")
            run(command + ["--rendering-method", renderer, "--audio-driver", "Dummy", "--resolution", "1440x900",
                           "--", str(out), str(directory)], out, label, env)
            results[label] = check_report(directory, packaged, False)
    directory = out / "source-offline"
    directory.mkdir()
    env = os.environ.copy()
    env["XDG_CONFIG_HOME"] = str(directory / "config")
    env["XDG_DATA_HOME"] = str(directory / "profile")
    run(source + ["--headless", "--audio-driver", "Dummy", "--", str(out), str(directory), "--offline"],
        out, "source-offline", env)
    results["source-offline"] = check_report(directory, False, True)
    for index, (path, expected_text) in enumerate(args.real_capture):
        expected = int(expected_text)
        if expected not in range(3) or not Path(path).is_file():
            raise ValueError(f"Invalid real capture or category: {path} {expected_text}")
        label = f"real-{index}"
        directory = out / label
        directory.mkdir()
        env = os.environ.copy()
        env["XDG_CONFIG_HOME"] = str(directory / "config")
        env["XDG_DATA_HOME"] = str(directory / "profile")
        run(source + ["--headless", "--audio-driver", "Dummy", "--", str(out), str(directory),
                      "--real-path=" + path, "--real-expected=" + expected_text], out, label, env)
        results[label] = check_report(directory, False, False)
    assert hashes == {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in out.glob("*.wvz")}
    summary = {"checks": sum(report["checks"] for report in results.values()), "runs": results,
               "source_sha256_unchanged": hashes}
    (out / "validation.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f'Initial category: {summary["checks"]} PASS across {len(results)} runs; source hashes unchanged')


if __name__ == "__main__":
    main()

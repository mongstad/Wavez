"""Exercise About from the source viewer or an exported Linux executable."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tests.g4.fixtures import scene
from tools.application_version import read_version
from tools.sync_about_notices import OUTPUT, SOURCES, resource_text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--export", action="store_true", help="Build a temporary Linux release with a validation-only autoload; test its normal Main scene")
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--renderer", choices=["forward_plus", "gl_compatibility", "headless"], default="forward_plus")
    parser.add_argument("--open-browser", action="store_true")
    args = parser.parse_args()
    assert OUTPUT.read_text(encoding="utf-8") == resource_text(), "Packaged notices must match canonical sources"
    out = args.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    capture = scene(out / "scene.ssc")
    digest = hashlib.sha256(capture.read_bytes()).hexdigest()
    if args.export:
        project = out / "export-source"; shutil.copytree(ROOT / "viewer", project, ignore=shutil.ignore_patterns(".godot"))
        with (project / "project.godot").open("a") as settings:
            settings.write('\n[autoload]\nAboutValidation="*res://ui/about/test_about.gd"\n')
        (project / "export_presets.cfg").write_text('[preset.0]\nname="About validation"\nplatform="Linux"\nrunnable=true\nexport_filter="all_resources"\ninclude_filter=""\nexclude_filter=""\nscript_export_mode=2\n[preset.0.options]\nbinary_format/architecture="x86_64"\nbinary_format/embed_pck=false\n')
        executable = out / "simscope.x86_64"
        for label, options in [("import", ["--editor", "--import", "--quit"]), ("export", ["--export-release", "About validation", str(executable)])]:
            result = subprocess.run([args.godot, "--headless", "--path", str(project), *options], capture_output=True, text=True, timeout=120)
            log = result.stdout + result.stderr; (out / (label + ".log")).write_text(log)
            assert result.returncode == 0 and "ERROR:" not in log, log[-5000:]
        # Release templates do not expose the editor's --script entry point.
        # The test-only autoload exercises the normal exported Main scene.
        command = [str(executable)]
    else:
        command = [args.godot, "--path", str(ROOT / "viewer"), "--script", "res://ui/about/run_about_tests.gd"]
    command += ["--audio-driver", "Dummy"]
    command += ["--headless"] if args.renderer == "headless" else ["--rendering-method", args.renderer, "--resolution", "1440x900"]
    command += ["--log-file", str(out / "godot.log"), "--", "--about-output=" + str(out)]
    if args.open_browser:command += ["--open-browser"]
    result = subprocess.run(command, cwd=out, capture_output=True, text=True, timeout=120)
    log = result.stdout + result.stderr; (out / "native.log").write_text(log)
    assert result.returncode == 0 and "ERROR:" not in log, log[-5000:]
    report = json.loads((out / "about-report.json").read_text())
    assert not report["failures"] and report["version"] == read_version()
    for title, path in SOURCES.items():
        assert report["notice_sha256"][title] == hashlib.sha256((ROOT / path).read_text(encoding="utf-8").encode()).hexdigest(), title
    assert hashlib.sha256(capture.read_bytes()).hexdigest() == digest
    report.update(source_unchanged_sha256=digest, packaged=args.export)
    (out / "about-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f'About: {report["checks"]} checks PASS ({args.renderer}, packaged={args.export})')


if __name__ == "__main__":
    main()

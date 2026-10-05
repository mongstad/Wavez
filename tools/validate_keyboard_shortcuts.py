"""Exercise staged keyboard preferences, authoritative dispatch and fresh-process persistence."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.validate_simulation_panel import fixture


def run(command, output, label, env, known_compatibility_cleanup=False, known_packaged_window_cleanup=False):
    result = subprocess.run(command, capture_output=True, text=True, env=env, timeout=160)
    log = result.stdout + result.stderr
    (output / f"{label}.log").write_text(log)
    # Normal shutdown after the dual-viewer lifecycle reproduces two texture
    # diagnostics in both runtimes on accepted main 0496d12.
    pattern = r"ERROR: Texture with GL ID of \d+: leaked 349524 bytes\.\n   at: ~Utilities \(drivers/gles3/storage/utilities.cpp:82\)\n"
    cleanup = re.findall(pattern, log) if known_compatibility_cleanup else []
    checked = re.sub(pattern, "", log) if known_compatibility_cleanup and len(cleanup) == known_compatibility_cleanup else log
    # The same existing file/menu/tool flow reproduces this exact signal pair
    # in an accepted-main Linux release. Keep it visible in the saved results.
    window_pattern = r"ERROR: Attempt to disconnect a nonexistent connection from 'root:<Window#\d+>'. Signal: '(?:focus_entered|tree_exited)', callable: ''\.\n   at: _disconnect \(core/object/object.cpp:1644\)\n"
    window_cleanup = re.findall(window_pattern, checked) if known_packaged_window_cleanup else []
    if len(window_cleanup) == 2 and any("'focus_entered'" in item for item in window_cleanup) and any("'tree_exited'" in item for item in window_cleanup):
        checked = re.sub(window_pattern, "", checked)
    if result.returncode or "ERROR:" in checked or "WARNING:" in checked:
        raise RuntimeError(f"Shortcut validation failed: {output / (label + '.log')}")
    return {"compatibility_texture_cleanup": cleanup, "packaged_window_cleanup": window_cleanup}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--renderer", choices=["forward_plus", "gl_compatibility", "headless"], default="forward_plus")
    parser.add_argument("--export", action="store_true")
    parser.add_argument("--speed-only", action="store_true", help="Validate only the new movement-speed shortcut paths")
    args = parser.parse_args()
    out = args.output_dir.resolve(); out.mkdir(parents=True, exist_ok=False)
    scenes = {"particles": ["particles"], "fields": ["volume"], "meshes": ["mesh"],
              "mixed": ["particles", "volume", "mesh"]}
    for name, kinds in scenes.items():
        fixture(out / f"{name}.wvz", kinds)
    hashes = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in out.glob("*.wvz")}
    env = os.environ.copy()
    env["XDG_CONFIG_HOME"] = str(out / "config")
    # Exports use externally installed templates, while runtime preferences use an isolated profile.
    if args.export:
        project = out / "export-source"
        shutil.copytree(ROOT / "viewer", project, ignore=shutil.ignore_patterns(".godot"))
        with (project / "project.godot").open("a") as settings:
            settings.write('\n[autoload]\nShortcutValidation="*res://ui/shell/test_keyboard_shortcuts.gd"\n')
        (project / "export_presets.cfg").write_text('[preset.0]\nname="Shortcut validation"\nplatform="Linux"\nrunnable=true\nexport_filter="all_resources"\ninclude_filter=""\nexclude_filter=""\nscript_export_mode=2\n[preset.0.options]\nbinary_format/architecture="x86_64"\nbinary_format/embed_pck=false\n')
        executable = out / "wavez.x86_64"
        for label, options in [("import", ["--editor", "--import", "--quit"]), ("export", ["--export-release", "Shortcut validation", str(executable)])]:
            run([args.godot, "--headless", "--path", str(project), *options], out, label, env)
        command = [str(executable)]
    else:
        command = [args.godot, "--path", str(ROOT / "viewer"), "--script", "res://ui/shell/run_shortcut_tests.gd"]
    env["XDG_DATA_HOME"] = str(out / "profile")
    command += ["--audio-driver", "Dummy", "--log-file", str(out / "godot.log")]
    command += ["--headless"] if args.renderer == "headless" else ["--rendering-method", args.renderer, "--resolution", "1440x900"]
    command += ["--", "--shortcut-output=" + str(out)]
    if args.speed_only:
        command.append("--shortcut-speed-only")
    native_cleanup = run(command, out, "native", env, known_packaged_window_cleanup=args.export)
    cleanup = run(command + ["--shortcut-restart"], out, "restart", env,
                  known_compatibility_cleanup=2 if args.renderer == "gl_compatibility" else 0)
    reports = [json.loads((out / name).read_text()) for name in ["report.json", "restart-report.json"]]
    assert all(not report["failures"] for report in reports)
    assert all(report["packaged"] == args.export for report in reports)
    assert {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in out.glob("*.wvz")} == hashes
    result = dict(checks=sum(report["checks"] for report in reports), source_sha256_unchanged=hashes,
                  renderer=args.renderer, packaged=args.export, fresh_process_restart=True,
                  known_engine_cleanup_diagnostics={"native": native_cleanup, "restart": cleanup}, reports=reports)
    (out / "validation.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f'Keyboard Shortcuts{" speed" if args.speed_only else ""}: {result["checks"]} PASS ({args.renderer}, packaged={args.export}); restart and source hash verified')


if __name__ == "__main__":
    main()

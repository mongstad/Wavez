"""#424: real Forward+ WYSIWYG image and independently owned pinned video exports.

The parent records the live scene and stages production video jobs, then exits.
Only afterwards do separate workers render the jobs. PNG comparisons are exact;
H.264 comparisons report bounded lossy RGB error. Every native engine diagnostic
is retained, including pre-existing package Popup diagnostics (strict failure).
The instrumented release changes only the parent entry scene; worker invocations
delegate to the unchanged Main.tscn from an unrelated working directory.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import time

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture
from tools.package_linux import stage, build


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fixtures(output):
    z, y, x = np.ogrid[:32, :32, :32]
    low = .6*np.cos(2*np.pi*x/32+.37)*np.ones((32, 32, 32))
    middle = .3*np.sin(2*np.pi*(x+2*y)/32-.21)*np.ones((32, 32, 32))
    high = .1*np.cos(2*np.pi*7*z/32+.63)*np.ones((32, 32, 32))
    declaration = dict(position_unit="dimensionless", channel_metadata={
        "field": {"amplitude": {"units": "dimensionless", "semantic": "signed"}}})
    # Domain 16: the modes lie strictly inside Low/Intermediate/High bins.
    for name, scale in [("field", 1.), ("replacement", 2.), ("mutation", .8), ("runtime-mutation", .7)]:
        with SceneCapture(output/(name+".wvz"), objects=[dict(id="field", kind="volume", units="dimensionless")], metadata=declaration) as writer:
            for index in range(3):
                q = (.2+low+middle+high)*(1+index*.2)*scale
                writer.add_volume("field", float(index), {"amplitude": q, "other": q*q}, origin=(0., 0., 0.), spacing=(.5, .5, .5), centering="node")


def package(godot, output):
    with tempfile.TemporaryDirectory(prefix="wavez-spectral-export-") as temporary:
        project = Path(temporary)/"viewer"
        inventory = stage(project)
        script = (project/"analysis/test_spectral_export.gd").read_text()
        script = script.replace("extends SceneTree", "extends Node\nvar root: Window:\n\tget: return get_tree().root\nvar process_frame: Signal:\n\tget: return get_tree().process_frame")
        script = script.replace("func _initialize()", "func _ready()").replace("create_timer(", "get_tree().create_timer(").replace("quit(", "get_tree().quit(")
        (project/"review_spectral_export.gd").write_text(script)
        (project/"review_entry.gd").write_text('''extends Node
func _ready():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--wavez-render-job="):
            add_child(load("res://Main.tscn").instantiate()); return
    add_child(load("res://review_spectral_export.gd").new())
''')
        (project/"Review.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://review_entry.gd" id="1"]\n[node name="Review" type="Node"]\nscript = ExtResource("1")\n')
        config = project/"project.godot"
        config.write_text(config.read_text().replace("res://Main.tscn", "res://Review.tscn"))
        binary = output/"WAVEZ.x86_64"
        build(godot, project, binary, output/"build-logs")
    (output/"python-inventory.json").write_text(json.dumps(inventory, indent=2)+"\n")
    return str(binary)


def read_json(path, default=None):
    try:
        return json.loads(path.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return default


def run(command, directory, env, cwd, timeout=180, cancel=False, mutate_source=None):
    began = time.monotonic()
    cancellation = None
    mutation = None
    with (directory/"native.log").open("w") as log:
        proc = subprocess.Popen(command, env=env, cwd=cwd, stdout=log, stderr=subprocess.STDOUT)
        try:
            while proc.poll() is None:
                if time.monotonic()-began > timeout:
                    raise TimeoutError(f"Render exceeded {timeout}s: {directory.name}")
                progress = read_json(directory/"progress.json", {})
                if cancel and cancellation is None and progress.get("stage") == "rendering" and progress.get("current_frame", 0) >= 2:
                    cancellation = dict(progress)
                    (directory/"cancel").touch()
                if mutate_source is not None and mutation is None and progress.get("stage") == "rendering" and progress.get("current_frame", 0) >= 2:
                    mutation = dict(progress)
                    with mutate_source.open("r+b") as fixture:
                        fixture.seek(-1, os.SEEK_END); value = fixture.read(1)
                        fixture.seek(-1, os.SEEK_END); fixture.write(bytes([value[0] ^ 1])); fixture.flush(); os.fsync(fixture.fileno())
                time.sleep(.02)
        finally:
            if proc.poll() is None:
                proc.kill()
            proc.wait()
    errors = [line for line in (directory/"native.log").read_text(errors="replace").splitlines() if "ERROR:" in line or "SCRIPT ERROR:" in line]
    return dict(exit_code=proc.returncode, elapsed_seconds=time.monotonic()-began, errors=errors, cancellation=cancellation, source_mutation=mutation,
                progress=read_json(directory/"progress.json"), metrics=read_json(directory/"metrics.json"))


def clone_job(original, target, mutate=None):
    target.mkdir()
    shutil.copytree(original/"spectral", target/"spectral")
    job = read_json(original/"job.json")
    job["output_path"] = str(target/"result.mp4")
    if mutate:
        mutate(job)
    (target/"job.json").write_text(json.dumps(job, indent=2)+"\n")


def rgb(path):
    return np.asarray(Image.open(path).convert("RGB"))


def unpack_exact(value):
    """Read the existing inspection f64 wire representation without rounding."""
    if isinstance(value, dict):
        if "$f64" in value:
            return struct.unpack("<d", bytes.fromhex(value["$f64"]))[0]
        return {key: unpack_exact(item) for key, item in value.items()}
    if isinstance(value, list):
        return [unpack_exact(item) for item in value]
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--package", action="store_true")
    args = parser.parse_args()
    if not Path("/usr/bin/ffmpeg").is_file() or not shutil.which("ffprobe"):
        raise RuntimeError("Focused MP4 regression requires /usr/bin/ffmpeg and ffprobe")
    output = args.output_dir.resolve(); output.mkdir(parents=True, exist_ok=False)
    fixtures(output)
    hashes = {name: sha256(output/(name+".wvz")) for name in ["field", "replacement", "mutation", "runtime-mutation"]}
    executable = package(args.godot, output) if args.package else str(Path(args.godot).resolve())
    cwd = output/"unrelated working directory"; cwd.mkdir()
    (cwd/"project.godot").write_text('config_version=5\n[application]\nconfig/name="Unrelated project"\n')
    env = dict(os.environ, PYTHONPATH="", PATH="/usr/bin:/bin", XDG_DATA_HOME=str(output/"profile/data"),
               XDG_CONFIG_HOME=str(output/"profile/config"), XDG_CACHE_HOME=str(output/"profile/cache"))
    common = ["--rendering-method", "forward_plus", "--rendering-driver", "vulkan", "--audio-driver", "Dummy"]
    parent_command = [executable] + ([] if args.package else ["--path", str(ROOT/"viewer"), "--script", "res://analysis/test_spectral_export.gd"])
    # Video's established logical annotation canvas is 1440px wide. Match it
    # here so enabled legend comparisons test the same layout and raster scale.
    parent_command += common+["--resolution", "1440x900", "--", "--spectral-export-output="+str(output)]
    parent = run(parent_command, output, env, cwd)
    native = read_json(output/"native.json", {})
    checks = []
    def check(ok, label):
        checks.append(dict(ok=bool(ok), label=label))
        if not ok:
            print("FAIL: "+label, flush=True)
    check(parent["exit_code"] == 0 and bool(native) and not native.get("failures"), "Live parent graphical and snapshot checks pass")
    cases = ["video-"+name for name in ["original", "low", "intermediate", "high", "legend", "custom", "ordinary", "source-mutation", "source-midrender"]]
    base = output/"video-low"
    if (base/"job.json").exists():
        for name in ["artifact-tampered", "artifact-missing", "snapshot-missing", "cancel-active"]:
            target = output/("video-"+name)
            clone_job(base, target, lambda job: job.update(fps=60, end_time=2, test_frame_delay_ms=50) if name == "cancel-active" else None)
            if name == "artifact-tampered":
                path = target/"spectral/field.f4"; data = bytearray(path.read_bytes()); data[-1] ^= 1; path.write_bytes(data)
            elif name == "artifact-missing":
                (target/"spectral/field.f4").unlink()
            elif name == "snapshot-missing":
                job = read_json(target/"job.json"); del job["spectral_presentation"]["artifact"]; del job["spectral_presentation"]["manifest"]
                (target/"job.json").write_text(json.dumps(job, indent=2)+"\n")
            cases.append("video-"+name)
    reports = {}
    for name in cases:
        directory = output/name
        if not (directory/"job.json").exists():
            check(False, name+": parent staged a job"); continue
        job = read_json(directory/"job.json")
        if name == "video-source-midrender":
            job.update(fps=60, end_time=2, test_frame_delay_ms=50)
            (directory/"job.json").write_text(json.dumps(job, indent=2)+"\n")
        command = [executable] + ([] if args.package else ["--path", str(ROOT/"viewer")])
        command += common+["--fixed-fps", str(job["fps"]), "--disable-vsync", "--", "--wavez-render-job="+str(directory/"job.json")]
        report = run(command, directory, env, cwd, cancel=name == "video-cancel-active",
                     mutate_source=output/"runtime-mutation.wvz" if name == "video-source-midrender" else None)
        reports[name] = report
        expected = "cancelled" if name == "video-cancel-active" else "failed" if name in ["video-source-mutation", "video-source-midrender", "video-artifact-tampered", "video-artifact-missing", "video-snapshot-missing"] else "complete"
        progress = report.get("progress") or {}
        check(progress.get("stage") == expected and report["exit_code"] == {"complete": 0, "failed": 1, "cancelled": 2}[expected], name+": worker reaches "+expected)
        frames = sorted((directory/"frames").glob("frame*.png"))
        if expected != "complete":
            check(not (directory/"result.mp4").exists(), name+": no misleading MP4 published")
            if name == "video-source-midrender":
                check(report["source_mutation"] is not None and 2 <= len(frames) < 120, name+": observed active batch stops after source mutation")
                check(all(np.array_equal(rgb(frame), rgb(directory/"viewport.png")) for frame in frames), name+": retained pre-mutation frames equal the pinned live scene")
            elif expected == "failed":
                check(not frames, name+": invalid snapshot/source never publishes an unintended frame")
            else:
                check(report["cancellation"] is not None and 2 <= len(frames) < 120, name+": cancellation occurs during an observed active batch")
            continue
        if progress.get("stage") != "complete" or report["exit_code"] != 0:
            # Preserve the failed worker's evidence and continue the remaining
            # independent cases; missing success artifacts are not a runner crash.
            continue
        check(len(frames) == 3, name+": three exact sample frames rendered")
        if not (directory/"timing.jsonl").exists():
            check(False, name+": completed job records its timing manifest")
            continue
        trace = [json.loads(line) for line in (directory/"timing.jsonl").read_text().splitlines()]
        check([item["capture_time"] for item in trace] == [0, .5, 1], name+": video timeline remains explicit and deterministic")
        spectral = "spectral_presentation" in job
        report["comparisons"] = []
        for index, frame in enumerate(frames):
            reference = directory/("viewport.png" if spectral and name != "video-legend" else f"viewport-{index}.png")
            if not reference.exists():
                check(False, name+f": frame {index} has an independent live reference")
                continue
            actual, desired = rgb(frame), rgb(reference)
            exact = actual.shape == desired.shape and np.array_equal(actual, desired)
            report["comparisons"].append(dict(frame=index, exact=exact,
                changed_pixels=int(np.any(actual != desired, axis=2).sum()) if actual.shape == desired.shape else None,
                reference_sha256=sha256(reference), frame_sha256=sha256(frame)))
            check(exact, name+f": frame {index} equals the independently captured live scene")
        if spectral:
            expected_snapshot = unpack_exact(job["spectral_presentation"])
            pin = read_json(directory/"spectral-presentation.json", {})
            report["pinned_provenance"] = pin
            check(pin.get("selected_band") == expected_snapshot["selected_band"] and pin.get("source") == expected_snapshot["source"], name+": video records selected reconstruction and unchanged source identity")
            check(pin.get("native_record") == expected_snapshot["data"]["record"] and pin.get("display") == expected_snapshot["display"] and pin.get("lut") == expected_snapshot["lut"], name+": native sample and exact display/LUT settings are preserved")
            check(all(item.get("spectral_presentation", {}).get("native_record") == expected_snapshot["data"]["record"]
                      and item["spectral_presentation"].get("selected_band") == expected_snapshot["selected_band"]
                      and item["spectral_presentation"].get("source_sha256") == expected_snapshot["source"]["sha256"]
                      and item["spectral_presentation"].get("display_sha256") == expected_snapshot["artifact"]["sha256"]
                      for item in trace), name+": every video time records the correct pinned native sample, field and source")
            if name != "video-legend":
                check(len({sha256(frame) for frame in frames}) == 1, name+": the pinned field stays constant while the video clock advances")
            else:
                check(len({sha256(frame) for frame in frames}) == 3, name+": enabled scientific legend discloses changing video time against the fixed native sample")
            sidecars = [read_json(path, {}) for path in sorted(directory.glob("inspection-*.json"))]
            check(len(sidecars) == 3 and all(item.get("spectral_presentation") and item.get("kind") == "wavez-visual-export" for item in sidecars), name+": optional per-frame metadata distinguishes the non-restorable derived presentation")
        else:
            check(not (directory/"spectral-presentation.json").exists() and all("spectral_presentation" not in item for item in trace), name+": ordinary exports do not acquire spectral metadata")
        movie = directory/"result.mp4"
        if movie.exists():
            try:
                probed = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height,nb_frames,r_frame_rate:format_tags=comment", "-of", "json", str(movie)], stderr=subprocess.STDOUT))
            except (subprocess.CalledProcessError, json.JSONDecodeError) as error:
                report["ffprobe_error"] = str(error)
                check(False, name+": published MP4 is decodable")
                continue
            probe = probed["streams"][0]
            report["ffprobe"] = probe
            check([probe["width"], probe["height"], int(probe["nb_frames"]), probe["r_frame_rate"]] == [job["width"], job["height"], 3, "2/1"], name+": H.264 output has requested size/frame count/rate")
            if spectral:
                comment = json.loads(probed.get("format", {}).get("tags", {}).get("comment", "{}"))
                report["mp4_provenance"] = comment
                check(comment.get("selected_band") == expected_snapshot["selected_band"] and comment.get("native_record") == expected_snapshot["data"]["record"] and comment.get("source_sha256") == expected_snapshot["source"]["sha256"], name+": standalone MP4 embeds selected band, native pin and source hash")
            raw = subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(movie), "-f", "rawvideo", "-pix_fmt", "rgb24", "-"])
            if len(raw) != 3*job["height"]*job["width"]*3 or len(frames) != 3:
                check(False, name+": encoded and PNG frame byte counts permit graphical comparison")
                continue
            decoded = np.frombuffer(raw, dtype=np.uint8).reshape(3, job["height"], job["width"], 3)
            errors = np.abs(decoded.astype(np.int16)-np.stack([rgb(frame) for frame in frames]).astype(np.int16))
            report["mp4_rgb_error"] = dict(mean=float(errors.mean()), p99=float(np.percentile(errors, 99)), maximum=int(errors.max()))
            check(errors.mean() < 5 and np.percentile(errors, 99) < 35, name+": encoded video matches PNG scene within declared lossy RGB tolerance")
        else:
            check(False, name+": MP4 published")
    sources_unchanged = all(sha256(output/(name+".wvz")) == hashes[name] for name in ["field", "replacement"])
    check(sources_unchanged, "Original and replacement WVZ1 inputs remain byte-for-byte unchanged")
    check(sha256(output/"mutation.wvz") != hashes["mutation"], "Isolated source-mutation negative control changed its dedicated fixture")
    check(sha256(output/"runtime-mutation.wvz") != hashes["runtime-mutation"], "Active video source-mutation negative control changed only its dedicated fixture")
    images = [output/(band+"-image.png") for band in ["original", "low", "intermediate", "high"]]
    check(all(path.exists() for path in images) and len({sha256(path) for path in images if path.exists()}) == 4, "Four selected reconstruction images are distinct; none silently substitutes a common original")
    errors = parent["errors"]+[error for report in reports.values() for error in report["errors"]]
    functional = not any(not check["ok"] for check in checks)
    summary = dict(packaged=args.package, headless=False, renderer="forward_plus", parent=parent, native=native, workers=reports,
                   checks=checks, source_hashes=hashes, sources_unchanged=sources_unchanged, errors=errors,
                   functional_pass=bool(functional), validation_exit_code=int(not functional or bool(errors)),
                   oracle="Independent live viewport capture; exact decoded PNG RGB. H.264 mean absolute RGB <5 and 99th percentile <35. Parent exits before any video worker launch. All native diagnostics contribute to strict status.")
    (output/"summary.json").write_text(json.dumps(summary, indent=2)+"\n")
    print(json.dumps(dict(output=str(output), checks=len(checks), functional_pass=functional, errors=len(errors), validation_exit_code=summary["validation_exit_code"])), flush=True)
    return summary["validation_exit_code"]


if __name__ == "__main__":
    raise SystemExit(main())

"""Focused spectral-plane source/package review; Forward+ is the visual gate.

Fixtures and bounded numerical oracles are generated outside the repository.
Optional existing Model A input stays read-only. No scientific solver is run.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture
from tools.package_linux import stage, build


def full_complex_band(region, spacing, low, high):
    """Separate full-complex oracle; no production kernel or real-FFT folding."""
    window = np.ones(region.shape)
    for axis, n in enumerate(region.shape):
        shape = [1, 1, 1]; shape[axis] = n
        window *= (.5-.5*np.cos(2*np.pi*np.arange(n)/n)).reshape(shape)
    mean = np.sum(window*region)/np.sum(window)
    transformed = np.fft.fftn(window*(region-mean))
    power = np.abs(transformed)**2/(region.size*np.sum(window*window))
    axes = [np.fft.fftfreq(n, d) for n, d in zip(region.shape, spacing[::-1])]
    radius = np.hypot(axes[0][:, None, None], np.hypot(axes[1][None, :, None], axes[2][None, None, :]))
    return float(np.sum(power[(radius >= low) & (radius < high)]))


def fixtures(out):
    shape = (48, 48, 48)
    spacing = (.25, .375, .5)
    origin = (-6., -9., -12.)
    z, y, x = np.ogrid[:48, :48, :48]
    envelope = 1.+.55*np.sin(2*np.pi*y/48)+.35*x/48
    base = envelope*np.cos(2*np.pi*x/8)*np.ones(shape)+.3*np.cos(2*np.pi*(y+z)/6)*np.ones(shape)
    identity = [1.,0.,0.,0.,0.,1.,0.,0.,0.,0.,1.,0.]
    for name in ("field", "other", "nonfinite", "translated", "scaled", "energy-only"):
        transform = identity.copy()
        if name == "translated": transform[3],transform[7],transform[11] = 2.,-3.,5.
        if name == "scaled": transform[0] = 2.
        with SceneCapture(out/(name+".wvz"),
                objects=[dict(id="field",kind="volume",units="dimensionless",data_to_world=transform)],
                metadata={"position_unit":"dimensionless","channel_metadata":{"field":{
                    "amplitude":{"units":"dimensionless","semantic":"signed"},
                    "energy_density":{"units":"dimensionless"}}}}) as writer:
            for t in (0.,2.,4.):
                q = base*(1+t/4)*(2 if name == "other" else 1)
                if name == "nonfinite": q=q.copy();q[24,24,24]=np.nan
                channels = {"energy_density":q*q} if name == "energy-only" else {"amplitude":q,"energy_density":q*q}
                writer.add_volume("field",t,channels,origin=origin,spacing=spacing,centering="node")
    expected = []
    for row in range(5):
        for col in range(5):
            start = [16,-8+row*12,-8+col*12]
            valid = all(0 <= v <= 32 for v in start)
            q = base[tuple(slice(v,v+16) for v in start)] if valid else None
            expected.append(dict(row=row,column=col,start=start,
                center_xyz=[origin[i]+(start[::-1][i]+7.5)*spacing[i] for i in range(3)],
                power=full_complex_band(q,spacing,.4,.8) if valid else None))
    (out/"golden.json").write_text(json.dumps(dict(shape=list(shape),spacing=spacing,origin=origin,
        band=dict(low=.4,high=.8),measurements=expected),indent=2)+"\n")


def package(godot, out):
    with tempfile.TemporaryDirectory(prefix="wavez-band-plane-review-") as temporary:
        project = Path(temporary)/"viewer"
        inventory = stage(project)
        assert "wavez_export/analysis/spatial_band_map.py" in inventory
        (out/"packaged-sources.json").write_text(json.dumps(inventory,indent=2)+"\n")
        source = project/"analysis/test_spatial_band_map.gd"
        script = source.read_text().replace("extends SceneTree", "extends Node\nvar root: Window:\n\tget: return get_tree().root\nvar process_frame: Signal:\n\tget: return get_tree().process_frame\nfunc create_timer(seconds: float) -> SceneTreeTimer:return get_tree().create_timer(seconds)")
        source.write_text(script.replace("func _initialize()", "func _ready()").replace("quit(","get_tree().quit("))
        (project/"BandPlaneReview.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://analysis/test_spatial_band_map.gd" id="1"]\n[node name="Review" type="Node"]\nscript = ExtResource("1")\n')
        config = project/"project.godot"
        config.write_text(config.read_text().replace("res://Main.tscn","res://BandPlaneReview.tscn"))
        binary = out/"WAVEZ-review.x86_64"
        build(godot,project,binary,out/"build-logs")
    return str(binary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot",required=True)
    parser.add_argument("--output-dir",type=Path,required=True)
    parser.add_argument("--headless",action="store_true")
    parser.add_argument("--package",action="store_true")
    parser.add_argument("--capture",type=Path)
    args = parser.parse_args()
    if args.headless and args.package: parser.error("packaged visual checks require Forward+")
    out = args.output_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    fixtures(out)
    hashes = {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob("*.wvz")}
    capture_before = args.capture.stat() if args.capture else None
    command = [package(args.godot,out) if args.package else args.godot,"--audio-driver","Dummy"]
    if not args.package: command += ["--path",str(ROOT/"viewer"),"--script","res://analysis/test_spatial_band_map.gd"]
    command += ["--headless"] if args.headless else ["--rendering-method","forward_plus","--rendering-driver","vulkan","--resolution","1440x900"]
    command += ["--","--band-map-output="+str(out)]
    if args.capture: command.append("--band-map-capture="+str(args.capture.resolve()))
    env = dict(os.environ,XDG_DATA_HOME=str(out/"data"),XDG_CONFIG_HOME=str(out/"config"),XDG_CACHE_HOME=str(out/"cache"))
    gpu = None
    with (out/"native.log").open("w") as log, (out/"gpu.csv").open("w") as gpu_log:
        if not args.headless and shutil.which("nvidia-smi"):
            gpu = subprocess.Popen(["nvidia-smi","--query-gpu=timestamp,name,memory.total,memory.used,utilization.gpu,power.draw","--format=csv","-lms","500"],stdout=gpu_log,stderr=gpu_log)
        began = time.monotonic()
        try:
            completed = subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=300)
        finally:
            if gpu is not None: gpu.terminate();gpu.wait(timeout=10)
    native = json.loads((out/"native.json").read_text()) if (out/"native.json").exists() else None
    unchanged = all(hashlib.sha256((out/name).read_bytes()).hexdigest()==digest for name,digest in hashes.items())
    if args.capture:
        after = args.capture.stat()
        unchanged &= (capture_before.st_size,capture_before.st_mtime_ns,capture_before.st_ctime_ns)==(after.st_size,after.st_mtime_ns,after.st_ctime_ns)
    log = (out/"native.log").read_text()
    report = dict(exit_code=completed.returncode,seconds=time.monotonic()-began,headless=args.headless,packaged=args.package,
        source_hashes=hashes,sources_unchanged=unchanged,result=native,
        errors=[line for line in log.splitlines() if "ERROR:" in line or "SCRIPT ERROR:" in line])
    (out/"summary.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps(dict(exit_code=completed.returncode,checks=native.get("checks") if native else None,
        failures=native.get("failures") if native else None,sources_unchanged=unchanged,output=str(out))))
    if completed.returncode or report["errors"] or not unchanged or not native or native["failures"]:raise SystemExit(1)


if __name__ == "__main__": main()

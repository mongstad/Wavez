"""Focused regional spectrum UI/worker integration, using generated fields.

Forward+ is the visual gate. --headless checks only CPU/UI state contracts.
Optional --capture adds one existing Model A review; scientific inputs stay external.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture
from tools.package_linux import stage, build


def fixtures(out):
    shape = (32, 40, 48)
    z, y, x = np.ogrid[:shape[0], :shape[1], :shape[2]]
    base = np.cos(2*np.pi*(4*x/48+3*y/40+2*z/32))
    base += .4*np.cos(2*np.pi*8*x/48)*np.ones(shape)
    geometry = dict(origin=(-6., -10., -12.), spacing=(.25, .5, .75), centering="node")
    for name in ("field", "other", "nonfinite"):
        with SceneCapture(out/(name+".wvz"), objects=[dict(id="field",kind="volume",units="dimensionless")],
                metadata={"position_unit":"dimensionless","channel_metadata":{"field":{
                    "amplitude":{"units":"dimensionless","semantic":"signed"},
                    "energy_density":{"units":"dimensionless"}}}}) as writer:
            for t in (0., 2., 4.):
                q = base*(1+t/4)+(0.5 if name == "other" else 0.)
                if name == "nonfinite":
                    q=q.copy();q[16,16,16]=np.nan
                writer.add_volume("field",t,{"amplitude":q,"energy_density":q*q},**geometry)


def package(godot, out):
    with tempfile.TemporaryDirectory(prefix="wavez-spectral-review-") as temporary:
        project=Path(temporary)/"viewer"
        inventory=stage(project)
        assert "wavez_export/analysis/spatial_spectrum.py" in inventory
        source=project/"analysis/test_spatial_spectrum.gd"
        script=source.read_text().replace("extends SceneTree", "extends Node\nvar root: Window:\n\tget: return get_tree().root\nvar process_frame: Signal:\n\tget: return get_tree().process_frame\nfunc create_timer(seconds: float) -> SceneTreeTimer:return get_tree().create_timer(seconds)")
        script=script.replace("func _initialize()", "func _ready()").replace("quit(","get_tree().quit(")
        source.write_text(script)
        (project/"SpectralReview.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://analysis/test_spatial_spectrum.gd" id="1"]\n[node name="Review" type="Node"]\nscript = ExtResource("1")\n')
        config=project/"project.godot"
        config.write_text(config.read_text().replace("res://Main.tscn","res://SpectralReview.tscn"))
        binary=out/"WAVEZ-review.x86_64"
        build(godot,project,binary,out/"build-logs")
    return str(binary)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot",required=True)
    parser.add_argument("--output-dir",type=Path,required=True)
    parser.add_argument("--headless",action="store_true")
    parser.add_argument("--package",action="store_true")
    parser.add_argument("--capture",type=Path)
    args=parser.parse_args()
    if args.headless and args.package:parser.error("packaged visual checks require Forward+")
    out=args.output_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    fixtures(out)
    hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob("*.wvz")}
    command=[package(args.godot,out) if args.package else args.godot,"--audio-driver","Dummy"]
    if not args.package:command += ["--path",str(ROOT/"viewer"),"--script","res://analysis/test_spatial_spectrum.gd"]
    command += ["--headless"] if args.headless else ["--rendering-method","forward_plus","--rendering-driver","vulkan","--resolution","1440x900"]
    command += ["--","--spectral-output="+str(out)]
    if args.capture:command.append("--spectral-capture="+str(args.capture.resolve()))
    env=dict(os.environ,XDG_DATA_HOME=str(out/"data"),XDG_CONFIG_HOME=str(out/"config"),XDG_CACHE_HOME=str(out/"cache"))
    with (out/"native.log").open("w") as log:
        completed=subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=180)
    native=json.loads((out/"native.json").read_text()) if (out/"native.json").exists() else None
    unchanged=all(hashlib.sha256((out/name).read_bytes()).hexdigest()==digest for name,digest in hashes.items())
    log=(out/"native.log").read_text()
    report=dict(exit_code=completed.returncode,headless=args.headless,packaged=args.package,
                source_hashes=hashes,sources_unchanged=unchanged,result=native,
                errors=[line for line in log.splitlines() if "ERROR:" in line or "SCRIPT ERROR:" in line])
    (out/"summary.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps(dict(exit_code=completed.returncode,checks=native.get("checks") if native else None,
                         failures=native.get("failures") if native else None,sources_unchanged=unchanged,output=str(out))))
    if completed.returncode or report["errors"] or not unchanged or not native or native["failures"]:raise SystemExit(1)


if __name__=="__main__":main()

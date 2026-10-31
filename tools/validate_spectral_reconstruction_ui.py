"""Focused source/package Forward+ validation of a pinned reconstructed volume.

Creates bounded synthetic fixtures, including an N192 cancellation workload.
An external reference is read only when --capture explicitly names it.
Strict reports retain every native error; this UI harness requires Forward+.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture
from tools.validate_spatial_band_map_ui import package
from tools.validate_spatial_band_sequence_ui import process_sample


def fixtures(out):
    z, y, x = np.ogrid[:32, :32, :32]
    low = .6*np.cos(2*np.pi*x/32+.37)*np.ones((32,32,32))
    middle = .3*np.sin(2*np.pi*(x+2*y)/32-.21)*np.ones((32,32,32))
    high = .1*np.cos(2*np.pi*(7*z)/32+.63)*np.ones((32,32,32))
    # Domain length16 gives |f|=.0625, sqrt(5)/16 and .4375 respectively.
    declaration = dict(position_unit="dimensionless", channel_metadata={
        "field":{"amplitude":{"units":"dimensionless","semantic":"signed"}}})
    for name, multiplier in [("reconstruction",1.),("replacement",2.)]:
        with SceneCapture(out/(name+".wvz"),objects=[dict(id="field",kind="volume",units="dimensionless")],metadata=declaration) as writer:
            for index in range(3):
                q=(.2+low+middle+high)*(1+index*.2)*multiplier
                writer.add_volume("field",float(index),{"amplitude":q,"other":q*q},origin=(0.,0.,0.),spacing=(.5,.5,.5),centering="node")
    np.savez_compressed(out/"known_bands.npz",original=.2+low+middle+high,low=.2+low,intermediate=middle,high=high)
    (out/"known-point.json").write_text(json.dumps({name:float(values[4,6,8]) for name,values in dict(original=.2+low+middle+high,low=.2+low,intermediate=middle,high=high).items()})+"\n")
    with SceneCapture(out/"zero.wvz",objects=[dict(id="field",kind="volume",units="dimensionless")],metadata=declaration) as writer:
        writer.add_volume("field",0.,{"amplitude":np.zeros((32,32,32),np.float64)},origin=(0.,0.,0.),spacing=(.5,.5,.5),centering="node")
    z,y,x=np.ogrid[:192,:192,:192]
    q=(np.sin(2*np.pi*x/32)+.3*np.cos(2*np.pi*(y+z)/24)).astype(np.float64)
    with SceneCapture(out/"active.wvz",objects=[dict(id="field",kind="volume",units="dimensionless")],metadata=declaration) as writer:
        writer.add_volume("field",0.,{"amplitude":q},origin=(0.,0.,0.),spacing=(1/6,1/6,1/6),centering="node")


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--godot",required=True)
    p.add_argument("--output-dir",type=Path,required=True)
    p.add_argument("--capture",type=Path)
    p.add_argument("--package",action="store_true")
    args=p.parse_args()
    out=args.output_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    fixtures(out)
    hashes={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in out.glob("*.wvz")}
    before=args.capture.stat() if args.capture else None
    command=[package(args.godot,out,"test_spectral_reconstruction.gd") if args.package else args.godot,"--audio-driver","Dummy"]
    if not args.package:command += ["--path",str(ROOT/"viewer"),"--script","res://analysis/test_spectral_reconstruction.gd"]
    command += ["--rendering-method","forward_plus","--rendering-driver","vulkan","--resolution","1440x900"]
    command += ["--","--reconstruction-output="+str(out)]
    if args.capture:command += ["--reconstruction-capture="+str(args.capture.resolve())]
    env=dict(os.environ,XDG_DATA_HOME=str(out/"data"),XDG_CONFIG_HOME=str(out/"config"),XDG_CACHE_HOME=str(out/"cache"))
    began=time.monotonic();samples=[];gpu=None
    with (out/"native.log").open("w") as log,(out/"gpu.csv").open("w") as glog:
        if shutil.which("nvidia-smi"):
            gpu=subprocess.Popen(["nvidia-smi","--query-gpu=timestamp,name,memory.total,memory.used,utilization.gpu,power.draw","--format=csv","-lms","250"],stdout=glog,stderr=glog)
        proc=subprocess.Popen(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
        try:
            while proc.poll() is None:
                sample=process_sample(proc.pid)
                if sample:samples.append(sample)
                if time.monotonic()-began>600:proc.kill();raise TimeoutError("Reconstruction validation exceeded600s")
                time.sleep(.1)
        finally:
            if proc.poll() is None:proc.kill()
            proc.wait()
            if gpu is not None:gpu.terminate();gpu.wait(timeout=10)
    native=json.loads((out/"native.json").read_text()) if (out/"native.json").exists() else None
    unchanged=all(hashlib.sha256((out/name).read_bytes()).hexdigest()==digest for name,digest in hashes.items())
    if args.capture:
        after=args.capture.stat();unchanged &= (before.st_size,before.st_mtime_ns,before.st_ctime_ns)==(after.st_size,after.st_mtime_ns,after.st_ctime_ns)
    errors=[s for s in (out/"native.log").read_text().splitlines() if "ERROR:" in s or "SCRIPT ERROR:" in s]
    report=dict(exit_code=proc.returncode,elapsed_seconds=time.monotonic()-began,packaged=args.package,headless=False,
        source_hashes=hashes,sources_unchanged=unchanged,result=native,errors=errors,viewer_process_samples=samples,
        measurement_note="Process RSS/CPU includes startup, worker coordination and all interactions. GPU CSV is whole-device including desktop; native engine counters and matched frame windows provide incremental estimates, not process-isolated VRAM certification.")
    report["validation_exit_code"]=int(bool(proc.returncode or errors or not unchanged or not native or native["failures"]))
    (out/"summary.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps(dict(exit_code=proc.returncode,checks=native.get("checks") if native else None,failures=native.get("failures") if native else None,
        errors=len(errors),validation_exit_code=report["validation_exit_code"],sources_unchanged=unchanged,output=str(out))))
    return report["validation_exit_code"]


if __name__=="__main__":raise SystemExit(main())

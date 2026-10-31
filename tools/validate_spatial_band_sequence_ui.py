"""Focused source/package validation for selected native-time spectral replay.

All synthetic files and cache entries are disposable. The optional signed N192
capture is opened read-only. Strict validation retains all native diagnostics.
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
from tools.validate_spatial_band_map_ui import full_complex_band, package


def fixtures(out):
    shape = (48, 48, 48)
    spacing, origin = (.25, .375, .5), (-6., -9., -12.)
    z, y, x = np.ogrid[:48, :48, :48]
    envelope = 1.+.55*np.sin(2*np.pi*y/48)+.35*x/48
    base = envelope*np.cos(2*np.pi*x/8)*np.ones(shape)+.3*np.cos(2*np.pi*(y+z)/6)*np.ones(shape)
    arrays = [base, 2*base, envelope*np.cos(2*np.pi*x/4)*np.ones(shape), 3*base]
    declaration = dict(position_unit="dimensionless",channel_metadata={"field":{"amplitude":{"units":"dimensionless","semantic":"signed"}}})
    golden = []
    for name in ("sequence", "other"):
        with SceneCapture(out/(name+".wvz"),objects=[dict(id="field",kind="volume",units="dimensionless")],metadata=declaration) as writer:
            for index, q in enumerate(arrays):
                writer.add_volume("field",float(index*2),{"amplitude":q*(2 if name=="other" else 1)},origin=origin,spacing=spacing,centering="node")
    for index,q in enumerate(arrays):
        centers=[]
        for row in range(5):
            for col in range(5):
                start=[16,-8+row*12,-8+col*12]
                valid=all(0 <= v <= 32 for v in start)
                region=q[tuple(slice(v,v+16) for v in start)] if valid else None
                centers.append(dict(row=row,column=col,power=full_complex_band(region,spacing,.4,.8) if valid else None))
        golden.append(dict(index=index,time=index*2,measurements=centers))
    (out/"golden.json").write_text(json.dumps(golden,indent=2)+"\n")
    z,y,x=np.ogrid[:128,:160,:160]
    q=(np.sin(2*np.pi*x/16)+.3*np.cos(2*np.pi*(y+z)/24)).astype(np.float32)
    with SceneCapture(out/"active-sequence.wvz",objects=[dict(id="field",kind="volume",units="dimensionless")],metadata=declaration) as writer:
        for index in range(3):
            writer.add_volume("field",float(index),{"amplitude":q*(index+1)},origin=(0.,0.,0.),spacing=(1.,1.,1.),centering="node")


def process_sample(pid):
    try:
        stat=Path(f"/proc/{pid}/stat").read_text().rsplit(")",1)[1].split()
        status=Path(f"/proc/{pid}/status").read_text().splitlines()
        values={line.split()[0].rstrip(":"):int(line.split()[1])*1024 for line in status if line.startswith(("VmRSS:","VmHWM:"))}
        return dict(monotonic=time.monotonic(),cpu_seconds=(int(stat[11])+int(stat[12]))/os.sysconf("SC_CLK_TCK"),**values)
    except (OSError,ValueError,IndexError): return None


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot",required=True)
    parser.add_argument("--output-dir",type=Path,required=True)
    parser.add_argument("--package",action="store_true")
    parser.add_argument("--headless",action="store_true")
    parser.add_argument("--capture",type=Path)
    args=parser.parse_args()
    if args.headless and args.package: parser.error("package checks require Forward+")
    out=args.output_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    fixtures(out)
    hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob("*.wvz")}
    before=args.capture.stat() if args.capture else None
    command=[package(args.godot,out,"test_spectral_sequence.gd") if args.package else args.godot,"--audio-driver","Dummy"]
    if not args.package: command += ["--path",str(ROOT/"viewer"),"--script","res://analysis/test_spectral_sequence.gd"]
    command += ["--headless"] if args.headless else ["--rendering-method","forward_plus","--rendering-driver","vulkan","--resolution","1440x900"]
    command += ["--","--band-map-output="+str(out)]
    if args.capture:command.append("--band-map-capture="+str(args.capture.resolve()))
    env=dict(os.environ,XDG_DATA_HOME=str(out/"data"),XDG_CONFIG_HOME=str(out/"config"),XDG_CACHE_HOME=str(out/"cache"))
    samples=[];gpu=None;began=time.monotonic()
    with (out/"native.log").open("w") as log,(out/"gpu.csv").open("w") as gpu_log:
        if not args.headless and shutil.which("nvidia-smi"):
            gpu=subprocess.Popen(["nvidia-smi","--query-gpu=timestamp,name,memory.total,memory.used,utilization.gpu,power.draw","--format=csv","-lms","500"],stdout=gpu_log,stderr=gpu_log)
        process=subprocess.Popen(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
        try:
            while process.poll() is None:
                sample=process_sample(process.pid)
                if sample:samples.append(sample)
                if time.monotonic()-began>420:
                    process.kill();raise TimeoutError("Native sequence validation exceeded420s")
                time.sleep(.2)
        finally:
            if process.poll() is None:process.kill()
            process.wait()
            if gpu is not None:gpu.terminate();gpu.wait(timeout=10)
    native=json.loads((out/"native.json").read_text()) if (out/"native.json").exists() else None
    unchanged=all(hashlib.sha256((out/name).read_bytes()).hexdigest()==digest for name,digest in hashes.items())
    if args.capture:
        after=args.capture.stat();unchanged &= (before.st_size,before.st_mtime_ns,before.st_ctime_ns)==(after.st_size,after.st_mtime_ns,after.st_ctime_ns)
    errors=[line for line in (out/"native.log").read_text().splitlines() if "ERROR:" in line or "SCRIPT ERROR:" in line]
    report=dict(exit_code=process.returncode,seconds=time.monotonic()-began,packaged=args.package,headless=args.headless,
        source_hashes=hashes,sources_unchanged=unchanged,result=native,errors=errors,viewer_process_samples=samples,
        viewer_measurement_note="Process CPU/RSS includes import/startup and all test interactions; NVIDIA samples are whole-device including desktop. Per-phase render CPU/GPU/frame timings are native observations.")
    report["validation_exit_code"]=int(bool(process.returncode or errors or not unchanged or not native or native["failures"]))
    (out/"summary.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps(dict(exit_code=process.returncode,checks=native.get("checks") if native else None,failures=native.get("failures") if native else None,errors=len(errors),validation_exit_code=report["validation_exit_code"],sources_unchanged=unchanged,output=str(out))))
    return report["validation_exit_code"]

if __name__=="__main__":raise SystemExit(main())

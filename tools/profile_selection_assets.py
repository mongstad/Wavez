"""Bounded exact-cohort publication profile, separate from the idle G3 baseline."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

import numpy as np

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from simscope_export import SceneCapture


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot",required=True);parser.add_argument("--output-dir",type=Path,required=True)
    parser.add_argument("--count",type=int,default=100000)
    parser.add_argument("--renderer",choices=["headless","gl_compatibility","forward_plus"],default="headless")
    args=parser.parse_args()
    if not 65<=args.count<=1000000:parser.error("Count must be 65..1000000")
    out=args.output_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    ids=np.arange(args.count,dtype="i8")+2**53+1;ids[-1]=2**63-1
    row=np.arange(args.count);positions=np.column_stack((row%1000*.1,row//1000*.1,np.zeros(args.count)))
    path=out/"fixture.ssc"
    with SceneCapture(path,objects=[dict(id="p",kind="particles",units="m",identity="persistent_i8")]) as writer:
        writer.add_particles("p",0,positions,ids=ids)
        writer.add_particles("p",1,positions[::-1]+[1.,0,0],ids=ids[::-1])
    before=hashlib.sha256(path.read_bytes()).hexdigest()
    (out/"config.json").write_text(json.dumps(dict(count=args.count)))
    command=[args.godot,"--path",str(ROOT/"viewer"),"--audio-driver","Dummy","--log-file",str(out/"godot.log")]
    command += ["--headless"] if args.renderer=="headless" else ["--rendering-method",args.renderer,"--resolution","960x720"]
    command += ["--script","selection/profile_assets.gd","--","--asset-profile="+str(out)]
    try:result=subprocess.run(command,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=150)
    except subprocess.TimeoutExpired as exc:
        output=exc.stdout or b"";result=subprocess.CompletedProcess(command,124,output.decode(errors="replace") if isinstance(output,bytes) else output)
    (out/"stdout.log").write_text(result.stdout);print(result.stdout)
    report=json.loads((out/"profile.json").read_text()) if (out/"profile.json").exists() else {}
    asset_valid=False
    if report:
        ref=report["definition"]["selector"]["ids_asset"]
        data=(Path(report["member_directory"])/(ref["sha256"]+".i8")).read_bytes()
        asset_valid=hashlib.sha256(data).hexdigest()==ref["sha256"] and data==ids.astype("<i8").tobytes()
    preserved=before==hashlib.sha256(path.read_bytes()).hexdigest()
    summary=dict(command=command,exit_code=result.returncode,source_sha256=before,source_unchanged=preserved,
                 full_member_bytes_exact=asset_valid,failures=report.get("failures"),count=args.count,
                 stages=report.get("profile",{}).get("stages"),worker_results=report.get("worker_results"),
                 end_to_end_ms=report.get("end_to_end_ms"),preview_gpu_bytes=report.get("preview_gpu_bytes"))
    (out/"summary.json").write_text(json.dumps(summary,indent=2))
    return 0 if result.returncode==0 and "ERROR:" not in result.stdout and preserved and asset_valid and report and not report["failures"] else 1


if __name__=="__main__":raise SystemExit(main())

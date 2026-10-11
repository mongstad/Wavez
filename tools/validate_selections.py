"""Synthetic viewer/worker selection integration; optional actual renderer image."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from tests.g4.fixtures import scene


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot",required=True)
    parser.add_argument("--output-dir",type=Path,required=True)
    parser.add_argument("--renderer",choices=["headless","forward_plus"],default="headless")
    parser.add_argument("--derived",action="store_true",help="Also exercise a real G3 extracted artifact (requires optional scikit-image)")
    args=parser.parse_args();out=args.output_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    path=scene(out/"fixture.wvz");before=hashlib.sha256(path.read_bytes()).hexdigest()
    if args.derived:
        from tools.extract_surface import extract
        result=extract(dict(source=str(path),extent=path.stat().st_size,sha256=before,object="field",index=0,channel="value",threshold=14.,cache=str(out/"surface")))
        (out/"derived.json").write_text(json.dumps(result))
    command=[args.godot,"--path",str(ROOT/"viewer"),"--audio-driver","Dummy","--log-file",str(out/"godot.log")]
    command += ["--headless"] if args.renderer=="headless" else ["--rendering-method",args.renderer,"--resolution","1100x820"]
    command += ["--script","selection/test_selection.gd","--","--selection-fixture="+str(out)]
    began=time.monotonic();timed_out=False
    try:result=subprocess.run(command,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=90)
    except subprocess.TimeoutExpired as exc:
        timed_out=True;output=exc.stdout or b""
        result=subprocess.CompletedProcess(command,124,output.decode(errors="replace") if isinstance(output,bytes) else output)
    (out/"stdout.log").write_text(result.stdout);print(result.stdout)
    report=dict(command=command,exit_code=result.returncode,timed_out=timed_out,seconds=time.monotonic()-began,
                source_unchanged=before==hashlib.sha256(path.read_bytes()).hexdigest(),source_sha256=before,
                category="headless integration" if args.renderer=="headless" else "actual renderer integration; image requires inspection",
                result=json.loads((out/"selection.json").read_text()) if (out/"selection.json").exists() else None)
    (out/"report.json").write_text(json.dumps(report,indent=2))
    return 0 if result.returncode==0 and "ERROR:" not in result.stdout and report["source_unchanged"] and report["result"] and not report["result"]["failures"] else 1


if __name__=="__main__":raise SystemExit(main())

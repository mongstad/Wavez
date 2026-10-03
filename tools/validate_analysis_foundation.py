"""Small synthetic G4a source/protocol gate. Headless is not image acceptance."""

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
from wavez_export.analysis.contracts import float_token
from wavez_export.analysis.sampling import bracket


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--godot",required=True)
    p.add_argument("--output-dir",type=Path,required=True)
    a=p.parse_args();out=a.output_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    source=scene(out/"fixture.wvz")
    before=hashlib.sha256(source.read_bytes()).hexdigest()
    cases=[]
    for times,static in [([0,.1,1.],False),([1,3],False),([5],True),([],False)]:
        for requested in [-1,0,.05,.1,.55,1,2,3,5,6]:
            cases.append(dict(times=[float_token(t) for t in times],static=static,time=float_token(requested),
                              expected=bracket([dict(time=t) for t in times],requested,static=static)))
    (out/"golden.json").write_text(json.dumps(dict(cases=cases,ids=[str(i) for i in [0,2**24+1,2**53+1,2**63-1]]),allow_nan=False))
    command=[a.godot,"--headless","--path",str(ROOT/"viewer"),"--audio-driver","Dummy","--log-file",str(out/"godot.log"),
             "--script","analysis/test_foundation.gd","--","--foundation="+str(out)]
    start=time.monotonic()
    timed_out=False
    try:
        result=subprocess.run(command,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=40)
    except subprocess.TimeoutExpired as exc:
        timed_out=True
        output=exc.stdout or b""
        result=subprocess.CompletedProcess(command,124,output.decode(errors="replace") if isinstance(output,bytes) else output)
    (out/"stdout.log").write_text(result.stdout);print(result.stdout)
    after=hashlib.sha256(source.read_bytes()).hexdigest()
    report=dict(command=command,exit_code=result.returncode,timed_out=timed_out,seconds=time.monotonic()-start,source_sha256=before,
                source_unchanged=before==after,code_revision=subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
                source_files={str(f.relative_to(ROOT)):hashlib.sha256(f.read_bytes()).hexdigest()
                              for folder in [ROOT/"wavez_export/analysis",ROOT/"viewer/analysis"] for f in folder.glob("*") if f.is_file()},
                result=json.loads((out/"godot.json").read_text()) if (out/"godot.json").exists() else None)
    (out/"report.json").write_text(json.dumps(report,indent=2))
    return 0 if result.returncode==0 and "ERROR:" not in result.stdout and before==after and report["result"] and not report["result"]["failures"] else 1


if __name__=="__main__":raise SystemExit(main())

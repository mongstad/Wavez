"""Small-count-of-records, multi-chunk G3 writer/Godot interoperability."""
import argparse,hashlib,json,subprocess,sys
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
from wavez_export import SceneCapture
from wavez_export.analysis.contracts import float_token


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("--godot",required=True);parser.add_argument("--output-dir",required=True,type=Path)
    args=parser.parse_args();out=args.output_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    count=400003;p=np.arange(count*3,dtype="f4").reshape(count,3);v=(p.astype("f8")+1e-8)/3
    locations=[0,1,524287,524288,524289,1048575,1048576,count*3-1]
    expected=[];hashes={}
    for codec in ("none","zstd"):
        path=out/(codec+".ssc")
        with SceneCapture(path,objects=[dict(id="p",kind="particles",units="m",identity="anonymous")],compression=codec) as writer:
            writer.add_particles("p",0,p,velocity=v);writer.add_particles("p",1,p[::-1],velocity=v[::-1])
        hashes[str(path)]=hashlib.sha256(path.read_bytes()).hexdigest()
        for index,values in [(0,v),(1,v[::-1])]:
            expected.append(dict(path=str(path),index=index,count=count,values=[dict(index=i,value=float_token(values.reshape(-1)[i])) for i in locations]))
    (out/"expected.json").write_text(json.dumps(expected))
    command=[args.godot,"--headless","--path",str(ROOT/"viewer"),"--audio-driver","Dummy","--log-file",str(out/"godot.log"),"--script","analysis/test_multichunk.gd","--","--chunks-fixture="+str(out)]
    result=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=60)
    (out/"stdout.log").write_text(result.stdout);print(result.stdout)
    intact=all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==sha for p,sha in hashes.items())
    report=dict(exit_code=result.returncode,source_hashes=hashes,source_unchanged=intact,result=json.loads((out/"checks.json").read_text()) if (out/"checks.json").exists() else None)
    (out/"report.json").write_text(json.dumps(report,indent=2))
    return 0 if result.returncode==0 and intact and "ERROR:" not in result.stdout and report["result"] and not report["result"]["failures"] else 1


if __name__=="__main__":raise SystemExit(main())

"""Isolated G3 file write/read/ratio/RSS benchmark; cached filesystem, no fsync claim."""
import argparse,json,os,resource,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
from simscope_export import SceneCapture,SceneReader
OUT=ROOT/'results/g3'

def run(mode):
    source=OUT/'scene-demo.ssc';target=OUT/('benchmark-'+mode+'.ssc');began=time.perf_counter();raw=0;records=0
    if mode in ('none','zstd'):
        if target.exists():target.unlink() # this tool's own disposable benchmark outputs only
        with SceneReader(source,cache_bytes=0) as r,SceneCapture(target,objects=r.metadata['objects'],metadata={'simulation_name':'G3 benchmark'},compression=mode) as w:
            for row in r.records:
                id=row['object'];i=r.samples[id].index(row);a=r.read_sample(id,i);raw+=sum(v.nbytes for v in a.values());records+=1
                spec={v['name']:v['association'] for v in row['descriptor']['arrays']};w._add(id,row['time'],a,spec,row['descriptor']['geometry'])
        size=target.stat().st_size
    else:
        source=OUT/('benchmark-'+mode.removeprefix('read-')+'.ssc');size=source.stat().st_size
        with SceneReader(source,cache_bytes=0) as r:
            for id in r.objects:
                for i in range(len(r.samples[id])):
                    a=r.read_sample(id,i);raw+=sum(v.nbytes for v in a.values());records+=1
    elapsed=time.perf_counter()-began
    return dict(mode=mode,seconds=elapsed,raw_bytes=raw,file_bytes=size,raw_to_file_ratio=raw/size,decoded_mib_s=raw/elapsed/1048576,records=records,peak_rss_mib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss/1024)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--mode');a=p.parse_args()
    if a.mode:print(json.dumps(run(a.mode)))
    else:
        rows=[]
        for mode in ('none','zstd','read-none','read-zstd'):
            result=subprocess.run([sys.executable,__file__,'--mode',mode],capture_output=True,text=True,check=True,env=dict(os.environ,OPENBLAS_NUM_THREADS='1'));rows.append(json.loads(result.stdout));print(result.stdout.strip(),flush=True)
        (OUT/'storage-benchmark.json').write_text(json.dumps(rows,indent=2))

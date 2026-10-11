"""Real-callback Forward+ end-of-playback phases plus whole-device NVIDIA telemetry."""
import argparse,json,os,subprocess,time,statistics,sys,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from tools.profile_parallel_preparation import identity,process_sample


def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--godot',required=True);p.add_argument('--capture',type=Path,required=True);p.add_argument('--output-dir',type=Path,required=True)
 p.add_argument('--viewer',type=Path,default=ROOT/'viewer');p.add_argument('--end-seconds',type=float,default=120.);p.add_argument('--resolution',default='1920x1080')
 a=p.parse_args()
 if not math.isfinite(a.end_seconds) or a.end_seconds<=0:p.error("end-seconds must be finite and positive")
 out=a.output_dir.resolve();out.mkdir(parents=True,exist_ok=False);source=a.capture.resolve();before=identity(source)
 cmd=[a.godot,'--path',str(a.viewer.resolve()),'--rendering-method','forward_plus','--resolution',a.resolution,'--audio-driver','Dummy','--script',str(ROOT/'viewer/layers/profile_end_gpu.gd'),'--',str(source),str(out/'trace.jsonl'),str(a.end_seconds)]
 (out/'command.json').write_text(json.dumps(cmd,indent=2)+'\n')
 rows=[];started=time.monotonic();phase='open';position=0
 with (out/'native.log').open('w') as log:
  process=subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,XDG_DATA_HOME=str(out/'data'),XDG_CONFIG_HOME=str(out/'config')))
  try:
   while process.poll() is None:
    if time.monotonic()-started>900:raise TimeoutError('End GPU profile')
    with (out/'native.log').open() as progress:
     progress.seek(position)
     for line in progress:
      if line.startswith('PHASE '):phase=line.strip()[6:];print(line.strip(),flush=True)
     position=progress.tell()
    row=dict(seconds=time.monotonic()-started,phase=phase)
    try:row.update(process_sample(process.pid))
    except (FileNotFoundError,ProcessLookupError):pass
    reading=subprocess.run(['nvidia-smi','--query-gpu=utilization.gpu,power.draw,clocks.gr,clocks.mem,memory.used','--format=csv,noheader,nounits'],capture_output=True,text=True,timeout=5)
    try:row.update(zip(['gpu_percent','power_w','graphics_mhz','memory_mhz','gpu_mib'],map(float,reading.stdout.splitlines()[0].split(', '))))
    except (IndexError,ValueError):row['gpu_error']=reading.stderr.strip()
    rows.append(row);time.sleep(.5)
  finally:
   if process.poll() is None:process.kill();process.wait()
   (out/'telemetry.json').write_text(json.dumps(rows,indent=2)+'\n')
 trace=[json.loads(s) for s in (out/'trace.jsonl').read_text().splitlines()];phases={}
 for name in sorted({r['phase'] for r in rows}):
  rs=[r for r in rows if r['phase']==name];stable=[r for r in rs if r['seconds']>=rs[0]['seconds']+2]
  samples=[r for r in trace if r.get('event')=='sample' and r['phase']==name]
  phases[name]=dict(telemetry_samples=len(stable),gpu_mean=statistics.mean(r['gpu_percent'] for r in stable) if stable else None,gpu_min=min((r['gpu_percent'] for r in stable),default=None),gpu_max=max((r['gpu_percent'] for r in stable),default=None),power_w_mean=statistics.mean(r['power_w'] for r in stable) if stable else None,peak_rss=max((r.get('VmRSS',0) for r in rs),default=0),swap=max((r.get('VmSwap',0) for r in rs),default=0),draw_fps_mean=statistics.mean(r['draw_fps'] for r in samples[2:]) if len(samples)>2 else None,first=samples[0] if samples else None,last=samples[-1] if samples else None)
 summary=dict(exit_code=process.returncode,source_identity=before,source_metadata_unchanged=before==identity(source),final=trace[-1],phases=phases,scope='GPU telemetry is whole-device including desktop; per-viewport GPU timing is Godot measurement. One sequential fresh-process run, uncontrolled OS cache/desktop, no forced draws/manual ticks. Source stat identity, not full payload hash.')
 (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
 print(json.dumps({k:{x:v[x] for x in ['gpu_mean','gpu_min','gpu_max','draw_fps_mean','peak_rss','swap']} for k,v in phases.items()},indent=2))
 if process.returncode or not summary['source_metadata_unchanged'] or 'ERROR:' in (out/'native.log').read_text():raise SystemExit(1)


if __name__=='__main__':main()

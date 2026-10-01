"""F10: eviction-heavy worker scans/seeks/exports/restarts with measured resources."""
import argparse,hashlib,json,os,random,subprocess,sys,time
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
from wavez_export import SceneCapture
from wavez_export.analysis import SourceSnapshot,selectors as S


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output-dir',type=Path,required=True);parser.add_argument('--cycles',type=int,default=30);args=parser.parse_args()
    if not 10<=args.cycles<=100:parser.error('Use 10–100 lifecycle cycles')
    out=args.output_dir.resolve();out.mkdir(parents=True,exist_ok=False);path=out/'long.ssc';checks=[];samples=[];process=None;worker=None;serial=0
    with SceneCapture(path,objects=[dict(id='p',kind='particles',units='m',identity='persistent_i8')],metadata=dict(time_unit='s',position_unit='m'),compression='zstd') as writer:
        ids=np.arange(64,dtype='i8')+2**53+1
        for n in range(512):
            order=np.roll(np.arange(64),n%64);x=order*.01
            writer.add_particles('p',n*.125,np.column_stack((x+n*.001,x*0,x*0)),ids=ids[order],value=order.astype('f8')+n*.125)
    before=hashlib.sha256(path.read_bytes()).hexdigest()
    with SourceSnapshot(path) as source:
        ref=source.identity();selection=S.define(source,dict(key='population',object='p',kind='roi',selector=dict(shape='box',lower=[-2]*3,upper=[2]*3)))
    def check(value,label):
        checks.append(dict(label=label,pass_=bool(value)))
        if not value:raise AssertionError(label)
    def write(name,data):
        target=worker/name;temporary=target.with_suffix('.new');temporary.write_text(json.dumps(data));os.replace(temporary,target)
    def wait(name,predicate,timeout=30):
        end=time.monotonic()+timeout
        while time.monotonic()<end:
            write('lease.json',dict(owner=os.getpid()))
            try:
                value=json.loads((worker/name).read_text())
                if predicate(value):return value
            except (OSError,ValueError):pass
            if process.poll() is not None:raise RuntimeError('Worker unexpectedly exited')
            time.sleep(.01)
        raise TimeoutError(name)
    def send(operation,arguments,background=False,budget=None,pins=None):
        nonlocal serial
        serial+=1;id='lifecycle-'+str(serial);request=dict(version=1,id=id,scene_revision=1,selection_revision=1,source=ref,operation=operation,arguments=arguments,budget=budget or {},member_pins=[],result_pins=pins or [])
        write('background_request.json' if background else 'request.json',request);start=time.monotonic()
        reply=wait('background_result.json' if background else 'result.json',lambda r:r.get('id')==id)
        reply['latency_seconds']=time.monotonic()-start;return reply
    def memory(pid):
        result={}
        for line in Path(f'/proc/{pid}/status').read_text().splitlines():
            if line.startswith(('VmRSS:','VmHWM:','VmSize:')):key,value,_=line.split();result[key[:-1]]=int(value)*1024
        result['fds']=len(list(Path(f'/proc/{pid}/fd').iterdir()));return result
    report=dict(status='in_progress',cycles=args.cycles,checks=checks,samples=samples,source=str(path),source_sha256=before,quota_bytes=8*1024**2)
    rng=random.Random(715)
    try:
        for cycle in range(args.cycles):
            if cycle%10==0:
                if process is not None:
                    pid=process.pid;write('close',{});process.wait(timeout=3);check(not Path(f'/proc/{pid}').exists(),f'cycle {cycle} old worker reaped')
                worker=out/'registry'/('owner-'+str(cycle));worker.mkdir(parents=True);write('lease.json',dict(owner=os.getpid()))
                process=subprocess.Popen([sys.executable,str(ROOT/'tests/g4/lifecycle_worker.py'),str(worker),str(os.getpid()),str(out/'registry/owner-0/members')],cwd=ROOT,stdout=(worker/'stdout.log').open('w'),stderr=subprocess.STDOUT)
                wait('ready.json',lambda r:r.get('pid')==process.pid)
            for query in range(3):
                index=rng.randrange(512);reply=send('sample',dict(object='p',index=index,channels=['value'],ids=[str(2**53+1)]))
                check(reply['ok'] and float(reply['data']['rows'][0]['channels']['value']['exact']['text'])==index*.125,f'cycle {cycle} random seek {query} exact source ID/value')
            request=dict(selections=[selection],mode='statistics',channels=[dict(channel='value')],metrics=['count','mean','stddev'],range=dict(axis='native_time',start=0,end=63.875),result_bytes=4*1024**2)
            reply=send('analyze',request,True);check(reply['ok'] and reply['data']['row_count']==1536,f'cycle {cycle} all native statistics rows')
            reference=reply['data']['result'];page=send('result_page',dict(result=reference,offset=0,limit=3))
            values={r['statistic']:r['value'] for r in page['data']['rows']}
            check(values['count']=='64' and float(values['mean'])==31.5,f'cycle {cycle} independent population/mean oracle')
            check(reply['metrics']['charged_bytes']==0 and reply['shared_memory']['used']==0,f'cycle {cycle} allocation leases released')
            if cycle%5==0:
                exported=send('export_analysis',dict(result=reference,destination=str(out/('export-'+str(cycle))),quota_bytes=8*1024**2),True,pins=[reference])
                check(exported['ok'] and int(exported['data']['export']['row_count'])==1536,f'cycle {cycle} complete numerical export')
            if cycle%7==0:
                limited=send('analyze',request,True,budget=dict(memory_bytes=1024**2),pins=[reference])
                check(not limited['ok'] and limited['code']=='memory_limit',f'cycle {cycle} low memory explicitly refused')
                limited=send('export_analysis',dict(result=reference,destination=str(out/('refused-'+str(cycle))),quota_bytes=1024**2),True,pins=[reference])
                check(not limited['ok'] and not (out/('refused-'+str(cycle))).exists(),f'cycle {cycle} insufficient export quota never publishes')
            cache_dirs=list((out/'registry/owner-0/results').iterdir());usage=sum(max(4096,p.stat().st_size) for d in cache_dirs for p in d.iterdir())
            check(len(cache_dirs)<=2 and usage<=8*1024**2,f'cycle {cycle} cache eviction bounds')
            samples.append(dict(cycle=cycle,pid=process.pid,**memory(process.pid),result_directories=len(cache_dirs),result_bytes=usage,scan_seconds=reply['latency_seconds'],scan_metrics=reply['metrics'],memo=reply['verification_memo']))
        rss=[s['VmRSS'] for s in samples];check(max(rss)<768*1024**2,'actual worker RSS remains below declared 768 MiB test envelope')
        for start in range(0,args.cycles,10):
            batch=samples[start:min(start+10,args.cycles)]
            if len(batch)>=5:check(batch[-1]['VmRSS']-batch[3]['VmRSS']<32*1024**2,f'worker epoch {start} warm RSS growth below 32 MiB')
        check(max(s['fds'] for s in samples)-min(s['fds'] for s in samples)<=4,'file descriptors remain bounded')
        pid=process.pid;write('close',{});process.wait(timeout=3);check(not Path(f'/proc/{pid}').exists(),'final worker reaped')
        check(hashlib.sha256(path.read_bytes()).hexdigest()==before,'source checksum unchanged after all cycles')
        report.update(status='PASS',peak_rss=max(rss),peak_result_bytes=max(s['result_bytes'] for s in samples),peak_fds=max(s['fds'] for s in samples))
    except BaseException as exc:report.update(status='FAIL',error=type(exc).__name__+': '+str(exc));raise
    finally:
        if process is not None and process.poll() is None:
            write('close',{})
            try:process.wait(timeout=3)
            except subprocess.TimeoutExpired:process.kill();process.wait()
        (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'G4 lifecycle: {len(checks)} checks PASS, {args.cycles} cycles, peak RSS {report["peak_rss"]/1024**2:.1f} MiB')


if __name__=='__main__':main()

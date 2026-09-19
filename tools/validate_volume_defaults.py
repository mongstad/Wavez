"""Read-only real-capture volume review; produces local statistics/render evidence."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import numpy as np
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from simscope_export import SceneReader


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--renderer', choices=['forward_plus','gl_compatibility'], default='forward_plus')
    args = parser.parse_args();source = args.capture.resolve();out = args.output_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    before = digest(source)
    with SceneReader(source,cache_bytes=0) as reader:
        volumes = [key for key,obj in reader.objects.items() if obj['kind']=='volume']
        assert len(volumes)==1, 'Review one declared volume per run'
        field = volumes[0];rows = reader.samples[field];stats=[]
        for index,row in enumerate(rows):
            channels=reader.read_sample(field,index);record=dict(index=index,time=row['time'],channels={})
            geometry=row['descriptor']['geometry'];shape=np.array(geometry['shape']);grid=shape[::-1]//2
            data_point=np.array(geometry['origin'])+grid*np.array(geometry['spacing'])
            transform=np.array(reader.objects[field]['data_to_world']).reshape(3,4)
            world=(transform[:,:3]@data_point+transform[:,3]).tolist()
            for name,values in channels.items():
                finite=values[np.isfinite(values)]
                record['channels'][name]=dict(shape=list(values.shape),dtype=str(values.dtype),sha256=hashlib.sha256(values.tobytes()).hexdigest(),nonfinite=int(values.size-finite.size),quantiles=dict(zip(['min','p50','p90','p99','p999','max'],np.quantile(finite,[0,.5,.9,.99,.999,1]).tolist())),negative_fraction=float((finite<0).mean()),above_one_fraction=float((finite>1).mean()),probe_world=world,probe_value=float(values[tuple(grid[::-1])]))
            stats.append(record)
        assert all(name in stats[0]['channels'] for name in ['density','psi_real','psi_imag'])
        metadata=dict(objects=reader.objects,cadences={key:[row['time'] for row in rows] for key,rows in reader.samples.items()},geometry=geometry)
    peak=max(stats,key=lambda row:row['channels']['density']['quantiles']['max']);last=stats[-1]
    def case(name,row,channel='density',preset='Scientific',particles=False,**changes):
        return dict(name=name,time=row['time'],channel=channel,preset=preset,particles=particles,changes=changes,oracle=row['channels'][channel])
    cases=[dict(name='opening',time=stats[0]['time'],oracle=stats[0]['channels']['density']),
           case('initial-scientific',stats[0],particles=True),case('initial-cinematic',stats[0],preset='Cinematic',particles=True),
           case('peak-default',peak),case('peak-source-range',peak,upper=peak['channels']['density']['quantiles']['max']),
           case('late-layered',last,particles=True),case('late-default',last),
           case('late-p99-range',last,upper=last['channels']['density']['quantiles']['p99']),
           case('late-opacity-1',last,opacity=1.),case('late-step-quarter',last,step=.25),case('late-step-one',last,step=1.),
           case('late-cinematic',last,preset='Cinematic')]
    for channel in ['psi_real','psi_imag']:
        q=last['channels'][channel]['quantiles'];bound=max(abs(q['min']),abs(q['max']))
        cases += [case(channel+'-default',last,channel),case(channel+'-symmetric',last,channel,lower=-bound,upper=bound,colormap='coolwarm')]
    job=dict(capture=str(source),field=field,cases=cases,output=str(out))
    (out/'job.json').write_text(json.dumps(job))
    env=os.environ.copy();env.update(XDG_DATA_HOME=str(out/'userdata'),XDG_CONFIG_HOME=str(out/'config'))
    for name,command in [('import',[args.godot,'--headless','--path',str(ROOT/'viewer'),'--editor','--import']),('review',[args.godot,'--path',str(ROOT/'viewer'),'--rendering-method',args.renderer,'--resolution','960x640','--audio-driver','Dummy','--script','res://layers/review_volume_defaults.gd','--','--review-job='+str(out/'job.json')])]:
        result=subprocess.run(command,cwd=ROOT,env=env,text=True,capture_output=True,timeout=240)
        text=result.stdout+result.stderr;(out/(name+'.log')).write_text(text)
        assert result.returncode==0 and 'ERROR:' not in text and 'WARNING:' not in text,text[-5000:]
    assert digest(source)==before,'Source capture changed'
    report=json.loads((out/'render-report.json').read_text())
    assert not report['failures'],report['failures']
    report.update(source_file=source.name,source_bytes=source.stat().st_size,source_sha256_unchanged=before,source_metadata=metadata,source_statistics=stats)
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'{args.renderer}: {report["checks"]} checks PASS; {len(cases)} visual cases; source hash unchanged')


if __name__=='__main__':main()

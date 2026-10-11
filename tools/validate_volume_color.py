"""Volume color-policy, GPU, recipe and export regression; optional read-only real capture."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import numpy as np
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture, SceneReader
from tools.validate_volume_opacity import run_native, digest


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot', required=True)
    p.add_argument('--renderer', choices=['forward_plus'], required=True)
    p.add_argument('--output-dir', type=Path, required=True)
    p.add_argument('--real-capture', type=Path)
    a = p.parse_args();out = a.output_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    env=os.environ.copy();env.update(XDG_DATA_HOME=str(out/'userdata'),XDG_CONFIG_HOME=str(out/'config'))
    source=out/'color.wvz'
    if a.real_capture:source=a.real_capture.resolve()
    else:
        z,y,x=np.meshgrid(*([np.linspace(-2,2,17)]*3),indexing='ij')
        fields=dict(density=np.exp((x+y+z)/2),psi_real=x,psi_imag=y)
        with SceneCapture(source,objects=[dict(id='field',kind='volume',units='u')]) as w:
            for t in [0.,2.]:
                values={k:v*(1+t) for k,v in fields.items()}
                values.update(ten=np.full(x.shape,10.),future_invalid=np.full(x.shape,10. if t==0 else 0.))
                w.add_volume('field',t,values,origin=[-2]*3,spacing=[.25]*3,centering='cell')
    before=digest(source)
    with SceneReader(source,cache_bytes=0) as r:
        field=next(k for k,v in r.objects.items() if v['kind']=='volume')
        row=r.samples[field][-1];arrays=r.read_sample(field,len(r.samples[field])-1)
        g=row['descriptor']['geometry'];grid=np.array(g['shape'])[::-1]//2
        pt=np.array(g['origin'])+grid*np.array(g['spacing']);tx=np.array(r.objects[field]['data_to_world']).reshape(3,4)
        world=(tx[:,:3]@pt+tx[:,3]).tolist()
        oracles={}
        for name in ['density','psi_real','psi_imag']:
            values=arrays[name];finite=values[np.isfinite(values)]
            oracles[name]=dict(bound=float(np.max(np.abs(finite))),percentiles=np.quantile(finite,[.01,.99]).tolist(),sha256=hashlib.sha256(values.tobytes()).hexdigest(),probe_world=world,probe_value=float(values[tuple(grid[::-1])]),log_valid=bool(np.min(finite)>=1e-38),percentile_clips=bool(np.min(finite)<np.quantile(finite,.01) or np.max(finite)>np.quantile(finite,.99)))
    job=dict(capture=str(source),field=field,time=row['time'],oracles=oracles,output=str(out),synthetic=not bool(a.real_capture))
    (out/'job.json').write_text(json.dumps(job))
    base=[a.godot,'--path',str(ROOT/'viewer'),'--rendering-method',a.renderer,'--audio-driver','Dummy']
    run_native(base+['--resolution','960x640','--script','res://layers/test_volume_color.gd','--','--color-job='+str(out/'job.json')],out,env)
    report=json.loads((out/'report.json').read_text());assert not report['failures']
    ffmpeg=shutil.which('ffmpeg');assert ffmpeg
    export=out/'export';export.mkdir();state=json.loads((out/'export-state.json').read_text())
    render=dict(version=1,capture_path=str(source),state=state,start_time=row['time'],end_time=row['time'],fps=4,playback_rate=1.,width=960,height=640,output_path=str(export/'color.mp4'),camera_mode='locked',orbit_speed=0.,quality='high',keep_frames=True,inspection_sidecars=True,ffmpeg_path=ffmpeg)
    (export/'job.json').write_text(json.dumps(render))
    run_native(base+['--fixed-fps','4','--disable-vsync','--','--wavez-render-job='+str(export/'job.json')],export,env)
    assert json.loads((export/'progress.json').read_text())['stage']=='complete'
    assert np.array_equal(np.asarray(Image.open(out/'density-percentile.png')),np.asarray(Image.open(export/'frames/frame00000000.png')))
    sidecar=json.loads((export/'inspection-00000000.json').read_text())
    assert sidecar['visual']['scene']['layers'][field]['color_mapping']==state['scene']['layers'][field]['color_mapping']
    report['export']=dict(complete=True,pixels_identical=True,policy_preserved=True)
    if not a.real_capture:
        failed=out/'invalid-export';failed.mkdir();bad=render.copy();bad.update(state=json.loads((out/'invalid-export-state.json').read_text()),start_time=2.,end_time=2.,output_path=str(failed/'invalid.mp4'))
        (failed/'job.json').write_text(json.dumps(bad))
        result=subprocess.run(base+['--','--wavez-render-job='+str(failed/'job.json')],cwd=ROOT,env=env,text=True,capture_output=True,timeout=120)
        (failed/'native.log').write_text(result.stdout+result.stderr)
        progress=json.loads((failed/'progress.json').read_text())
        assert result.returncode!=0 and progress['stage']=='failed' and 'Log color unavailable' in progress['message']
        assert not (failed/'invalid.mp4').exists()
        report['invalid_log_export_refused']=True
    assert digest(source)==before
    report.update(source_sha256_unchanged=before,source_file=source.name,source_bytes=source.stat().st_size,oracles=oracles)
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'{a.renderer}: {report["checks"]} PASS; export verified; source unchanged')


if __name__=='__main__':main()

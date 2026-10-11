"""Generate adversarial WVZ1 fixtures and validate asynchronous playback semantics."""
import argparse,json,subprocess,sys
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from wavez_export import SceneCapture

def prepare(out):
    out.mkdir(parents=True,exist_ok=True)
    for name,persistent,compression in [('ids',True,'none'),('anonymous',False,'none'),('zstd',True,'zstd')]:
        path=out/(name+'.wvz')
        objects=[dict(id='particles',kind='particles',units='u',identity='persistent_i8' if persistent else 'anonymous'),dict(id='field',kind='volume',units='u')]
        path.unlink(missing_ok=True)
        with SceneCapture(path,objects=objects,compression=compression) as writer:
            for time in sorted(set(np.arange(0,4.1,.5))|{1.25,3.25}):
                if time in [0,1.25,3.25,4]:
                    writer.add_volume('field',time,{'rho':np.full((2,2,2),time+1,dtype='f8')},origin=[0,0,0],spacing=[1,1,1])
                if time*2 != int(time*2):continue
                step=int(time*2)
                ids=np.array([7,42,9007199254741011],dtype='i8')
                if step>=2:ids=np.array([42,100,9007199254741011],dtype='i8')
                if step==5:ids=np.array([100,9007199254741011],dtype='i8')
                if step>=6:ids=np.array([100,9007199254741011,103],dtype='i8')
                if step%2:ids=ids[::-1].copy()
                n=len(ids);x=np.array([int(v%101) for v in ids],dtype='f8')*.01
                pos=np.column_stack([x+time,x*2-time,x*0+.25*time])
                colors=np.column_stack([x,np.ones(n)*.5,np.ones(n)*.8,np.ones(n)*.7])
                fields=dict(scalar=x-0.25,opacity=np.array([1,0,float('nan')][:n],dtype='f8'),particle_type=(ids%3).astype('u4'),visual_color=colors,visual_size=x+.2,visual_brightness=x+.3,velocity=np.column_stack([x,x*2,x*3]))
                writer.add_particles('particles',time,pos,ids=ids if persistent else None,**fields)
    (out/'delayed.wvz').unlink(missing_ok=True)
    with SceneCapture(out/'delayed.wvz',objects=[dict(id='particles',kind='particles',units='u',identity='persistent_i8'),dict(id='field',kind='volume',units='u')]) as w:
        w.add_volume('field',0,{'rho':np.ones((2,2,2),dtype='f4')},origin=[0,0,0],spacing=[1,1,1])
        w.add_particles('particles',1,[[1.,0.,0.]],ids=[7])
        w.add_particles('particles',2,[[2.,0.,0.]],ids=[7])
    (out/'replacement.wvz').unlink(missing_ok=True)
    with SceneCapture(out/'replacement.wvz',objects=[dict(id='field',kind='volume',units='u')]) as w:
        for t in [0,1]:w.add_volume('field',t,{'rho':np.ones((2,2,2),dtype='f8')},origin=[0,0,0],spacing=[1,1,1])
    from wavez_export import SceneReader
    with SceneReader(out/'ids.wvz') as reader:
        initial_end=max(r['end'] for r in reader.records if r['time']<=.5)
        (out/'live-config.json').write_text(json.dumps({'initial_end':initial_end,'final_end':(out/'ids.wvz').stat().st_size},indent=2))
    (out/'config.json').write_text(json.dumps(dict(ids=str(out/'ids.wvz'),anonymous=str(out/'anonymous.wvz')),indent=2))

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot',required=True);p.add_argument('--output-dir',type=Path,required=True)
    p.add_argument('--renderer',choices=['headless','forward_plus'],default='headless')
    a=p.parse_args();out=a.output_dir.resolve();prepare(out)
    cmd=[a.godot,'--path',str(ROOT/'viewer'),'--audio-driver','Dummy','--log-file',str(out/'godot.log')]
    cmd+=['--headless'] if a.renderer=='headless' else ['--rendering-method',a.renderer,'--resolution','960x640']
    cmd+=['--script','layers/test_scene_playback.gd','--','--playback-fixture='+str(out)]
    r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=180)
    (out/'test.log').write_text(r.stdout);print(r.stdout)
    raise SystemExit(0 if r.returncode==0 and 'ERROR:' not in r.stdout else 1)
if __name__=='__main__':main()

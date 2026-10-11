"""Rendered regression for live WVZ1 union-clock slider extent.

Optionally replay committed prefixes of a real layered capture, without writing
to that source. The native test appends bytes only to disposable fixture copies.
"""
import argparse, json, subprocess, sys
from pathlib import Path
import numpy as np
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from wavez_export import SceneCapture, SceneReader


def prepare(out, source=None):
    if source is None:
        source = out / 'cadence.wvz'
        source.unlink(missing_ok=True)
        with SceneCapture(source, objects=[
            dict(id='particles', kind='particles', units='u', identity='persistent_i8'),
            dict(id='density', kind='volume', units='u')]) as w:
            for t in sorted(set(np.arange(0, 4.1, .5)) | {1.25, 3.25}):
                if t in (0, 1.25, 3.25, 4):
                    w.add_volume('density', t, {'rho': np.full((2,2,2), t+1, dtype='f4')}, origin=[0,0,0], spacing=[1,1,1])
                if t*2 == int(t*2):
                    w.add_particles('particles', t, np.array([[t,0,0]], dtype='f4'), ids=[7], scalar=np.array([t], dtype='f4'))
        requested, initial_time, final_time = 2.25, .5, 4
    else:
        requested, initial_time, final_time = 20.25, .5, 40
    with SceneReader(source) as reader:
        particle = next(o['id'] for o in reader.objects.values() if o['kind']=='particles')
        volume = next(o['id'] for o in reader.objects.values() if o['kind']=='volume')
        initial_end = max(r['end'] for r in reader.records if r['time']<=initial_time)
        final_end = max(r['end'] for r in reader.records if r['time']<=final_time)
        # Select a committed prefix; no record is manufactured or re-encoded.
        retained = [r for r in reader.records if r['end']<=final_end]
        times = sorted(set(r['time'] for r in retained))
        particle_times = [r['time'] for r in retained if r['object']==particle]
        volume_times = [r['time'] for r in retained if r['object']==volume]
    complete = out/'complete.wvz'
    with Path(source).open('rb') as src, complete.open('wb') as dst:
        remaining = final_end
        while remaining:
            block=src.read(min(8*1024**2,remaining));dst.write(block);remaining-=len(block)
    config = dict(source=str(Path(source).resolve()), complete=str(complete), initial_end=initial_end,
                  times=times, requested=requested, particle=particle, volume=volume,
                  particle_times=particle_times, volume_times=volume_times, analytic=source.name=='cadence.wvz')
    (out/'config.json').write_text(json.dumps(config,indent=2))


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot',required=True);p.add_argument('--source',type=Path)
    p.add_argument('--label',default='after');p.add_argument('--renderer',default='forward_plus',choices=['forward_plus'])
    a=p.parse_args();out=(ROOT/'results/g3-timeline'/a.label).resolve();out.mkdir(parents=True,exist_ok=True)
    prepare(out,a.source)
    cmd=[a.godot,'--path',str(ROOT/'viewer'),'--resolution','1440x900','--audio-driver','Dummy',
         '--rendering-method',a.renderer,'--log-file',str(out/'godot.log'),
         '--script','layers/test_scene_timeline.gd','--','--timeline-fixture='+str(out)]
    r=subprocess.run(cmd,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
    (out/'test.log').write_text(r.stdout);print(r.stdout)
    raise SystemExit(0 if r.returncode==0 and 'ERROR:' not in r.stdout else 1)


if __name__=='__main__':main()

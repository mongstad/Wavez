"""Portable preset regression, source invariance and process measurements."""
import argparse, hashlib, json, subprocess, sys, time
from pathlib import Path
import numpy as np
import os
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tests.g4.fixtures import scene
from wavez_export import SceneCapture

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot',required=True);p.add_argument('--output-dir',type=Path,required=True)
    p.add_argument('--renderer',default='forward_plus',choices=['forward_plus','gl_compatibility','headless'])
    p.add_argument('--production',type=Path)
    a=p.parse_args();out=a.output_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    scene(out/'scene.ssc')
    for name,volume in [('different',True),('particles',False)]:
        objects=[dict(id='tracers',kind='particles',units='m',identity='persistent_i8')]
        if volume:objects.append(dict(id='vacuum_field',kind='volume',units='K'))
        with SceneCapture(out/(name+'.ssc'),objects=objects) as w:
            for t in [0.,1.]:
                w.add_particles('tracers',t,np.array([[0.,0.,0.],[1.,1.,1.]]),ids=np.array([101,102],dtype='i8'),temperature=np.array([2.,3.]))
                if volume:w.add_volume('vacuum_field',t,dict(temperature=np.ones((4,4,4))),origin=[0,0,0],spacing=[1,1,1],centering='node')
    hashes={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in out.glob('*.ssc')}
    stamp=(a.production.stat().st_size,a.production.stat().st_mtime_ns) if a.production else None
    command=[a.godot,'--path',str(ROOT/'viewer'),'--audio-driver','Dummy','--script','res://scene/test_view_preset.gd']
    command+=['--headless'] if a.renderer=='headless' else ['--rendering-method',a.renderer,'--resolution','1440x900']
    command+=['--',str(out)]+([str(a.production)] if a.production else [])
    samples=[];started=time.monotonic()
    with (out/'native.log').open('w') as log:
        child=subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT)
        while child.poll() is None:
            try:
                fields=Path(f'/proc/{child.pid}/stat').read_text().split()
                samples.append(dict(seconds=time.monotonic()-started,rss=int(fields[23])*os.sysconf('SC_PAGE_SIZE'),cpu_seconds=(int(fields[13])+int(fields[14]))/os.sysconf('SC_CLK_TCK')))
            except FileNotFoundError:pass
            if time.monotonic()-started>180:child.kill();child.wait();raise RuntimeError('Preset timeout')
            time.sleep(.05)
    (out/'process.json').write_text(json.dumps(samples,indent=2))
    assert child.returncode==0 and 'ERROR:' not in (out/'native.log').read_text(),out/'native.log'
    r=json.loads((out/'report.json').read_text());assert not r['failures']
    assert hashes=={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in out.glob('*.ssc')}
    if a.production:assert stamp==(a.production.stat().st_size,a.production.stat().st_mtime_ns)
    r.update(source_hashes_unchanged=hashes,production_stat_unchanged=bool(a.production),rss_peak=max(s['rss'] for s in samples),cpu_seconds=max(s['cpu_seconds'] for s in samples),total_seconds=time.monotonic()-started)
    (out/'report.json').write_text(json.dumps(r,indent=2)+'\n');print(f'Preset: {r["checks"]} PASS ({a.renderer})')
if __name__=='__main__':main()

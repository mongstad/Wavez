"""Rendered offline-video acceptance tests (Godot GPU + FFmpeg + ffprobe)."""
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import time

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
import numpy as np
from wavez_export import SceneCapture


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',required=True)
    parser.add_argument('--output-dir',type=Path)
    parser.add_argument('--renderer',choices=['gl_compatibility','forward_plus'],default='gl_compatibility')
    parser.add_argument('--continuation', action='store_true', help='Run focused additional coverage without repeating the full 4K suite.')
    parser.add_argument('--overlay-ui', action='store_true', help='Focused production overlay, resolution and deterministic repeat coverage.')
    args=parser.parse_args()
    ffmpeg=shutil.which('ffmpeg'); probe=shutil.which('ffprobe')
    if not ffmpeg or not probe: raise SystemExit('Full acceptance suite requires ffmpeg and ffprobe.')
    base=args.output_dir.resolve() if args.output_dir else Path(tempfile.mkdtemp(prefix='wavez-native-video-'))
    if args.output_dir:base.mkdir(parents=True,exist_ok=False)
    run=Path(tempfile.mkdtemp(prefix='acceptance ',dir=base))
    log=[]
    def record(text):
        print(text,flush=True);log.append(text)
        (run/'validation.log').write_text('\n'.join(log))
    def check(ok,description):
        if not ok: raise AssertionError(description)
        record('PASS: '+description)
    def command(extra):
        return [args.godot,'--path',str(ROOT/'viewer'),'--resolution','640x360','--audio-driver','Dummy','--rendering-method',args.renderer]+extra
    with SceneCapture(base/'fixture.ssc',objects=[dict(id='particles',kind='particles',units='u',identity='persistent_i8')],metadata={'simulation_name':'Video timing fixture'}) as c:
        for t in np.linspace(0,1,11):
            c.add_particles("particles",t,[[-2+t*4,0,0],[0,1+t,0],[1,0,-1]],ids=[0,1,2],temperature=np.array([100,200,300],dtype="f4"),visual_size=np.full(3,.7,dtype="f4"),particle_type=np.array([0,1,0],dtype="u4"))
    with SceneCapture(base/'variable fixture.ssc',objects=[dict(id='particles',kind='particles',units='u',identity='anonymous')]) as c:
        c.add_particles("particles",0,np.array([[0,0,0],[1,0,0]],dtype="f4"),temperature=np.array([1,2],dtype="f4"))
        c.add_particles("particles",.1,np.array([[0,0,0],[1,0,0],[2,0,0]],dtype="f4"),temperature=np.array([1,2,3],dtype="f4"))
        c.add_particles("particles",.2,np.array([[0,1,0],[1,1,0],[2,1,0]],dtype="f4"),density=np.array([1,2,3],dtype="f4"))
    result=subprocess.run(command(['--script','video/test_ux.gd','--','--video-fixture='+str(base)]),text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60)
    record(result.stdout)
    check(result.returncode==0 and 'ERROR:' not in result.stdout,'screenshot, trails, timeline and export-state UX suite')
    state=json.loads((base/'state.json').read_text())
    state['overlay_visible']=False
    state['trails_enabled']=False
    capture_hash=hashlib.sha256((base/'fixture.ssc').read_bytes()).hexdigest()
    def job_for(name,**changes):
        directory=run/name;directory.mkdir()
        job=dict(version=1,capture_path=str(base/'fixture.ssc'),start_time=.1,end_time=.6,
                 fps=30,playback_rate=1.,width=1920,height=1080,output_path=str(directory/'result with spaces.mp4'),
                 state=copy.deepcopy(state),camera_mode='orbit',orbit_speed=.2,quality='high',keep_frames=True,ffmpeg_path=ffmpeg)
        job.update(changes)
        path=directory/'job.json';path.write_text(json.dumps(job))
        return path,job
    def launch(path,job):
        stream=(path.parent/'renderer.log').open('w')
        process=subprocess.Popen(command(['--fixed-fps',str(job['fps']),'--disable-vsync','--','--wavez-render-job='+str(path)]),stdout=stream,stderr=subprocess.STDOUT)
        return process,stream
    def finish(process,stream,path,stage='complete'):
        process.wait(timeout=120);stream.close()
        progress=json.loads((path.parent/'progress.json').read_text())
        output=(path.parent/'renderer.log').read_text()
        record(f'{path.parent.name}: {progress["stage"]} — {progress["message"]}')
        check(progress['stage']==stage,f'{path.parent.name}: expected completion state')
        check('SCRIPT ERROR:' not in output and 'RID allocations' not in output,f'{path.parent.name}: no Godot script errors/resource leaks')
        if stage=='complete': check(process.returncode==0,'successful render process exit')
        return progress
    def movie(path,job):
        p,s=launch(path,job);finish(p,s,path)
        result=json.loads(subprocess.check_output([probe,'-v','error','-select_streams','v:0','-show_entries','stream=width,height,avg_frame_rate,nb_frames,duration','-of','json',job['output_path']]))['streams'][0]
        count=max(1,math.ceil((job['end_time']-job['start_time'])*job['fps']/job['playback_rate']-1e-9))
        check((result['width'],result['height'])==(job['width'],job['height']),f'{path.parent.name}: actual MP4 dimensions')
        check(int(result['nb_frames'])==count and result['avg_frame_rate']==f'{job["fps"]}/1',f'{path.parent.name}: exact frame count and frame rate')
        traces=[json.loads(line) for line in (path.parent/'timing.jsonl').read_text().splitlines()]
        check(len(traces)==count and all(abs(t['capture_time']-(job['start_time']+i/job['fps']*job['playback_rate']))<1e-10 for i,t in enumerate(traces)),f'{path.parent.name}: playback-rate and range timing')
        if job.get('keep_frames'):
            files=sorted((path.parent/'frames').glob('*.png'))
            check(len(files)==count,f'{path.parent.name}: one PNG per output frame')
            check(all(struct.unpack('>II',f.read_bytes()[16:24])==(job['width'],job['height']) for f in files),f'{path.parent.name}: actual PNG dimensions')
        return traces
    if args.overlay_ui:
        ui_state=copy.deepcopy(state);ui_state['overlay_visible']=True
        presentation=dict(workspace=0,scroll=0,remaining=False)
        first_frames=None
        for name,width,height in [('overlay 1080p',1920,1080),('overlay repeat',1920,1080),('overlay 4K',3840,2160)]:
            p,j=job_for(name,width=width,height=height,end_time=.2,state=ui_state,presentation=presentation)
            traces=movie(p,j)
            hashes=[hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted((p.parent/'frames').glob('*.png'))]
            check(all(t['overlays'] for t in traces),name+': explicit overlay included')
            if first_frames is None: first_frames=hashes
            elif name=='overlay repeat':check(first_frames==hashes,'production UI repeated export pixels are deterministic')
        p,j=job_for('overlay disabled',end_time=.2);traces=movie(p,j)
        check(not any(t['overlays'] for t in traces),'overlay disabled remains explicit')
        check(hashlib.sha256((p.parent/'frames/frame00000000.png').read_bytes()).hexdigest()!=first_frames[0],'UI inclusion changes rendered pixels')
        p,j=job_for('appearance workspace',end_time=.2,state=ui_state,presentation=dict(workspace=1,scroll=0,remaining=True));movie(p,j)
        check(hashlib.sha256((p.parent/'frames/frame00000000.png').read_bytes()).hexdigest()!=first_frames[0],'accepted workspace and remaining preference reach rendered UI')
        check(hashlib.sha256((base/'fixture.ssc').read_bytes()).hexdigest()==capture_hash,'source capture bytes unchanged')
        record('ALL OVERLAY UI TESTS PASSED\nArtifacts: '+str(run))
        return
    if args.continuation:
        p,j=job_for('1440p 24fps',width=2560,height=1440,fps=24,end_time=.2);movie(p,j)
        p,j=job_for('custom resolution and FPS',width=640,height=480,fps=17,end_time=.2,keep_frames=False);movie(p,j)
        check(not (p.parent/'frames').exists(), 'successful atomic publication permits requested PNG cleanup')
        trail_state=copy.deepcopy(state);trail_state.update(trails_enabled=True,clean_view=False)
        p,j=job_for('trails enabled',width=640,height=360,start_time=.6,end_time=.7,state=trail_state);traces=movie(p,j)
        enabled_hash=hashlib.sha256((p.parent/'frames/frame00000000.png').read_bytes()).hexdigest()
        check(all(t['trails'] and t['trail_instances']>0 for t in traces),'export includes actual recorded trail instances')
        p,j=job_for('trails disabled',width=640,height=360,start_time=.6,end_time=.7);traces=movie(p,j)
        check(all(not t['trails'] and t['trail_instances']==0 for t in traces),'export excludes trail instances when disabled')
        check(hashlib.sha256((p.parent/'frames/frame00000000.png').read_bytes()).hexdigest()!=enabled_hash,'enabling trails changes rendered pixels')
        p,j=job_for('malformed path',output_path=123)
        process,stream=launch(p,j);finish(process,stream,p,'failed')
        p,j=job_for('overflowing frame count',playback_rate=1e-300)
        process,stream=launch(p,j);finish(process,stream,p,'failed')
        check(hashlib.sha256((base/'fixture.ssc').read_bytes()).hexdigest()==capture_hash,'source capture bytes unchanged')
        record('ALL CONTINUATION ACCEPTANCE TESTS PASSED\nArtifacts: '+str(run))
        return
    p,j=job_for('1080p 30fps');baseline=movie(p,j)
    p,j=job_for('1080p 60fps',fps=60);movie(p,j)
    p,j=job_for('slow render repeat',test_frame_delay_ms=25);slow=movie(p,j)
    check(baseline==slow,'identical samples and camera transforms despite per-frame delays')
    scientific=copy.deepcopy(state);scientific.update(clean_view=True)
    scientific['environment'].update(glow_enabled=False,fog_enabled=False,background_mode=1)
    p,j=job_for('4K scientific',width=3840,height=2160,end_time=.2,state=scientific);traces=movie(p,j)
    check(all(t['clean_view'] and not t['overlays'] and t['colormap']=='inferno' and t['color_channel']=='temperature' for t in traces),'scientific appearance, mapping and overlays reproduced')
    overlay_state=copy.deepcopy(state);overlay_state['overlay_visible']=True
    p,j=job_for('overlays enabled',state=overlay_state,end_time=.2);movie(p,j)
    p,j=job_for('rate two',playback_rate=2.);movie(p,j)
    p,j=job_for('locked camera',camera_mode='locked',end_time=.2);traces=movie(p,j)
    check(all(t['camera_origin']==traces[0]['camera_origin'] for t in traces),'locked camera remains exact')
    p,j=job_for('missing ffmpeg',ffmpeg_path='',end_time=.2,keep_frames=False)
    process,stream=launch(p,j);finish(process,stream,p,'frames_ready')
    check(len(list((p.parent/'frames').glob('*.png')))==3 and not Path(j['output_path']).exists(),'missing FFmpeg retains PNGs even when cleanup was selected')
    p,j=job_for('failed encoder',ffmpeg_path='/usr/bin/false',end_time=.2,keep_frames=False)
    process,stream=launch(p,j);finish(process,stream,p,'failed')
    check(len(list((p.parent/'frames').glob('*.png')))==3 and not Path(j['output_path']).exists(),'failed encoding never removes source frames or publishes output')
    p,j=job_for('cancel render',end_time=1.,fps=60,test_frame_delay_ms=50)
    process,stream=launch(p,j)
    deadline=time.monotonic()+30
    while time.monotonic()<deadline:
        if list((p.parent/'frames').glob('*.png')): break
        time.sleep(.05)
    (p.parent/'cancel').touch()
    status=finish(process,stream,p,'cancelled')
    check(0<status['current_frame']<status['total_frames'] and not Path(j['output_path']).exists(),'render cancellation preserves completed PNGs and no final MP4')
    # A slow fake encoder simulates an interrupted encoder without racing a tiny H.264 job.
    fake=run/'slow encoder.py'
    fake.write_text('#!'+sys.executable+'\nimport sys,time\nfrom pathlib import Path\nPath(sys.argv[-1]).write_bytes(b"partial")\ntime.sleep(30)\n')
    fake.chmod(0o755)
    p,j=job_for('cancel encoding',ffmpeg_path=str(fake),end_time=.2,keep_frames=False)
    process,stream=launch(p,j)
    deadline=time.monotonic()+30
    while time.monotonic()<deadline:
        if (p.parent/'encoded.partial.mp4').exists(): break
        time.sleep(.05)
    (p.parent/'cancel').touch()
    status=finish(process,stream,p,'cancelled')
    check(len(list((p.parent/'frames').glob('*.png')))==3 and (p.parent/'encoded.partial.mp4').exists() and not Path(j['output_path']).exists(),'interrupted encoding preserves frames and isolates partial MP4')
    p,j=job_for('cleanup success',keep_frames=False,end_time=.2);movie(p,j)
    check(not (p.parent/'frames').exists() and Path(j['output_path']).stat().st_size>0,'PNG cleanup only after verified final MP4')
    check(hashlib.sha256((base/'fixture.ssc').read_bytes()).hexdigest()==capture_hash,'source capture bytes unchanged')
    record('ALL VIDEO ACCEPTANCE TESTS PASSED\nArtifacts: '+str(run))

if __name__=='__main__':main()

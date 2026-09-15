"""Actual-GPU G3 acceptance, followed by a fresh short video and state audit."""
import argparse,json,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
    p=argparse.ArgumentParser();p.add_argument('--godot',required=True)
    p.add_argument('--scene-fixture',type=Path,default=ROOT/'results/g3',help='Prepared native scene fixtures; render evidence is written here')
    a=p.parse_args();out=a.scene_fixture.resolve()
    def run(name,command):
        r=subprocess.run(command,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=180);(out/(name+'.log')).write_text(r.stdout);print(r.stdout,flush=True)
        if r.returncode or 'ERROR:' in r.stdout:raise RuntimeError(name+' failed')
    for script in ['main.gd','layers/test_scene_validation.gd']:
        run('parse-'+Path(script).stem,[a.godot,'--headless','--path','viewer','--log-file','/tmp/simscope-g3-parse.log','--script',script,'--check-only'])
    for renderer in ['forward_plus','gl_compatibility']:
        run('gpu-'+renderer,[a.godot,'--path','viewer','--rendering-method',renderer,'--audio-driver','Dummy','--log-file','/tmp/simscope-g3-'+renderer+'.log','--script','layers/test_scene_validation.gd','--','--scene-fixture='+str(out)])
    job=json.loads((out/'video-check/job.json').read_text());directory=Path(tempfile.mkdtemp(prefix='video-final-',dir=out));job['output_path']=str(directory/'scene.mp4');(directory/'job.json').write_text(json.dumps(job))
    run('video-final',[a.godot,'--path','viewer','--resolution','640x640','--audio-driver','Dummy','--log-file','/tmp/simscope-g3-video-final.log','--','--simscope-render-job='+str(directory/'job.json')])
    rows=[json.loads(s) for s in (directory/'timing.jsonl').read_text().splitlines()]
    assert [r['capture_time'] for r in rows]==[.5,.75,1.,1.25]
    for r in rows:
        t=r['capture_time'];layers={x['id']:x for x in r['sample']['layers']}
        assert layers['particles']['source_time']==t
        assert layers['density']['source_time']==(0 if t<1 else 1)
        assert layers['surface']['source_time']==0 and layers['surface']['status']=='interpolated'
        assert r['sample']['isosurface']['source_time']==layers['density']['source_time'] and r['sample']['isosurface']['threshold']==.5
        state=json.loads((directory/('inspection-%08d.json'%r['n'])).read_text())
        assert state['version']==2 and len(state['layers'])==3 and state['visual']['scene']['layers']['density']['slice_distance']==-2
        assert state['visual']['scene']['layers']['density']['colormap']=='viridis' and state['visual']['scene']['layers']['density']['upper']==1
    probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_entries','stream=codec_name,width,height,nb_frames','-of','json',job['output_path']]))
    assert probe['streams'][0]['nb_frames']=='4' and probe['streams'][0]['width']==640 and probe['streams'][0]['height']==640
    (out/'video-acceptance.json').write_text(json.dumps({'job':str(directory/'job.json'),'mp4':job['output_path'],'frames':4,'source_timing_and_display_state':'passed','ffprobe':probe},indent=2));print('G3 VIDEO PASS',job['output_path'])
if __name__=='__main__':main()

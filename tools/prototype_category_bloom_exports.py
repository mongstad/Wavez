"""Investigate native video barriers using a temporary, explicitly patched worker.

The repository's production worker, job schema and UI are never modified.
"""
import argparse
import copy
import difflib
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from tools.package_linux import stage
from tools.verify_wvz import verify


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',required=True)
    parser.add_argument('--fixtures',type=Path,required=True)
    parser.add_argument('--accepted-repo',type=Path,required=True)
    parser.add_argument('--output-dir',type=Path,required=True)
    args=parser.parse_args()
    output=args.output_dir.resolve();output.mkdir(parents=True,exist_ok=False)
    fixtures=args.fixtures.resolve();capture=fixtures/'overlap.wvz'
    capture_hash=hashlib.sha256(capture.read_bytes()).hexdigest();verified=verify(capture)
    state=json.loads((fixtures/'video-state.json').read_text())
    state.pop('scene',None);state['camera_transform'][3]=[0,0,9]
    state['overlay_visible']=False;state['show_legend']=False
    state['environment']['glow_enabled']=True
    results=[]
    original_worker=(ROOT/'viewer/video/render_worker.gd').read_text()
    with tempfile.TemporaryDirectory(prefix='wavez-306-export-') as temp:
        projects={}
        for label,source in [('accepted',args.accepted_repo),('candidate',ROOT),('prototype',ROOT)]:
            project=Path(temp)/label/'viewer';stage(project,source);projects[label]=project
        code=original_worker.replace('var job_path := ""','var prototype_graph\nvar job_path := ""',1)
        anchor='\tviewer.shell.prepare_export(job.get("presentation",{}))'
        assert code.count(anchor)==1
        code=code.replace(anchor,anchor+'\n\tprototype_graph = preload("res://scene/bloom_prototype_graph.gd").new()\n\tviewer.add_child(prototype_graph)\n\tif not prototype_graph.attach(viewer):finish("failed",prototype_graph.error,1);return\n\tprototype_graph.gains = Vector3(1.35,1,1)',1)
        anchor='\t\tviewer.shell.refresh_export()'
        assert code.count(anchor)==1
        code=code.replace(anchor,anchor+'\n\t\tprototype_graph.invalidate()\n\t\tif not prototype_graph.sync():finish("failed",prototype_graph.error,1);return',1)
        (projects['prototype']/'video/render_worker.gd').write_text(code)
        (output/'temporary-worker.patch').write_text(''.join(difflib.unified_diff(original_worker.splitlines(True),code.splitlines(True),fromfile='production/render_worker.gd',tofile='temporary-prototype/render_worker.gd',n=0)))
        for label,project in projects.items():
            log=output/(label+'-import.log')
            with log.open('w') as stream:
                imported=subprocess.run([args.godot,'--headless','--path',str(project),'--editor','--import'],stdout=stream,stderr=subprocess.STDOUT,timeout=180,env=dict(os.environ,XDG_CONFIG_HOME=str(output/(label+'-profile'))))
            assert imported.returncode==0 and 'ERROR:' not in log.read_text(),log
        runs=[('prototype','forward_plus',False,1),('prototype','forward_plus',False,2)]
        runs += [(label,renderer,scientific,1) for renderer in ['forward_plus','gl_compatibility'] for scientific in [True,False] for label in ['accepted','candidate']]
        runs += [('prototype','forward_plus',True,1)]
        for label,renderer,scientific,repeat in runs:
            name=f'{label}-{renderer}-'+('Scientific' if scientific else 'Cinematic')+f'-{repeat}'
            directory=output/name;directory.mkdir()
            chosen=copy.deepcopy(state);chosen['clean_view']=scientific;chosen['preset']='Scientific' if scientific else 'Cinematic'
            chosen['environment'].update(glow_enabled=not scientific,fog_enabled=not scientific,background_mode=1 if scientific else 2)
            job=dict(version=1,capture_path=str(capture),state=chosen,start_time=0.,end_time=.75,fps=4,playback_rate=1.,width=640,height=360,output_path=str(directory/'result.mp4'),camera_mode='locked',quality='high',keep_frames=True,ffmpeg_path=shutil.which('ffmpeg'))
            path=directory/'job.json';path.write_text(json.dumps(job,indent=2)+'\n')
            command=[args.godot,'--path',str(projects[label]),'--resolution','640x360','--audio-driver','Dummy','--rendering-method',renderer,'--fixed-fps','4','--disable-vsync','--','--wavez-render-job='+str(path)]
            with (directory/'native.log').open('w') as stream:
                process=subprocess.run(command,stdout=stream,stderr=subprocess.STDOUT,timeout=150,env=dict(os.environ,XDG_DATA_HOME=str(directory/'profile'),XDG_CONFIG_HOME=str(directory/'profile')))
            log=(directory/'native.log').read_text();progress=json.loads((directory/'progress.json').read_text())
            assert process.returncode==0 and 'ERROR:' not in log and 'WARNING:' not in log and progress['stage']=='complete',directory
            frames=sorted((directory/'frames').glob('*.png'));assert len(frames)==3
            timing=[json.loads(row) for row in (directory/'timing.jsonl').read_text().splitlines()]
            assert len(timing)==3 and all(abs(row['capture_time']-n/4)<1e-12 for n,row in enumerate(timing))
            metadata=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_entries','stream=width,height,nb_frames,avg_frame_rate','-of','json',str(directory/'result.mp4')],text=True))['streams'][0]
            assert (metadata['width'],metadata['height'],metadata['nb_frames'],metadata['avg_frame_rate'])==(640,360,'3','4/1')
            hashes=[hashlib.sha256(np.array(Image.open(frame)).tobytes()).hexdigest() for frame in frames]
            assert len(set(hashes))>1,'moving scientific samples must reach the output'
            results.append(dict(name=name,pixel_hashes=hashes,ffprobe=metadata,metrics=json.loads((directory/'metrics.json').read_text())))
            print('PASS',name,flush=True)
    indexed={row['name']:row for row in results};comparisons=[]
    for renderer in ['forward_plus','gl_compatibility']:
        for mode in ['Cinematic','Scientific']:
            a=indexed[f'accepted-{renderer}-{mode}-1'];b=indexed[f'candidate-{renderer}-{mode}-1']
            assert a['pixel_hashes']==b['pixel_hashes'];comparisons.append(f'accepted/candidate {renderer} {mode}: all three frames pixel-identical')
    assert indexed['prototype-forward_plus-Cinematic-1']['pixel_hashes']==indexed['prototype-forward_plus-Cinematic-2']['pixel_hashes']
    assert indexed['prototype-forward_plus-Scientific-1']['pixel_hashes']==indexed['accepted-forward_plus-Scientific-1']['pixel_hashes']
    assert hashlib.sha256(capture.read_bytes()).hexdigest()==capture_hash
    assert hashlib.sha256((ROOT/'viewer/video/render_worker.gd').read_bytes()).hexdigest()==hashlib.sha256(original_worker.encode()).hexdigest()
    report=dict(runs=results,comparisons=comparisons,deterministic_prototype_repeat=True,scientific_prototype_matches_accepted=True,strict_verified_records=verified,source_sha256_unchanged=capture_hash,production_worker_unchanged=True,prototype_worker_scope='temporary project only; fixed experiment gains, no saved schema',limitations=['640x360, 3 frames per job; not 4K video, long video, cancellation, selection-aware v2 or production Bloom integration'])
    (output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print('11 native MP4 jobs completed; production worker and source unchanged')


if __name__=='__main__':main()

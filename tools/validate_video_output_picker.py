"""#283: source/release Browse typing, path round trip and two real short exports.
Native OS typing remains an owner check; native callback edge cases are injected.
"""
import argparse, hashlib, json, os, subprocess, tempfile
from pathlib import Path
from package_linux import stage, build
from validate_video_current import fixtures
ROOT = Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',required=True)
    parser.add_argument('--output-dir',type=Path,required=True)
    args=parser.parse_args();out=args.output_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    inputs=out/'inputs';inputs.mkdir();fixtures(inputs)
    digest=hashlib.sha256((inputs/'particles.wvz').read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix='wavez-picker-review-') as temporary:
        project=Path(temporary)/'viewer';stage(project)
        script=(project/'video/test_output_picker.gd').read_text()
        script=script.replace('extends SceneTree','extends Node\nvar root: Window:\n get: return get_tree().root\nvar process_frame: Signal:\n get: return get_tree().process_frame')
        script=script.replace('func _initialize()','func _ready()').replace('create_timer(','get_tree().create_timer(').replace('quit(','get_tree().quit(')
        (project/'review_picker.gd').write_text(script)
        (project/'review_entry.gd').write_text('extends Node\nfunc _ready():\n for arg in OS.get_cmdline_user_args():\n  if arg.begins_with("--wavez-render-job="):\n   add_child(load("res://Main.tscn").instantiate());return\n add_child(load("res://review_picker.gd").new())\n')
        (project/'Review.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://review_entry.gd" id="1"]\n[node name="Review" type="Node"]\nscript=ExtResource("1")\n')
        p=project/'project.godot';p.write_text(p.read_text().replace('res://Main.tscn','res://Review.tscn'))
        binary=out/'WAVEZ.x86_64';build(args.godot,project,binary,out/'build-logs')
    for mode in ['source','release']:
        folder=out/mode;folder.mkdir()
        (folder/'config.json').write_text(json.dumps({'source':str(inputs/'particles.wvz'),'packaged':mode=='release'}))
        env=dict(os.environ,XDG_DATA_HOME=str(folder/'profile/data'),XDG_CONFIG_HOME=str(folder/'profile/config'),PYTHONPATH='',PATH='/usr/bin:/bin')
        command=[args.godot,'--path',str(ROOT/'viewer'),'--script','video/test_output_picker.gd'] if mode=='source' else [str(binary)]
        with (folder/'native.log').open('w') as log:
            result=subprocess.run(command+['--audio-driver','Dummy','--',str(folder)],cwd='/tmp',env=env,stdout=log,stderr=subprocess.STDOUT,timeout=100)
        report=json.loads((folder/'report.json').read_text())
        assert result.returncode==0 and all(c['ok'] for c in report['checks']), (mode,report)
        for name in ['first','second']:
            probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_streams','-of','json',str(folder/(name+'.mp4'))]))
            stream=probe['streams'][0]
            assert stream['codec_name']=='h264' and (stream['width'],stream['height'])==(320,180) and stream['nb_read_frames']=='2'
        assert hashlib.sha256((inputs/'particles.wvz').read_bytes()).hexdigest()==digest
        print(mode,len(report['checks']),'checks; two H.264 exports PASS',flush=True)
if __name__=='__main__':main()

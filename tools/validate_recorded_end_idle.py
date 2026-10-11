"""Recorded boundary redraw/submission, live-follow and transport integration."""
import argparse,hashlib,json,os,subprocess,sys,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from tools.validate_render_pacing import fixtures
from tools.package_linux import stage,build
from wavez_export import SceneReader


def package(godot,out):
 with tempfile.TemporaryDirectory(prefix='wavez-end-idle-') as tmp:
  project=Path(tmp)/'viewer';stage(project)
  p=project/'scene/test_recorded_end_idle.gd';text=p.read_text().replace('extends SceneTree','extends Node\nvar root: Window:\n\tget: return get_tree().root\nvar process_frame: Signal:\n\tget: return get_tree().process_frame\nfunc create_timer(seconds: float) -> SceneTreeTimer:return get_tree().create_timer(seconds)')
  p.write_text(text.replace('func _initialize()','func _ready()').replace('quit(','get_tree().quit('))
  (project/'EndIdle.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scene/test_recorded_end_idle.gd" id="1"]\n[node name="EndIdle" type="Node"]\nscript = ExtResource("1")\n')
  settings=project/'project.godot';settings.write_text(settings.read_text().replace('res://Main.tscn','res://EndIdle.tscn'))
  binary=out/'WAVEZ-review.x86_64';build(godot,project,binary,out/'build-logs')
 return str(binary)


def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--godot',required=True);p.add_argument('--output-dir',type=Path,required=True);p.add_argument('--renderer',choices=['headless','forward_plus'],default='forward_plus');p.add_argument('--export',action='store_true')
 a=p.parse_args();out=a.output_dir.resolve();out.mkdir(parents=True,exist_ok=False);fixtures(out)
 with SceneReader(out/'particles.wvz',cache_bytes=0) as r:end=max(x['end'] for x in r.records if x['time']<=1.)
 (out/'live.json').write_text(json.dumps(dict(prefix_end=end))+'\n')
 hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.wvz')}
 cmd=[package(a.godot,out) if a.export else a.godot,'--audio-driver','Dummy']
 if not a.export:cmd+=['--path',str(ROOT/'viewer'),'--script','res://scene/test_recorded_end_idle.gd']
 cmd+=['--headless'] if a.renderer=='headless' else ['--rendering-method','forward_plus','--resolution','960x640']
 cmd+=['--',str(out)]
 with (out/'native.log').open('w') as log:r=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=240,env=dict(os.environ,XDG_DATA_HOME=str(out/'data'),XDG_CONFIG_HOME=str(out/'config')))
 report=json.loads((out/'end-idle.json').read_text());unchanged=all(hashlib.sha256((out/name).read_bytes()).hexdigest()==digest for name,digest in hashes.items())
 summary=dict(checks=report['checks'],failures=report['failures'],exit_code=r.returncode,renderer=a.renderer,packaged=a.export,source_hashes=hashes,sources_unchanged=unchanged)
 (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))
 if r.returncode or report['failures'] or not unchanged or 'ERROR:' in (out/'native.log').read_text():raise SystemExit(1)


if __name__=='__main__':main()

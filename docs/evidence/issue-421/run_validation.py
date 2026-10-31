import subprocess,json,os,pathlib
root=pathlib.Path('/home/Nozba/Codex/Wavez/Wavez');out=pathlib.Path('/tmp/wavez-421');g='/home/Nozba/Codex/Wavez/Godot_v4.7.2-stable_linux.x86_64'
env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1',XDG_CONFIG_HOME=str(out/'config'),XDG_DATA_HOME=str(out/'profile'))
cases=[('import',[g,'--headless','--editor','--path','viewer','--import']),('preferences',['python','tools/validate_view_preferences.py','--godot',g,'--output',str(out/'preferences')]),('shell',['python','tools/validate_viewer_shell.py','--godot',g,'--output-dir',str(out/'shell')]),('bloom',['python','tools/validate_global_bloom.py','--godot',g,'--output-dir',str(out/'bloom'),'--renderer','forward_plus']),('preset',['python','tools/validate_view_preset.py','--godot',g,'--output-dir',str(out/'preset')]),('playback',['python','tools/validate_scene_playback.py','--godot',g,'--output-dir',str(out/'playback'),'--renderer','forward_plus']),('camera',['python','tools/validate_camera_tumble.py','--godot',g,'--output-dir',str(out/'camera'),'--renderer','forward_plus','--suite','navigation']),('video',['python','tools/validate_video.py','--godot',g,'--output-dir',str(out/'video'),'--overlay-ui']),('package',['python','tools/package_linux.py','--godot',g,'--output-dir',str(out/'package')])]
rows=[]
for name,cmd in cases:
 with (out/(name+'-run.log')).open('w') as f:
  try:r=subprocess.run(cmd,cwd=root,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=600);code=r.returncode
  except subprocess.TimeoutExpired:code=124
 rows.append(dict(name=name,command=cmd,exit_code=code));(out/'runs.json').write_text(json.dumps(rows,indent=2));print(name,code,flush=True)

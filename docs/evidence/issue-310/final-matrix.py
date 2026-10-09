from pathlib import Path
import subprocess,os,shutil
R=Path('/home/Nozba/Codex/Wavez/light-310');P=Path('/home/Nozba/Codex/Wavez/Wavez');G='/home/Nozba/Codex/Wavez/Godot_v4.7.2-stable_linux.x86_64'
for label,method in [('forward','forward_plus'),('compatibility','gl_compatibility')]:
 for who,source,folder in [('accepted',R/'accepted','accepted-forward-final' if label=='forward' else 'accepted-compatibility'),('candidate',P,'source-'+label),('package',P,'package-'+label+'-final')]:
  out=R/folder;out.rename(R/(folder+'-status-preview-old'))
  cmd=['python',str(source/'tools/validate_application_theme.py'),'--godot',G,'--renderer',method,'--output-dir',str(out)]
  if who=='package':cmd.append('--package')
  result=subprocess.run(cmd,env=os.environ,text=True,capture_output=True,timeout=300)
  (R/(folder+'-wrapper.txt')).write_text(result.stdout+result.stderr)
  if who=='package':
   assert (out/'report.json').exists()
   log=(out/'cycle.log').read_text()
   assert '61772 checks; 0 failures' in log and 'Attempt to disconnect a nonexistent connection' in log
   print('EXPECTED SHUTDOWN LIMITATION',folder,flush=True)
  else:assert result.returncode==0,(folder,result.stdout+result.stderr);print('PASS',folder,flush=True)

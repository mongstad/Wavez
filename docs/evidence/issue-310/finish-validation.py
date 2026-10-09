from pathlib import Path
import os,subprocess,json
R=Path('/home/Nozba/Codex/Wavez/light-310');P=Path('/home/Nozba/Codex/Wavez/Wavez');G='/home/Nozba/Codex/Wavez/Godot_v4.7.2-stable_linux.x86_64'
def run(command,out,env):
    out.mkdir(parents=True,exist_ok=True)
    result=subprocess.run(command,cwd=out,env=env,capture_output=True,text=True,timeout=240)
    log=result.stdout+result.stderr;(out/'run.txt').write_text(log)
    assert result.returncode==0 and 'ERROR:' not in log and 'WARNING:' not in log,(out,result.returncode,log[-1200:])
    print('PASS',out.name,flush=True)
for label,method in [('forward','forward_plus'),('compatibility','gl_compatibility')]:
    package=R/('package-'+label+'-final')
    if not (package/'summary.json').exists():
        for phase,choice in [('restart-light','Light'),('restart-dark','Dark')]:
            out=package/phase
            env=dict(os.environ,XDG_DATA_HOME=str(package/'profile'),XDG_CONFIG_HOME=str(package/'profile'))
            run([str(package/'WAVEZ.x86_64'),'--rendering-method',method,'--resolution','1440x900','--audio-driver','Dummy','--',str(out),choice],out,env)
        summary={'cycle':json.loads((package/'report.json').read_text()),'restart-light':json.loads((package/'restart-light/report.json').read_text()),'restart-dark':json.loads((package/'restart-dark/report.json').read_text()),'packaged':True,'status':'UI assertions completed; strict cycle wrapper rejected shutdown diagnostics', 'restart_status':'clean'}
        (package/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    for who,source in [('accepted',R/'accepted'),('candidate',P)]:
        out=R/('shared-'+who+'-'+label)
        env=dict(os.environ,XDG_DATA_HOME=str(out/'profile'),XDG_CONFIG_HOME=str(out/'profile'))
        run([G,'--path',str(source/'viewer'),'--script',str(R/'chrome-compare.gd'),'--rendering-method',method,'--resolution','1440x900','--audio-driver','Dummy','--',str(out),str(R/'compare-shared/mixed.wvz')],out,env)
    for who,source in [('accepted',R/'accepted'),('candidate',P)]:
        out=R/('exports-'+who+'-'+label)
        env=dict(os.environ,XDG_DATA_HOME=str(R/('source-'+label)/'profile'),XDG_CONFIG_HOME=str(R/('source-'+label)/'profile'))
        run(['python',str(source/'tools/validate_g4_render.py'),'--godot',G,'--renderer',method,'--output-dir',str(out/'results')],out,env)

"""Small synthetic maintenance checks, with optional actual DPI/layout screenshots."""
import argparse,hashlib,json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
from examples.g4_demo import create

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--godot',required=True);p.add_argument('--output-dir',required=True,type=Path)
    p.add_argument('--renderer',choices=['headless','gl_compatibility','forward_plus'],default='headless');p.add_argument('--resolution',choices=['1440x900','3840x2160'],default='1440x900');a=p.parse_args()
    out=a.output_dir.resolve();out.mkdir(parents=True,exist_ok=False);source=create(out/'scene.ssc');digest=hashlib.sha256(source.read_bytes()).hexdigest()
    cmd=[a.godot,'--path',str(ROOT/'viewer'),'--audio-driver','Dummy','--log-file',str(out/'godot.log')]
    cmd+=['--headless'] if a.renderer=='headless' else ['--rendering-method',a.renderer,'--resolution',a.resolution]
    cmd+=['--script','analysis/test_maintenance_ui.gd','--','--maintenance-fixture='+str(out),'--maintenance-resolution='+a.resolution]
    try:r=subprocess.run(cmd,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
    except subprocess.TimeoutExpired as e:r=subprocess.CompletedProcess(cmd,124,(e.stdout or b'').decode(errors='replace') if isinstance(e.stdout,bytes) else e.stdout or '')
    (out/'stdout.log').write_text(r.stdout);print(r.stdout)
    result=json.loads((out/'ui.json').read_text()) if (out/'ui.json').exists() else None
    report=dict(command=cmd,exit_code=r.returncode,result=result,source_sha256=digest,source_unchanged=hashlib.sha256(source.read_bytes()).hexdigest()==digest)
    valid=r.returncode==0 and 'ERROR:' not in r.stdout and result and not result['failures'] and report['source_unchanged']
    if a.renderer!='headless':valid=valid and bool(result['images']) and all([i['width'],i['height']]==[int(v) for v in a.resolution.split('x')] for i in result['images'])
    report['status']='PASS' if valid else 'FAIL';(out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    return 0 if valid else 1
if __name__=='__main__':raise SystemExit(main())

"""Synthetic space-time UI and optional actual-renderer acceptance."""
import argparse,hashlib,json,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from tests.g4.fixtures import traveling_pulse


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--godot',required=True);p.add_argument('--output-dir',type=Path,required=True);p.add_argument('--renderer',choices=['headless','gl_compatibility','forward_plus'],default='headless');args=p.parse_args()
    out=args.output_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    path=traveling_pulse(out/'pulse.wvz');before=hashlib.sha256(path.read_bytes()).hexdigest()
    command=[args.godot,'--path',str(ROOT/'viewer'),'--audio-driver','Dummy','--log-file',str(out/'godot.log')]
    command+=['--headless'] if args.renderer=='headless' else ['--rendering-method',args.renderer,'--resolution','1100x820']
    command+=['--script','analysis/test_space_time.gd','--','--space-time-fixture='+str(out)]
    began=time.monotonic()
    try:result=subprocess.run(command,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=120)
    except subprocess.TimeoutExpired as e:result=subprocess.CompletedProcess(command,124,(e.stdout or b'').decode(errors='replace') if isinstance(e.stdout,bytes) else e.stdout or '')
    (out/'stdout.log').write_text(result.stdout);print(result.stdout)
    report=dict(command=command,exit_code=result.returncode,seconds=time.monotonic()-began,source_sha256=before,source_unchanged=hashlib.sha256(path.read_bytes()).hexdigest()==before,category='headless integration' if args.renderer=='headless' else 'actual renderer; image inspection required',result=json.loads((out/'space-time.json').read_text()) if (out/'space-time.json').exists() else None)
    (out/'report.json').write_text(json.dumps(report,indent=2))
    return 0 if result.returncode==0 and 'ERROR:' not in result.stdout and report['source_unchanged'] and report['result'] and not report['result']['failures'] else 1


if __name__=='__main__':raise SystemExit(main())

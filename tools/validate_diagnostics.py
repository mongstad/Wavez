"""Synthetic G4d viewer integration. Each invocation owns a fresh output folder."""
import argparse,hashlib,json,math,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from tests.g4.fixtures import scene


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--godot',required=True);p.add_argument('--output-dir',type=Path,required=True);p.add_argument('--renderer',choices=['headless','gl_compatibility','forward_plus'],default='headless');args=p.parse_args()
    out=args.output_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    scene(out/'run-a.wvz');scene(out/'run-b.wvz')
    (out/'a.csv').write_text('time,value\n0,2\n0.5,4\n1.5,6\n3,8\n')
    (out/'b.csv').write_text('time,value\n10,1\n10.5,2\n11.5,3\n13,4\n')
    (out/'period.csv').write_text('time,value\n'+''.join(f'{i*.01:.17g},{math.sin(2*math.pi*i*.01):.17g}\n' for i in range(601)))
    hashes={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in out.iterdir()}
    command=[args.godot,'--path',str(ROOT/'viewer'),'--audio-driver','Dummy','--log-file',str(out/'godot.log')]
    command+=['--headless'] if args.renderer=='headless' else ['--rendering-method',args.renderer,'--resolution','1100x820']
    command+=['--script','analysis/test_diagnostics.gd','--','--diagnostics-fixture='+str(out)]
    began=time.monotonic()
    try:result=subprocess.run(command,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=120)
    except subprocess.TimeoutExpired as e:result=subprocess.CompletedProcess(command,124,(e.stdout or b'').decode(errors='replace') if isinstance(e.stdout,bytes) else e.stdout or '')
    (out/'stdout.log').write_text(result.stdout);print(result.stdout)
    report=dict(command=command,exit_code=result.returncode,seconds=time.monotonic()-began,source_hashes=hashes,source_unchanged=all(hashlib.sha256((out/name).read_bytes()).hexdigest()==sha for name,sha in hashes.items()),category='headless integration' if args.renderer=='headless' else 'actual renderer; image inspection required',result=json.loads((out/'diagnostics.json').read_text()) if (out/'diagnostics.json').exists() else None)
    (out/'report.json').write_text(json.dumps(report,indent=2))
    return 0 if result.returncode==0 and 'ERROR:' not in result.stdout and report['source_unchanged'] and report['result'] and not report['result']['failures'] else 1


if __name__=='__main__':raise SystemExit(main())

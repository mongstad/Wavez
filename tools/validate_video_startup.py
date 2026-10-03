"""#116: exercise Start Export through the development viewer, including mutation and cancellation."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
from validate_video_current import fixtures

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output-dir', required=True, type=Path)
    args = parser.parse_args()
    out = args.output_dir.resolve();out.mkdir(parents=True, exist_ok=False)
    fixtures(out)
    shutil.copyfile(out/'field.wvz', out/'field-copy.wvz')
    checks = [];runs = []
    def check(ok, label):
        checks.append(dict(ok=bool(ok),label=label));print(('PASS: ' if ok else 'FAIL: ')+label,flush=True)
    command = [args.godot,'--path',str(ROOT/'viewer'),'--audio-driver','Dummy','--rendering-method','forward_plus','--resolution','960x640']
    environment = dict(os.environ, WAVEZ_VIDEO_PROFILE='1')
    result = subprocess.run(command+['--headless','--log-file',str(out/'identity.log'),'--script','video/test_source_identity.gd','--',str(out)],env=environment,capture_output=True,text=True,timeout=30)
    checks.extend(json.loads((out/'identity-checks.json').read_text())['checks'])
    check(result.returncode == 0 and 'SCRIPT ERROR' not in result.stdout+result.stderr,'Identity unit process passes')
    for name, changes, mutation in [
        ('normal',dict(sidecars=True),None),
        ('used-corruption',dict(source=str(out/'corrupt.wvz')),None),
        ('unused-corruption',dict(source=str(out/'corrupt.wvz'),start=0.,end=.1),None),
        ('cancel-loading',dict(cancel_stage='loading'),None),
        ('mutate-rendering',{},'rendering'),
        ('mutate-encoding',{},'encoding'),
    ]:
        folder=out/name;folder.mkdir()
        source=out/'field.wvz'
        if mutation:
            source=folder/'source.wvz';shutil.copyfile(out/'field.wvz',source)
        config=dict(source=str(source),start=.75,end=1.75,width=640,height=360,fps=60,rate=1.,**{})
        config.update(changes);(folder/'config.json').write_text(json.dumps(config))
        source=Path(config['source']);before=hashlib.file_digest(source.open('rb'),'sha256').hexdigest()
        changed=False;began=time.monotonic()
        with (folder/'native.log').open('w') as log:
            process=subprocess.Popen(command+['--script','video/test_startup_ui.gd','--',str(folder)],stdout=log,stderr=subprocess.STDOUT,env=environment)
            try:
                while process.poll() is None:
                    if time.monotonic()-began>120:raise TimeoutError(name)
                    if mutation and not changed:
                        files=list(folder.glob('.wavez-export-*/progress.json'))
                        if files:
                            try:progress=json.loads(files[0].read_text())
                            except (ValueError,OSError):progress={}
                            if progress.get('stage')==mutation:
                                stamp=source.stat()
                                # Equal-size mutation with restored mtime: ctime must catch it,
                                # including after all requested records are already cached.
                                with source.open('r+b') as stream:
                                    stream.seek(-1,2);value=stream.read(1);stream.seek(-1,2);stream.write(bytes([value[0]^1]))
                                os.utime(source,ns=(stamp.st_atime_ns,stamp.st_mtime_ns));changed=True
                    time.sleep(.005)
            finally:
                if process.poll() is None:process.kill();process.wait()
        report=json.loads((folder/'ui-report.json').read_text());runs.append(dict(name=name,**report))
        native=(folder/'native.log').read_text()
        check('SCRIPT ERROR' not in native and 'RID allocations' not in native,name+': no script errors/resource leaks')
        expected='failed' if mutation or name=='used-corruption' else ('cancelled' if name.startswith('cancel') else 'complete')
        check(report['stage']==expected,name+': '+expected)
        check(report['launch_return_ms']<1000,name+': Start Export returns within one second')
        if mutation:check(changed and 'Source changed' in report['progress']['message'],name+': source mutation refuses safely')
        else:check(before==hashlib.file_digest(source.open('rb'),'sha256').hexdigest(),name+': source bytes unchanged')
        if expected!='complete':check(not (folder/'result.mp4').exists(),name+': no MP4 published')
        if name=='used-corruption':check('checksum' in report['progress']['message'].lower(),name+': strict payload rejection')
        if name.startswith('cancel'):check(report['cancel_to_exit_ms']<2000,name+': worker exits within two seconds')
        directory=Path(report['directory'])
        job=json.loads((directory/'job.json').read_text())
        check(job['source']['kind']=='wavez-export-source' and 'sha256' not in job['source'],name+': UI sends metadata identity, no whole-prefix hash')
        if name=='normal':
            sidecar=json.loads((directory/'inspection-00000000.json').read_text())
            check(sidecar['source']==job['source'],name+': sidecar reuses binding without another full hash')
            check(report['restore_error']=='',name+': local inspection frame restores on unchanged source')
    (out/'report.json').write_text(json.dumps(dict(checks=checks,runs=runs),indent=2))
    failures=sum(not c['ok'] for c in checks)
    print(f'STARTUP VIDEO: {len(checks)} checks, {failures} failures',flush=True)
    raise SystemExit(bool(failures))

if __name__=='__main__':main()

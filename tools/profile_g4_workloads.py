"""Separate overlay, ID trace, CSV and cold/held-layer seek measurements."""
import argparse,hashlib,json
from pathlib import Path
from profile_g4 import ROOT,run


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot',required=True);p.add_argument('--output-dir',type=Path,required=True)
    p.add_argument('--capture',type=Path,required=True);p.add_argument('--demo',type=Path,required=True)
    p.add_argument('--renderer',choices=['gl_compatibility','forward_plus'],required=True)
    p.add_argument('--roi-only',action='store_true',help='Supplement an already measured matrix with a paused large ROI scan')
    a=p.parse_args();out=a.output_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    sources=[a.capture.resolve(),a.demo.resolve()];hashes={str(s):hashlib.sha256(s.read_bytes()).hexdigest() for s in sources}
    definition=dict(key='single',object='p',kind='particle_ids',selector=dict(ids=[str(2**53+1)]))
    roi=dict(name='ROI-scan-paused',analysis=True,playing=False,seconds=6)
    jobs=[dict(capture=str(sources[0]),cases=[dict(name='overlay-only',overlay=True,definition=definition,seconds=4),dict(name='single-ID-trace',analysis=True,mode='trace',definition=definition,seconds=6),dict(name='CSV-export',export=True,seconds=4),dict(name='cold-random-seeks',stored=True,cold=True,seeks=[32.125,3.125,27.125,8.125,35.125,1.125],seconds=4),roi]),
          dict(capture=str(sources[1]),start=0,end=4,cases=[dict(name='held-field-mesh-seeks',fields=True,stored=True,cold=True,seeks=[.125,2.875,.625,1.25,0,4],seconds=4),dict(name='held-field-mesh-overlay',fields=True,overlay=True,definition=definition,seconds=4)])]
    if a.roi_only:jobs=[dict(capture=str(sources[0]),cases=[roi])]
    report=dict(status='in_progress',source_sha256=hashes,runs=[])
    try:
        for index,job in enumerate(jobs):
            directory=out/str(index);directory.mkdir();job['output']=str(directory/'profile.json')
            run(a,ROOT/'viewer',directory,job,report['runs'])
        report['source_unchanged']=all(hashlib.sha256(Path(s).read_bytes()).hexdigest()==h for s,h in hashes.items())
        if not report['source_unchanged']:raise RuntimeError('Source changed')
        report['status']='MEASURED; review callback and resource evidence'
    except BaseException as exc:report.update(status='FAIL',error=str(exc));raise
    finally:(out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))


if __name__=='__main__':main()

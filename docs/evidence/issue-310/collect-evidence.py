from pathlib import Path
import hashlib,json,shutil,sys
import numpy as np
from PIL import Image
ROOT=Path(sys.argv[1]).resolve()
DEST=Path(sys.argv[2]).resolve()
DEST.mkdir(parents=True,exist_ok=True)
pairs=[]
for renderer,accepted in [('forward','accepted-forward-final'),('compatibility','accepted-compatibility')]:
    for candidate in ['source-'+renderer,'package-'+renderer+'-final']:
        if not (ROOT/candidate/'summary.json').exists(): continue
        base=ROOT/accepted;new=ROOT/candidate
        for name in sorted([p.name for p in base.glob('*dark.png')]+['scientific-light.png','restart-dark/restart-Dark.png']):
            a=np.asarray(Image.open(base/name));b=np.asarray(Image.open(new/name))
            assert a.shape==b.shape
            delta=np.any(a!=b,axis=2);count=int(delta.sum())
            allowed=np.zeros(delta.shape,dtype=bool)
            note=''
            if name.startswith('about-') or name=='restart-dark/restart-Dark.png':
                # Only the manually verified final build digit (80 -> 81), not an entire dialog.
                x,y=(530,111) if '1024' in name else (738,233)
                allowed[y:y+16,x:x+12]=True
                note='Required application build digit 80 -> 81'
            if name in ['details-dark.png','file-picker-dark.png']:
                note='Unnormalized run-specific source/project/recent paths; see shared-path exact comparisons'
                remaining=None
            else:
                remaining=int((delta & ~allowed).sum());assert remaining==0,(candidate,name,remaining)
            pairs.append(dict(renderer=renderer,candidate=candidate,image=name,raw_changed_pixels=count,unexplained_pixels=remaining,note=note,
                              accepted_sha256=hashlib.sha256((base/name).read_bytes()).hexdigest(),candidate_sha256=hashlib.sha256((new/name).read_bytes()).hexdigest()))
        summary=json.loads((new/'summary.json').read_text())
        (DEST/(candidate+'.json')).write_text(json.dumps(summary,indent=2)+'\n')
        for phase in ['cycle','restart-light','restart-dark']:
            log = new/(phase+'.log')
            if not log.exists(): log = new/phase/'run.txt'
            shutil.copyfile(log,DEST/(candidate+'-'+phase+'.txt'))
for renderer in ['forward','compatibility']:
    for image in ['details-dark.png','file-picker-dark.png']:
        a=ROOT/('shared-accepted-'+renderer)/image;b=ROOT/('shared-candidate-'+renderer)/image
        if a.exists() and b.exists():
            count=int(np.any(np.asarray(Image.open(a))!=np.asarray(Image.open(b)),axis=2).sum());assert count==0,(renderer,image,count)
            pairs.append(dict(renderer=renderer,image=image,context='Shared absolute capture and directory paths',raw_changed_pixels=count,unexplained_pixels=count))
(DEST/'pixel-comparisons.json').write_text(json.dumps(pairs,indent=2)+'\n')
shutil.copyfile(ROOT/'protected-files.json',DEST/'protected-files.json')
shutil.copyfile(ROOT/'production-linux/build.json',DEST/'production-linux-build.json')
for label,folder in [('before','accepted-forward-final'),('after','source-forward')]:
    for image in ['shell-1440x900-0-light','expanded-1440x900-light','scrolled-970x600-light']:
        shutil.copyfile(ROOT/folder/(image+'.png'),DEST/(label+'-'+image+'.png'))
for image in ['shell-1440x900-0-dark','global-focused-light','view-menu-selected-light','disclosure-hover-light','jobs-light','video-light','status-warning-light','status-error-light','expanded-970x600-light']:
    shutil.copyfile(ROOT/'source-forward'/(image+'.png'),DEST/(image+'.png'))
for renderer in ['forward','compatibility']:
    path=ROOT/('package-'+renderer+'-final')/'restart-light/restart-Light.png'
    if path.exists():shutil.copyfile(path,DEST/(renderer+'-about-light.png'))
path=ROOT/'logical-4k/light-3840x2160.png'
if path.exists():shutil.copyfile(path,DEST/'light-3840x2160.png')
for f in ['chrome-compare.gd','collect-evidence.py']:shutil.copyfile(ROOT/f,DEST/f)
print(len(pairs),'pixel comparisons collected')

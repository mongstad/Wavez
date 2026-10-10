import json
import sys
import numpy as np
from pathlib import Path
from PIL import Image
root=Path(sys.argv[2])
current=Path(sys.argv[1]);base=root/('before-compat' if 'compat' in current.name else 'before')
before=json.loads((base/'report.json').read_text());after=json.loads((current/'report.json').read_text())
count=0;pixel=[];contrasts=[]
def lum(color):
    value=[int(color[i:i+2],16)/255 for i in (0,2,4)]
    linear=[x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in value]
    return sum(x*y for x,y in zip(linear,[.2126,.7152,.0722]))
for name,old in before.items():
    new=after[name]
    if 'heading' not in old:
        assert old==new,(name,old,new)
        if name.endswith('keyboard'):assert all(new.values()),name
        if name.endswith('hover'):assert new['hovered'],name
        continue
    assert old['heading']==new['heading'],name
    assert old['pins']==new['pins'],name
    assert old['other_title']==new['other_title'],name
    expected='7956c8' if old['light'] else '7270d8'
    assert new['heading_color']==expected,(name,new['heading_color'])
    for pin in new['pins'].values():
        assert pin['pinned']==pin['button_pressed']
        assert all(c==expected for c in pin['colors'].values())
    for bg in new['background_samples']:
        a,b=sorted([lum(expected),lum(bg)]);contrasts.append((name,bg,(b+.05)/(a+.05)))
    a=np.asarray(Image.open(base/(name+'.png')).convert('RGB'));b=np.asarray(Image.open(current/(name+'.png')).convert('RGB'))
    delta=np.any(a!=b,axis=2);diff=int(delta.sum())
    x0,y0,x1,y1=new['heading_pixel_rect'];delta[y0:y1,x0:x1]=False
    # Pixel equality uses the corresponding accepted renderer baseline.
    assert not delta.any(),(name,'pixels changed outside heading')
    if not old['light']:assert diff==0,name
    else:assert diff>0,name
    pixel.append(dict(state=name,changed_pixels=diff,outside_heading=0));count+=1
summary={'geometry_and_pin_contract_states':count,'keyboard_and_hover_states':4,'dark_pixel_identical':True,'light_differences_only_heading':True,'light_min_contrast':min(r[2] for r in contrasts if r[0].startswith('light')),'contrasts':[{'state':name,'background':bg,'ratio':ratio} for name,bg,ratio in contrasts],'pixels':pixel}
assert summary['light_min_contrast']>=4.5
(current/'verification.json').write_text(json.dumps(summary,indent=2)+'\n')
print('Verified',count,'layout/pin/color states; keyboard/hover unchanged; Dark pixels identical; Light pixel changes confined to heading. Minimum Light contrast:',summary['light_min_contrast'])

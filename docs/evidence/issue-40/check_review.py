"""Focused artifact checks for the issue-40 revision of PR #39."""
from pathlib import Path
import hashlib
import itertools
import json
import re
import subprocess
import xml.etree.ElementTree as ET
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
REVISION_BASE = '4d6fd3b5c3e023f0cd4e2a5474f44129ff30e1dd'
MAIN_BASE = '68e3b5abb548d2e95ba5ae5b8e57e03d652de502'

def git(*args):
    return subprocess.check_output(['git',*args],cwd=ROOT,text=True)

layout = json.loads((OUT/'layout.json').read_text())
token_path = ROOT/'viewer/ui/theme/simscope_tokens.gd'
assert layout['token_sha256'] == hashlib.sha256(token_path.read_bytes()).hexdigest()
tokens = dict(re.findall(r'&"([\w.]+)": Color\("([0-9a-f]+)"\)',token_path.read_text()))
assert not git('diff',MAIN_BASE,'--','viewer','simscope_export','tests','tools')
assert not git('diff',REVISION_BASE,'--','docs/UX_CONTROL_MAP.md')
assert not git('diff',REVISION_BASE,'--','docs/evidence/issue-14/*.png','docs/evidence/issue-14/*.json','docs/evidence/issue-14/render_wireframes.py')
historical = git('show',REVISION_BASE+':docs/UX_IA_REVIEW.md').split('\n',2)[2]
assert (ROOT/'docs/UX_IA_REVIEW.md').read_text().endswith(historical)
allowed = {'docs/CURRENT_STATUS.md','docs/UX_INFORMATION_ARCHITECTURE.md',
           'docs/UX_IA_REVIEW.md','docs/UX_VISUAL_LANGUAGE.md',
           'docs/evidence/issue-14/check_review.py','docs/evidence/issue-14/wireframes.md'}
changed = git('diff','--name-only',REVISION_BASE).splitlines()
changed += git('ls-files','--others','--exclude-standard').splitlines()
assert all(p in allowed or p.startswith('docs/evidence/issue-40/') for p in changed),changed

required = {'scene','particle','volume','volume-details','faint-inherited',
            'faint-edited','signed','selection','analysis','results','compact',
            'mesh','components','time-difference','color-details'}
figures = {x['name']:x for x in layout['figures']}
assert set(figures) == required
control_count = 0
for name,figure in figures.items():
    path = OUT/(name+'.png')
    assert path.stat().st_size < 1024*1024,path
    assert hashlib.sha256(path.read_bytes()).hexdigest() == figure['sha256']
    with Image.open(path) as im:
        assert im.size == tuple(figure['size']);im.verify()
    w,h = figure['size']
    assert (w,h) == ((1024,640) if name=='compact' else (1440,900))
    controls = figure['controls'];control_count += len(controls)
    for control in controls:
        x,y,cw,ch = control['rect']
        assert x>=0 and y>=0 and x+cw<=w and y+ch<=h,(name,control)
        assert cw>=28 and ch>=28,(name,control)
        assert control['name'],(name,control)
        if name!='components' and 40<y<h-88:
            assert y+ch<=h-88,(name,'dock/transport overlap',control)
    for a,b in itertools.combinations(controls,2):
        ax,ay,aw,ah=a['rect'];bx,by,bw,bh=b['rect']
        assert min(ax+aw,bx+bw)<=max(ax,bx) or min(ay+ah,by+bh)<=max(ay,by),(name,'overlapping controls',a,b)
    for label in figure['labels']:
        x,y,lw,lh=label['rect']
        assert x>=0 and y>=0 and x+lw<=w+.01 and y+lh<=h,(name,label)
        assert not any(t in label['text'] for t in ('·',' @ ','[ Apply','[ Probe','Workspace:')),(name,label)
    if name not in ('compact','components'):
        nav = {x['name'] for x in controls if 40<x['rect'][1]<132}
        assert {'Scene','Appearance','Selection','Analysis'} <= nav,(name,nav)
    if name!='components':
        assert any(x['name']=='Jobs 0' and x['rect'][1]>=h-88 for x in controls)

def texts(name):
    return {x['text'] for x in figures[name]['labels']}

assert {'0','100'} <= texts('faint-inherited')
assert {'1','99'} <= texts('faint-edited')
assert {'0','1.72'} <= texts('faint-edited')  # Existing mappings before Apply.
for name in ('faint-inherited','faint-edited','compact'):
    controls=figures[name]['controls']
    apply=next(x for x in controls if x['name']=='Apply')
    neighbors=[x for x in controls if x['type']=='numeric input' and x['rect'][1]==apply['rect'][1]]
    assert len(neighbors)==2
assert {'Symmetric','Locked','Magnitude','0.01','1.298'} <= texts('signed')
assert {'9007199254740993','Bind source snapshot…'} <= texts('selection')
assert 'Requested time' not in texts('volume')
assert {'Displayed time','Requested time','200','220'} <= texts('time-difference')
assert {'Volume quality','Ray step','Reset opacity mapping'} <= texts('volume-details')
assert {'For positive and negative data','Enter a finite number.'} <= texts('components')
assert {'Export numerical data…','Return to viewport','Recorded range'} <= texts('results')
svg = ET.parse(OUT/'icons.svg').getroot()
assert {x.attrib['id'] for x in svg} == set(layout['icons'])
assert len(layout['icons']) == 29
assert not any(x.tag.endswith('text') for x in svg.iter())

def luminance(value):
    rgb=[int(value[i:i+2],16)/255 for i in (0,2,4)]
    linear=[c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in rgb]
    return sum(c*v for c,v in zip(linear,(.2126,.7152,.0722)))

pairs=[]
for text in ('text.primary','text.secondary','text.muted'):
    for surface in ('surface.0','surface.1','surface.2','surface.3'):
        pairs.append((text,surface,4.5))
pairs += [('accent.foreground','accent.primary',4.5),('selection.text','selection.fill',4.5),
          ('focus.ring','surface.1',3),('border.control','surface.2',3)]
pairs += [(key,'surface.1',4.5) for key in ('state.success','state.warning','state.error','state.info')]
contrast=[]
for fore,back,minimum in pairs:
    a,b=sorted((luminance(tokens[fore]),luminance(tokens[back])))
    ratio=(b+.05)/(a+.05)
    assert ratio>=minimum,(fore,back,ratio)
    contrast.append({'foreground':fore,'background':back,'ratio':round(ratio,3),'minimum':minimum})
subprocess.run(['git','diff','--check'],cwd=ROOT,check=True)
report={'issue':40,'static_mockups':len(figures),'vector_icons':len(layout['icons']),
        'controls_with_bounds_nonoverlap_and_minimum_size':control_count,
        'contrast_pairs':contrast,'theme_token_hash':'matches current source',
        'required_copy_navigation_and_adjacent_inputs':'pass',
        'historical_evidence_and_control_map':'unchanged',
        'production_diff':'empty','revision_scope':'pass','whitespace':'pass',
        'limits':'Static evidence only; no runtime, human usability, scientific or physical DPI validation.'}
(OUT/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='contrast_pairs'},indent=2))

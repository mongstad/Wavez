"""Static, code-drawn issue-40 design evidence; never loaded by the viewer.

Run from the repository root with the existing Python/Pillow environment.
Theme values are read, never copied back. No captures or external assets needed.
All scene/plot marks and numbers are illustrative, not scientific render evidence.
"""
from pathlib import Path
from functools import lru_cache
import hashlib
import json
import math
import os
import random
import re
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
TOKEN_PATH = ROOT / 'viewer/ui/theme/simscope_tokens.gd'
TOKENS = TOKEN_PATH.read_text()
C = dict(re.findall(r'&"([\w.]+)": Color\("([0-9a-f]+)"\)', TOKENS))
C = {k: '#' + v for k, v in C.items()}
SANS = Path(os.environ.get('UX_MOCKUP_FONT', '/usr/share/fonts/google-noto/NotoSans-Regular.ttf'))
BOLD = Path(os.environ.get('UX_MOCKUP_BOLD', '/usr/share/fonts/google-noto/NotoSans-SemiBold.ttf'))
MONO = ROOT / 'viewer/ui/fonts/DejaVuSansMono.ttf'
S = 2
COMMAND_BAR = 48
MANIFEST = []

# Provisional 16-unit vector drawings, not final icon artwork. UX2 play/copy/chevron geometry is
# retained; additions follow its 1.5-unit outline, round caps and joins.
# These tuples also generate the reviewable SVG sprite; no symbol fonts.
ICONS = {
    'open': [('p', [(1, 12), (1, 3), (6, 3), (8, 5), (14, 5), (14, 7)]), ('p', [(1, 13), (4, 7), (15, 7), (12, 13), (1, 13)])],
    'state': [('r', (3, 2, 10, 12, 1)), ('p', [(5, 1), (5, 4), (11, 4), (11, 1)]), ('p', [(6, 7), (10, 7)]), ('p', [(6, 10), (10, 10)])],
    'export': [('p', [(8, 10), (8, 1), (4, 5)]), ('p', [(8, 1), (12, 5)]), ('p', [(2, 10), (2, 14), (14, 14), (14, 10)])],
    'view': [('r', (1, 2, 14, 12, 1)), ('p', [(10, 2), (10, 14)]), ('p', [(1, 11), (15, 11)])],
    'help': [('c', (8, 8, 6)), ('p', [(6, 5), (7, 4), (9, 4), (10, 5), (10, 7), (8, 9)]), ('c', (8, 12, .15))],
    'frame': [('p', [(1, 6), (1, 1), (6, 1)]), ('p', [(10, 1), (15, 1), (15, 6)]), ('p', [(15, 10), (15, 15), (10, 15)]), ('p', [(6, 15), (1, 15), (1, 10)])],
    'reset': [('p', [(3, 5), (6, 2), (11, 2), (14, 5), (14, 10), (11, 13), (6, 13), (3, 10)]), ('p', [(3, 1), (3, 5), (7, 5)])],
    'play': [('p', [(5, 3), (13, 8), (5, 13), (5, 3)])],
    'pause': [('p', [(5, 3), (5, 13)]), ('p', [(11, 3), (11, 13)])],
    'previous': [('p', [(2, 3), (2, 13)]), ('p', [(13, 3), (5, 8), (13, 13), (13, 3)])],
    'next': [('p', [(14, 3), (14, 13)]), ('p', [(3, 3), (11, 8), (3, 13), (3, 3)])],
    'eye': [('p', [(1, 8), (4, 4), (8, 3), (12, 4), (15, 8), (12, 12), (8, 13), (4, 12), (1, 8)]), ('c', (8, 8, 2))],
    'hidden': [('p', [(1, 8), (4, 4), (8, 3), (12, 4), (15, 8), (12, 12), (8, 13), (4, 12), (1, 8)]), ('p', [(2, 2), (14, 14)])],
    'particles': [('c', (4, 4, 1.5)), ('c', (12, 5, 1.5)), ('c', (5, 12, 1.5)), ('c', (11, 11, 1.5))],
    'field': [('r', (2, 2, 12, 12, 1)), ('p', [(6, 2), (6, 14)]), ('p', [(10, 2), (10, 14)]), ('p', [(2, 6), (14, 6)]), ('p', [(2, 10), (14, 10)])],
    'mesh': [('p', [(8, 1), (15, 13), (1, 13), (8, 1), (8, 8), (15, 13)]), ('p', [(8, 8), (1, 13)])],
    'scene': [('p', [(8, 1), (14, 4), (14, 12), (8, 15), (2, 12), (2, 4), (8, 1)]), ('p', [(2, 4), (8, 7), (14, 4)]), ('p', [(8, 7), (8, 15)])],
    'appearance': [('p', [(2, 4), (14, 4)]), ('p', [(2, 12), (14, 12)]), ('c', (6, 4, 2)), ('c', (10, 12, 2))],
    'selection': [('p', [(6, 2), (2, 2), (2, 6)]), ('p', [(10, 2), (14, 2), (14, 6)]), ('p', [(14, 10), (14, 14), (10, 14)]), ('p', [(6, 14), (2, 14), (2, 10)]), ('p', [(5, 8), (7, 10), (11, 6)])],
    'analysis': [('p', [(2, 2), (2, 14), (15, 14)]), ('p', [(4, 10), (7, 6), (10, 9), (14, 3)])],
    'warning': [('p', [(8, 2), (15, 14), (1, 14), (8, 2)]), ('p', [(8, 6), (8, 9)]), ('c', (8, 11.5, .15))],
    'info': [('c', (8, 8, 6)), ('c', (8, 4.5, .15)), ('p', [(8, 7), (8, 11)])],
    'down': [('p', [(4, 6), (8, 10), (12, 6)])],
    'right': [('p', [(6, 4), (10, 8), (6, 12)])],
    'copy': [('r', (5, 5, 8, 9, 1)), ('p', [(3, 11), (2, 11), (2, 2), (10, 2), (10, 3)])],
    'check': [('p', [(3, 8), (6, 11), (13, 4)])],
    'lock': [('r', (3, 7, 10, 7, 1)), ('p', [(5, 7), (5, 4), (6, 2), (10, 2), (11, 4), (11, 7)])],
    'loop': [('p', [(2, 7), (2, 4), (12, 4), (10, 2)]), ('p', [(12, 4), (10, 6)]), ('p', [(14, 9), (14, 12), (4, 12), (6, 14)]), ('p', [(4, 12), (6, 10)])],
    'close': [('p', [(4, 4), (12, 12)]), ('p', [(12, 4), (4, 12)])],
}

@lru_cache(None)
def font(size=14, role='body'):
    return ImageFont.truetype(str(MONO if role == 'numeric' else BOLD if role == 'heading' else SANS), size*S)

def col(key):
    return C.get(key, key)

class Canvas:
    def __init__(self, name, w=1440, h=900):
        self.name, self.w, self.h = name, w, h
        self.im = Image.new('RGB', (w*S, h*S), C['surface.0'])
        self.d = ImageDraw.Draw(self.im)
        self.controls, self.labels = [], []
        self.alignments = []
        self.clip_bottom = h

    def rect(self, x, y, w, h, fill='surface.1', stroke=None, radius=4, width=1):
        self.d.rounded_rectangle((x*S, y*S, (x+w)*S, (y+h)*S), radius=radius*S,
                                 fill=col(fill) if fill else None,
                                 outline=col(stroke) if stroke else None, width=round(width*S))

    def line(self, pts, color='border.subtle', width=1):
        self.d.line([(round(x*S), round(y*S)) for x,y in pts], fill=col(color), width=round(width*S), joint='curve')

    def text(self, x, y, value, size=14, color='text.primary', role='body', limit=None):
        value = str(value)
        width = self.d.textlength(value, font=font(size,role))/S
        assert x >= 0 and x+width <= self.w and y+size <= self.clip_bottom, (self.name, value, x,y,width)
        if limit is not None:
            assert width <= limit, (self.name, value, width, limit)
        self.d.text((x*S,y*S), value, font=font(size,role), fill=col(color), anchor='lt')
        self.labels.append({'text':value,'rect':[x,y,round(width,2),size],'role':role})
        return width

    def icon(self, name, x, y, color='text.secondary', size=16):
        # Center the existing drawing in its slot; do not refine the artwork.
        points=[]
        for typ,v in ICONS[name]:
            if typ=='p':points.extend(v)
            elif typ=='r':points.extend([(v[0],v[1]),(v[0]+v[2],v[1]+v[3])])
            else:points.extend([(v[0]-v[2],v[1]-v[2]),(v[0]+v[2],v[1]+v[2])])
        x+=(8-(min(p[0] for p in points)+max(p[0] for p in points))/2)*size/16
        y+=(8-(min(p[1] for p in points)+max(p[1] for p in points))/2)*size/16
        for typ, v in ICONS[name]:
            k = size/16
            if typ == 'p':
                self.line([(x+a*k, y+b*k) for a,b in v], color, 1.5*k)
                for a,b in [v[0], v[-1]]:
                    r=.75*k; self.d.ellipse(((x+a*k-r)*S,(y+b*k-r)*S,(x+a*k+r)*S,(y+b*k+r)*S),fill=col(color))
            elif typ == 'r':
                a,b,w,h,r=v;self.rect(x+a*k,y+b*k,w*k,h*k,None,color,r*k,1.5*k)
            else:
                a,b,r=v;self.d.ellipse(((x+(a-r)*k)*S,(y+(b-r)*k)*S,(x+(a+r)*k)*S,(y+(b+r)*k)*S),outline=col(color),width=round(1.5*k*S))

    def centered_text(self,x,y,w,h,value,size=14,color='text.primary',role='body'):
        # Shared font baseline within a row, with the reference ink optically
        # centered. Numeric roles use 0; labels use cap + descender reference Ag.
        face=font(size,role)
        reference=face.getbbox('0' if role=='numeric' else 'Ag',anchor='ls')
        glyph=face.getbbox(str(value),anchor='ls')
        baseline=y+h/2-(reference[1]+reference[3])/(2*S)
        top=baseline+glyph[1]/S
        self.text(x,top,value,size,color,role,limit=w)
        self.alignments.append({'text':str(value),'slot':[x,y,w,h],
                                'ink_center_y':round(baseline+(glyph[1]+glyph[3])/(2*S),3),
                                'baseline':round(baseline,3)})

    def button(self, x,y,w,label='', icon=None, kind='secondary', dropdown=False, focus=False, name=None, h=32):
        fill = {'primary':'accent.primary','selected':'selection.fill','quiet':'surface.1','disabled':'surface.1'}.get(kind,'surface.2')
        border = 'accent.primary' if kind in ('primary','selected') else 'border.subtle' if kind in ('quiet','disabled') else 'border.control'
        ink = 'accent.foreground' if kind == 'primary' else 'text.disabled' if kind == 'disabled' else 'selection.text' if kind == 'selected' else 'text.primary'
        self.rect(x,y,w,h,fill,border)
        if focus: self.rect(x-4,y-4,w+8,h+8,None,'focus.ring',6,2)
        tx=x+12
        icon_x=x+8 if label else x+(w-16)/2
        if icon:self.icon(icon,icon_x,y+(h-16)/2,ink);tx=x+32
        if label:self.centered_text(tx,y,w-(tx-x)-(28 if dropdown else 12),h,label,color=ink)
        if dropdown:self.icon('down',x+w-24,y+(h-16)/2,ink)
        self.controls.append({'type':kind+' button','name':name or label or icon,'rect':[x,y,w,h],'focus':focus,'icon':icon,'icon_only':bool(icon and not label),'dropdown':dropdown,
                              'icon_slot':[icon_x,y+(h-16)/2,16,16] if icon else None,
                              'chevron_slot':[x+w-24,y+(h-16)/2,16,16] if dropdown else None})

    def input(self,x,y,w,value,numeric=True,focus=False,error=False):
        self.rect(x,y,w,32,'surface.2','state.error' if error else 'border.control')
        if focus:self.rect(x-4,y-4,w+8,40,None,'focus.ring',6,2)
        self.centered_text(x+10,y,w-20,32,value,13 if numeric else 14,role='numeric' if numeric else 'body')
        self.controls.append({'type':'numeric input' if numeric else 'text input','name':value,'rect':[x,y,w,32],'focus':focus,'invalid':error})

    def badge(self,x,y,label,icon=None,color='text.secondary'):
        width=self.d.textlength(label,font=font(12))/S+16+(20 if icon else 0)
        self.rect(x,y,width,24,'surface.2','border.subtle',4)
        if icon:self.icon(icon,x+6,y+5,color,14)
        self.centered_text(x+8+(20 if icon else 0),y,width-16-(20 if icon else 0),24,label,12,color)
        return width

    def toggle(self,x,y,label,on=True):
        self.centered_text(x,y,self.cw-48,32,label)
        self.rect(x+self.cw-40,y+6,36,20,'accent.primary' if on else 'surface.3','border.control',10)
        cx=x+self.cw-(16 if on else 30)
        self.d.ellipse(((cx-6)*S,(y+10)*S,(cx+6)*S,(y+22)*S),fill=col('accent.foreground' if on else 'text.secondary'))
        self.controls.append({'type':'toggle','name':label,'rect':[x,y,self.cw,32],'value':on})

    def row(self,y,label,value,choice=False,numeric=True):
        self.centered_text(self.x,y,128,32,label,color='text.secondary')
        if choice:self.button(self.x+136,y,self.cw-136,value,dropdown=True)
        else:self.input(self.x+136,y,self.cw-136,value,numeric)

    def section(self,y,title,closed=False,info=False):
        self.line([(self.x,y),(self.x+self.cw,y)])
        if closed:
            self.button(self.x,y+8,self.cw,title,icon='right',kind='quiet')
        else:
            self.text(self.x,y+14,title,16,role='heading')
            if info:self.button(self.x+self.cw-32,y+6,32,icon='info',kind='quiet',name=title+' details')
        return y+44

    def note(self,y,label,kind='info'):
        self.icon('warning' if kind=='warning' else 'check' if kind=='success' else 'info',self.x,y, 'state.'+kind)
        self.text(self.x+24,y+1,label,12,'text.secondary',limit=self.cw-24)

    def save(self):
        path=OUT/(self.name+'.png')
        self.im.resize((self.w,self.h),Image.Resampling.LANCZOS).save(path,optimize=True)
        MANIFEST.append({'name':self.name,'size':[self.w,self.h], 'controls':self.controls,'labels':self.labels,
                         'alignments':self.alignments,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})


def scene_image(f, kind='volume'):
    """Original deterministic illustrative marks, never native renderer evidence."""
    xend=f.w-f.dock
    f.rect(0,COMMAND_BAR,xend,f.h-COMMAND_BAR-88,'#080d16',radius=0)
    rng=random.Random(40)
    cx,cy=xend*.5,COMMAND_BAR+(f.h-COMMAND_BAR-88)*.47
    # Faint perspective guide, distinct from scientific data coloring.
    for i in range(-3,4):
        f.line([(cx-250+i*24,cy+132+i*14),(cx+188+i*24,cy+200-i*10)],'#172334')
        f.line([(cx-250+i*64,cy+132),(cx-74+i*64,cy+222)],'#172334')
    for i in range(2300 if kind=='particle' else 3400):
        u=rng.random()*math.tau;r=abs(rng.gauss(0,.40))
        a=190*r*math.cos(u);b=115*r*math.sin(u)
        x=cx+a*.91-b*.42;y=cy+a*.30+b*.90
        if kind=='signed':
            x+=-52 if i%2 else 52
            tone=(110,153,211) if i%2 else (203,124,125)
        elif kind=='particle':tone=(158,192,208)
        else:tone=(116+int(60*max(0,1-r)),165+int(32*max(0,1-r)),126)
        if 60<x<xend-50 and 118<y<f.h-164:
            radius=.55 if kind=='particle' else .85
            f.d.ellipse(((x-radius)*S,(y-radius)*S,(x+radius)*S,(y+radius)*S),fill=tone)
    f.text(24,116,'demo.ssc',12,'text.muted')
    f.text(24,136,'3 objects',12,'text.muted')
    f.button(16,64,140,'Frame scene','frame')
    f.button(164,64,150,'Reset camera','reset')
    f.button(322,64,114,'Navigate',dropdown=True)
    # Small orientation guide; no scientific legend or new source representation.
    f.line([(44,f.h-128),(65,f.h-136)],'text.muted')
    f.line([(44,f.h-128),(44,f.h-152)],'text.muted')
    f.line([(44,f.h-128),(28,f.h-140)],'text.muted')
    f.text(69,f.h-144,'X',12,'text.muted');f.text(40,f.h-169,'Y',12,'text.muted');f.text(16,f.h-152,'Z',12,'text.muted')


def shell(name,workspace='Appearance',object_type='field',compact=False,held=False):
    f=Canvas(name,1024 if compact else 1440,640 if compact else 900)
    f.dock=320 if compact else 360;f.x=f.w-f.dock+16;f.cw=f.dock-32
    # Atmospheric depth is confined to the application chrome, never data.
    a=tuple(bytes.fromhex(C['atmosphere.start'][1:]));b=tuple(bytes.fromhex(C['atmosphere.end'][1:]))
    for x in range(f.w):
        c=tuple(round(a[i]+(b[i]-a[i])*x/f.w) for i in range(3))
        f.d.line((x*S,0,x*S,COMMAND_BAR*S),fill=c,width=S)
    for i,key in enumerate(('accent.primary','identity.purple','identity.teal')):f.rect(16+i*6,16,3,16,key,radius=0)
    f.centered_text(42,0,90,COMMAND_BAR,'SimScope',16,role='heading')
    f.button(140,8,100,'Open…','open')
    f.centered_text(260,0,250,COMMAND_BAR,'demo.ssc',14,'text.secondary')
    bx=f.w-472
    for label,ico,width in [('State','state',108),('Export','export',112),('View','view',104),('Help','help',108)]:
        f.button(bx,8,width,label,ico,dropdown=True);bx+=width+8
    scene_image(f,'particle' if object_type=='particles' else 'signed' if 'signed' in name else 'volume')
    f.rect(f.w-f.dock,COMMAND_BAR,f.dock,f.h-COMMAND_BAR-88,'surface.1',radius=0)
    f.line([(f.w-f.dock,COMMAND_BAR),(f.w-f.dock,f.h-88)])
    if compact:
        f.button(f.x,56,f.cw,workspace,workspace.lower(),kind='selected',dropdown=True)
        header=100
    else:
        for i,label in enumerate(('Scene','Appearance','Selection','Analysis')):
            f.button(f.x+(i%2)*168,56+(i//2)*40,160,label,label.lower(),kind='selected' if workspace==label else 'quiet')
        header=148
    f.text(f.x,header,{'particles':'Particles','mesh':'Mesh','field':'Scalar field'}[object_type],18,role='heading')
    f.button(f.x+f.cw-72,header-4,32,icon='eye',name='Hide selected object')
    f.button(f.x+f.cw-32,header-4,32,icon='down',name='Choose object')
    f.icon(object_type,f.x,header+31)
    f.text(f.x+24,header+32,{'particles':'Particle object','mesh':'Triangle mesh','field':'Uniform grid'}[object_type],12,'text.secondary')
    f.text(f.x+132,header+32,'Recorded sample',12,'text.secondary')
    f.text(f.x,header+58,'Source time',12,'text.muted')
    f.text(f.x+88,header+57,'200',13,role='numeric')
    if workspace=='Appearance':f.row(header+80,'Channel','psi_real' if 'signed' in name else 'value' if object_type=='mesh' else 'density',choice=True)
    # Transport: slider is explicitly sample index, never a physical-time scale.
    y=f.h-88
    f.rect(0,y,f.w,64,'surface.1','border.subtle',radius=0)
    f.button(16,y+16,32,icon='previous',name='Previous sample')
    f.button(56,y+16,40,icon='play',kind='disabled' if held else 'primary',name='Play')
    f.button(104,y+16,32,icon='next',name='Next sample')
    f.text(156,y+9,'Sample index',12,'text.secondary')
    f.text(254,y+8,'5 / 9',13,role='numeric')
    f.text(156,y+43,'Union of recorded samples',12,'text.muted')
    end=300 if compact else 530
    f.line([(156,y+32),(end,y+32)],'border.control',3)
    f.line([(156,y+32),((end+156)/2,y+32)],'accent.primary',3)
    tx=(end+156)/2;f.d.ellipse(((tx-5)*S,(y+27)*S,(tx+5)*S,(y+37)*S),fill=C['accent.primary'])
    f.text(end+24,y+9,'Displayed time',12,'text.secondary')
    f.text(end+24,y+36,'200',13,role='numeric')
    if held:
        f.text(end+148,y+9,'Requested time',12,'state.warning')
        f.text(end+148,y+36,'220',13,role='numeric')
        f.button(end+280,y+27,100,'Seek…')
    else:
        f.button(end+148,y+27,116,'Seek…')
    if not compact and not held:
        f.text(end+284,y+9,'Time mode',12,'text.secondary')
        f.button(end+284,y+27,164,'Recorded time',dropdown=True)
        f.text(end+464,y+9,'Rate',12,'text.secondary')
        f.input(end+464,y+27,64,'1')
        f.text(end+536,y+36,'units/s',12,'text.secondary')
    elif compact:
        f.button(584,y+27,164,'Recorded time',dropdown=True)
        f.button(756,y+27,112,'1 unit/s',dropdown=True,name='Playback rate')
    f.button(876 if compact else f.w-224,y+16,32,icon='loop',name='Loop playback')
    f.button(916 if compact else f.w-176,y+16,92 if compact else 160,'Jobs 0',icon='check',kind='quiet')
    f.text(16,f.h-18,'Preparing sample…' if held else 'Ready',12,'state.warning' if held else 'state.success')
    f.text(210,f.h-18,'Source units',12,'text.muted')
    f.text(f.w-160,f.h-18,'No active jobs',12,'text.muted')
    f.clip_bottom=f.h-88
    return f,header+124


def color_group(f,y,signed=False,faint=False):
    y=f.section(y,'Color',info=True)
    f.row(y,'Colormap','coolwarm' if signed else 'viridis',True);y+=40
    f.row(y,'Mapping','Linear',True);y+=40
    f.text(f.x,y+8,'Range',14,'text.secondary')
    f.input(f.x+72,y,112,'-1.298' if signed else '0')
    f.text(f.x+192,y+8,'to',12,'text.secondary')
    f.input(f.x+216,y,f.cw-216,'1.298' if signed else '1.72');y+=44
    x=f.x
    if signed:x+=f.badge(x,y,'Symmetric')+8
    elif faint:x+=f.badge(x,y,'Percentile')+8
    f.badge(x,y,'Locked',icon='lock');y+=32
    f.text(f.x,y,'Based on sample at time 200',12,'text.muted');y+=20
    f.note(y,'No color clipping',kind='success');y+=24
    f.button(f.x,y,164,'Derive range…',icon='right',kind='quiet')
    f.button(f.x+172,y,f.cw-172,'Reset color',kind='quiet');return y+44

def opacity_group(f,y,signed=False):
    y=f.section(y,'Opacity',info=True)
    f.row(y,'Mapping','Magnitude' if signed else 'Linear',True);y+=40
    # Wrapped property labels retain the accepted 128-pixel column.
    for lines,value in [(('Transparent','below'),'0.01' if signed else '0'),(('Full strength','above'),'1.298' if signed else '1.72')]:
        f.text(f.x,y+1,lines[0],14,'text.secondary');f.text(f.x,y+18,lines[1],14,'text.secondary')
        f.input(f.x+136,y,f.cw-136,value);y+=44
    f.text(f.x,y+8,'Strength',14,'text.secondary');f.input(f.x+136,y,72,'0.25')
    f.text(f.x+216,y+10,'/ world unit',12,'text.secondary');y+=40
    f.button(f.x,y,f.cw,'Reset opacity mapping',kind='quiet');return y+44

def volume(name='volume',signed=False):
    f,y=shell(name)
    # Main color and opacity editors are not buried under generic Advanced.
    f.section(y,'Quick setup',closed=True);y+=48
    y=color_group(f,y,signed)
    # Long forms scroll locally. This view shows Color and core Opacity fields;
    # quality/reset continuation is separately shown in the component sheet.
    y=f.section(y,'Opacity',info=True)
    f.row(y,'Mapping','Magnitude' if signed else 'Linear',True);y+=40
    f.text(f.x,y+1,'Transparent',14,'text.secondary');f.text(f.x,y+18,'below',14,'text.secondary')
    f.input(f.x+136,y,f.cw-136,'0.01' if signed else '0');y+=40
    f.text(f.x,y+1,'Full strength',14,'text.secondary');f.text(f.x,y+18,'above',14,'text.secondary')
    f.input(f.x+136,y,f.cw-136,'1.298' if signed else '1.72');y+=40
    f.text(f.x,y+8,'Strength',14,'text.secondary');f.input(f.x+136,y,72,'0.25');f.text(f.x+216,y+10,'/ world unit',12,'text.secondary')
    f.rect(f.w-10,282,4,500,'surface.2',radius=2);f.rect(f.w-10,282,4,342,'border.subtle',radius=2)
    f.save()

def faint(name,inherited=False,compact=False,help_open=False):
    f,y=shell(name,compact=compact)
    y=f.section(y,'Quick setup',info=True)
    f.button(f.x,y,f.cw,'Faint structure',dropdown=True);y+=40
    f.text(f.x,y,'Apply once, then edit any setting.',12,'text.secondary');y+=28
    f.text(f.x,y,'Lower (%)',12,'text.secondary');f.text(f.x+92,y,'Upper (%)',12,'text.secondary');y+=20
    f.input(f.x,y,80,'0' if inherited else '1',focus=not inherited and not help_open)
    f.input(f.x+92,y,80,'100' if inherited else '99')
    f.button(f.x+184,y,f.cw-184,'Apply',kind='primary');y+=44
    f.note(y,'Full sample range selected.' if inherited else 'Values above the chosen range will clip.','info' if inherited else 'warning');y+=28
    y+=12
    if not compact:
        f.section(y,'Color',info=True);y+=44
        f.row(y,'Colormap','viridis',True);y+=40
        f.row(y,'Mapping','Linear',True);y+=40
        f.row(y,'Minimum','0');y+=40
        f.row(y,'Maximum','1.72');y+=40
        f.text(f.x,y,'Current settings',12,'text.muted')
        f.badge(f.x+140,y-6,'Locked',icon='lock');y+=30
        f.section(y,'Opacity',closed=True)
    f.rect(f.w-10,282 if not compact else 234,4,f.h-404,'surface.2',radius=2)
    f.rect(f.w-10,282 if not compact else 234,4,100,'border.subtle',radius=2)
    if help_open:
        f.rect(680,278,384,284,'surface.2','border.control',6)
        f.text(696,300,'Quick setup',16,role='heading')
        f.button(1016,290,32,icon='close',kind='quiet',name='Close quick setup details',focus=True)
        for i,line in enumerate(('Apply a one-time color and opacity setup.',
                                 'Manual settings remain editable.',
                                 'Colormap and both mappings change.',
                                 'Strength, ray step and source values stay',
                                 'unchanged.')):
            f.text(696,344+i*24,line,12,'text.secondary')
        f.button(696,510,344,'Volume display handbook',icon='help')
    f.save()

def loaded_scene():
    f,y=shell('scene','Scene')
    y=236
    y=f.section(y,'Objects')
    for name,kind,desc,selected in [('Scalar field','field','Uniform grid',True),('Particles','particles','Recorded sample',False),('Mesh','mesh','Triangle mesh',False)]:
        f.rect(f.x,y,f.cw,60,'selection.fill' if selected else 'surface.1','accent.primary' if selected else 'border.subtle')
        f.icon(kind,f.x+12,y+12,'selection.text' if selected else 'text.secondary')
        f.text(f.x+40,y+10,name);f.text(f.x+40,y+34,desc,12,'text.secondary')
        f.button(f.x+f.cw-44,y+14,32,icon='eye' if kind!='mesh' else 'hidden',kind='quiet',name=('Hide ' if kind!='mesh' else 'Show ')+name)
        y+=68
    y=f.section(y+4,'Source probe',info=True)
    f.row(y,'Channel','density',True);y+=44
    for i,axis in enumerate('XYZ'):
        x=f.x+i*112;f.text(x,y,axis,12,'text.secondary');f.input(x,y+20,104,'0')
    y+=64
    f.button(f.x,y,148,'Probe source',kind='primary');f.button(f.x+156,y,f.cw-156,'Copy result',icon='copy');y+=44
    f.text(f.x,y,'Value',12,'text.secondary');f.text(f.x+136,y,'0.2875',13,role='numeric');y+=22
    f.text(f.x,y,'Probed at time 200',12,'text.muted');y+=22
    f.toggle(f.x,y,'Show probe marker',False);y+=40
    f.section(y,'Geometry and metadata',closed=True)
    f.save()

def particle():
    f,y=shell('particle','Appearance','particles')
    y=f.section(y,'Representation')
    f.toggle(f.x,y,'Point rendering');y+=40
    f.row(y,'Size multiplier','1');y+=40
    f.row(y,'Brightness','1');y+=48
    y=f.section(y,'Color',info=True)
    f.row(y,'Colormap','viridis',True);y+=40
    f.row(y,'Range policy','Per sample',True);y+=40
    f.toggle(f.x,y,'Show particle legend',False);y+=44
    f.button(f.x,y,f.cw,'Range and normalization',icon='right',kind='quiet');y+=44
    f.section(y,'Display filters',closed=True);y+=48
    f.section(y,'Recorded history',closed=True);y+=48
    f.section(y,'Size and brightness channels',closed=True)
    f.save()

def selection():
    f,y=shell('selection','Selection','particles')
    y=236;y=f.section(y,'Source snapshot',info=True)
    f.rect(f.x,y,f.cw,76,'surface.2','border.subtle')
    f.icon('lock',f.x+12,y+12);f.text(f.x+36,y+12,'demo.ssc')
    f.text(f.x+12,y+42,'Bound snapshot',12,'state.success');f.text(f.x+164,y+42,'9 samples',13,role='numeric');y+=88
    f.button(f.x,y,f.cw,'Bind source snapshot…',icon='state');y+=48
    y=f.section(y,'Create selection')
    f.row(y,'Object','Particles',True);y+=40
    f.row(y,'Selection type','Persistent IDs',True);y+=48
    f.text(f.x,y,'Particle IDs',14,'text.secondary');y+=24
    f.input(f.x,y,f.cw,'9007199254740993',focus=True);y+=48
    f.text(f.x,y,'Name',14,'text.secondary');y+=24
    f.input(f.x,y,f.cw,'Example selection',numeric=False);y+=44
    f.button(f.x,y,168,'Create selection',kind='primary');y+=48
    f.section(y,'Saved selections',closed=True)
    f.save()

def analysis(results=False):
    f,y=shell('results' if results else 'analysis','Analysis','particles')
    y=236
    y=f.section(y,'Results' if results else 'Analysis type')
    f.button(f.x,y,f.cw,'Particle count' if results else 'Population counts',dropdown=True);y+=48
    for label,value in [('Source','demo.ssc'),('Object','Particles'),('Selection','All particles'),('Units','particles')]:
        f.text(f.x,y,label,12,'text.muted');f.text(f.x+112,y,value,14);y+=28
    y+=8
    if results:
        f.badge(f.x,y,'Complete',icon='check',color='state.success');y+=40
        f.text(f.x,y,'Recorded range',14,'text.secondary');f.text(f.x+160,y,'0 to 400',13,role='numeric');y+=36
        f.text(f.x,y,'9 source samples',12,'text.muted');y+=36
        f.button(f.x,y,f.cw,'Export numerical data…',icon='export');y+=44
        f.button(f.x,y,f.cw,'Return to viewport',icon='view');y+=44
        f.section(y,'Request details',closed=True)
        # Expanded result temporarily occupies the viewport, not a second dock.
        f.rect(16,104,1048,672,'surface.1','border.subtle',4)
        f.text(40,128,'Particle count',18,role='heading')
        f.text(40,160,'Population counts',14,'text.secondary')
        f.badge(904,124,'Complete',icon='check',color='state.success')
        f.text(40,206,'Particles',12,'text.secondary')
        for i,v in enumerate([64,48,32,16,0]):
            yy=246+i*42;f.line([(104,yy),(1016,yy)],'surface.3');f.text(56,yy-6,str(v),13,'text.secondary','numeric')
        points=[]
        for i,v in enumerate([64,62,58,56,52,48,46,44,40]):
            xx=104+i*114;yy=414-v*168/64;points.append((xx,yy))
        f.line(points,'accent.primary',2)
        for xx,yy in points:f.d.ellipse(((xx-3)*S,(yy-3)*S,(xx+3)*S,(yy+3)*S),fill=C['accent.primary'])
        for i,v in enumerate([0,100,200,300,400]):f.text(100+i*228,430,str(v),13,'text.secondary','numeric')
        f.text(440,466,'Recorded time (source units)',12,'text.secondary')
        f.rect(40,512,1000,36,'surface.2','border.subtle')
        for x,txt in [(56,'Recorded time'),(290,'Count'),(524,'Support'),(776,'Source samples')]:f.text(x,524,txt,12,'text.secondary')
        for i,(t,n) in enumerate([(0,64),(50,62),(100,58)]):
            yy=548+i*40;f.line([(40,yy+40),(1040,yy+40)],'border.subtle')
            f.text(56,yy+12,str(t),13,role='numeric');f.text(290,yy+12,str(n),13,role='numeric');f.text(524,yy+12,'Complete',12);f.text(776,yy+12,'Recorded',12)
        f.text(40,712,'3 of 9 rows',12,'text.muted')
        f.button(704,696,164,'Copy exact value',icon='copy');f.button(880,696,160,'Next page',icon='next')
    else:
        y=f.section(y,'Recorded range')
        f.row(y,'Start inclusive','0');y+=40
        f.row(y,'End inclusive','400');y+=44
        f.button(f.x,y,f.cw,'Use full range',kind='quiet');y+=48
        f.section(y,'Missing support',closed=True);y+=48
        f.button(f.x,y,164,'Run analysis',kind='primary');f.button(f.x+172,y,f.cw-172,'Results',icon='analysis')
    f.save()

def specimens():
    f=Canvas('components');f.x=40;f.cw=400
    f.text(40,32,'Midnight scientific',18,role='heading')
    f.text(40,64,'Control and copy review',14,'text.secondary')
    # Three intentionally distinct specimen areas, outside application chrome.
    f.rect(24,104,432,744,'surface.1','border.subtle')
    f.rect(480,104,448,744,'surface.1','border.subtle')
    f.rect(952,104,464,744,'surface.1','border.subtle')
    f.text(40,124,'Actions and menus',16,role='heading')
    f.button(40,164,168,'Apply',kind='primary',focus=True)
    f.button(224,164,152,'Reset color')
    f.button(392,164,32,icon='copy',name='Copy value')
    f.button(40,220,164,'State',icon='state',dropdown=True,kind='selected')
    f.rect(40,260,384,184,'surface.2','border.control',6)
    for i,label in enumerate(('Save scene recipe…','Load scene recipe…','Save analysis recipe…','Load analysis recipe…')):
        y=272+i*40+(8 if i>=2 else 0);f.icon('state',52,y+8);f.centered_text(80,y,320,32,label)
    f.line([(52,354),(412,354)])
    f.text(40,476,'Quick setup',16,role='heading')
    f.rect(40,512,384,220,'surface.2','border.control',6)
    for i,(title,subtitle) in enumerate([('Dense core','Use the full sample range'),('Faint structure','Choose percentiles before applying'),('Signed field','For positive and negative data')]):
        y=524+i*68
        if i==1:f.rect(48,y-4,368,64,'selection.fill',radius=4)
        f.text(64,y+4,title);f.text(64,y+30,subtitle,12,'text.secondary')
    f.text(40,768,'Apply once, then edit any setting.',12,'text.secondary')
    f.text(40,796,'No persistent active-setup badge.',12,'text.muted')
    f.x=496;f.cw=416
    f.text(496,124,'Editing and feedback',16,role='heading')
    f.text(496,168,'Minimum',14,'text.secondary');f.input(640,156,244,'abc',error=True,focus=True)
    f.icon('warning',496,208,'state.error');f.text(520,210,'Enter a finite number.',12,'state.error')
    f.text(496,240,'Current value: 0',12,'text.secondary')
    f.text(496,272,'Enter to apply. Escape to restore.',12,'text.muted')
    f.toggle(496,316,'Show probe marker')
    f.button(496,376,388,'Volume quality',icon='down',kind='selected')
    f.row(428,'Ray step','0.5');f.text(640,468,'world units',12,'text.muted')
    f.text(496,500,'Finer steps cost more render time.',12,'text.secondary')
    f.button(496,544,240,'Reset opacity mapping')
    f.badge(496,604,'Locked',icon='lock');f.badge(624,604,'Symmetric')
    f.note(654,'Color clips above the maximum.','warning')
    f.note(698,'Setup applied. Settings updated.','success')
    f.button(496,750,388,'Apply',kind='disabled')
    f.text(496,800,'Signed field requires values of both signs.',12,'text.secondary')
    f.x=968;f.cw=432
    f.text(968,124,'Icons and metadata',16,role='heading')
    names=['open','state','export','view','help','frame','reset','play','pause','previous','next','eye','hidden','particles','field','mesh','scene','appearance','selection','analysis','warning','info','down','right','copy','check','lock','loop']
    for i,name in enumerate(names):
        x=976+(i%4)*104;y=172+(i//4)*64
        f.icon(name,x+28,y,'text.primary',20)
        f.text(x,y+30,name.capitalize(),12,'text.secondary',limit=100)
    f.text(976,648,'Source probe',16,role='heading')
    for i,(label,value) in enumerate([('Value','0.2875'),('Probed at','200'),('Displayed time','220')]):
        f.text(976,686+i*32,label,14,'text.secondary');f.text(1152,686+i*32,value,13,role='numeric')
    f.badge(976,792,'Earlier sample',icon='info',color='state.info')
    f.save()

def transport():
    f,y=shell('time-difference',held=True)
    f.section(y,'Quick setup',closed=True)
    color_group(f,y+48,False)
    f.save()

def seek_target():
    f,y=shell('seek-target')
    f.section(y,'Quick setup',closed=True)
    color_group(f,y+48,False)
    f.rect(536,606,344,190,'surface.2','border.control',6)
    f.text(552,628,'Seek time',16,role='heading')
    f.button(832,618,32,icon='close',kind='quiet',name='Close seek target')
    f.text(552,668,'Target',14,'text.secondary')
    f.input(680,656,184,'240',focus=True)
    f.text(552,704,'Recorded source units',12,'text.muted')
    f.button(552,748,144,'Go',kind='primary')
    f.button(704,748,160,'Cancel')
    f.save()

def volume_details():
    f,y=shell('volume-details')
    y=opacity_group(f,y)
    y=f.section(y,'Volume quality',info=True)
    f.row(y,'Ray step','0.5');y+=40
    f.text(f.x+136,y,'world units',12,'text.muted');y+=28
    f.text(f.x,y,'Finer steps cost more render time.',12,'text.secondary');y+=32
    for title in ('Slice','Clipping','Surface'):
        f.section(y,title,closed=True);y+=48
    f.rect(f.w-10,282,4,500,'surface.2',radius=2);f.rect(f.w-10,490,4,292,'border.subtle',radius=2)
    f.save()

def mesh():
    f,y=shell('mesh','Appearance','mesh')
    y=f.section(y,'Color',info=True)
    f.row(y,'Color mode','Scalar',True);y+=40
    f.row(y,'Colormap','viridis',True);y+=40
    f.row(y,'Minimum','0');y+=40
    f.row(y,'Maximum','1');y+=48
    y=f.section(y,'Representation')
    f.toggle(f.x,y,'Wireframe',True)
    # Illustrative object boundary, not a new viewer mesh capability.
    for pts in [[(392,310),(680,358),(688,538),(400,490),(392,310)],[(392,310),(492,252),(778,300),(680,358)],[(680,358),(778,300),(786,480),(688,538)],[(400,490),(492,252)],[(392,310),(688,538)]]:
        f.line(pts,'#74998a',1)
    f.save()

def help_detail():
    f,y=shell('color-details')
    y=color_group(f,y+48)
    f.rect(704,328,344,204,'surface.2','border.control',6)
    f.text(720,348,'Color range',16,role='heading')
    f.button(1000,340,32,icon='close',kind='quiet',name='Close color details')
    for i,line in enumerate(('Values outside the range use endpoint','colors. Source values stay unchanged.')):
        f.text(720,392+i*22,line,12,'text.secondary')
    f.button(720,468,296,'Rendering handbook',icon='help')
    f.save()

def svg_icons():
    parts=['<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">']
    for name, shapes in ICONS.items():
        parts.append(f'<symbol id="{name}" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">')
        for typ,v in shapes:
            if typ=='p':parts.append('<polyline points="'+' '.join(f'{x},{y}' for x,y in v)+'"/>')
            elif typ=='r':
                x,y,w,h,r=v;parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}"/>')
            else:
                x,y,r=v;parts.append(f'<circle cx="{x}" cy="{y}" r="{r}"/>')
        parts.append('</symbol>')
    parts.append('</svg>');(OUT/'icons.svg').write_text('\n'.join(parts)+'\n')

def write_layout():
    """One evidence record per line; avoid thousands of formatting-only lines."""
    metadata={'token_sha256':hashlib.sha256(TOKEN_PATH.read_bytes()).hexdigest(),
              'body_font':str(SANS),'heading_font':str(BOLD),
              'numeric_font':str(MONO.relative_to(ROOT)),'icons':list(ICONS),
              'command_bar_height':COMMAND_BAR,'input_scope':'Desktop keyboard and mouse/trackpad',
              'icon_status':'Provisional; native review in UX3, final refinement in UX8'}
    lines=['{']+[f'  "{key}": {json.dumps(value)},' for key,value in metadata.items()]
    lines.append('  "figures": [')
    for i,figure in enumerate(MANIFEST):
        lines.append('    {')
        for key in ('name','size','sha256'):
            lines.append(f'      "{key}": {json.dumps(figure[key])},')
        for key in ('controls','labels','alignments'):
            lines.append(f'      "{key}": [')
            lines.extend('        '+json.dumps(row)+(',' if j<len(figure[key])-1 else '')
                         for j,row in enumerate(figure[key]))
            lines.append('      ]'+(',' if key!='alignments' else ''))
        lines.append('    }'+(',' if i<len(MANIFEST)-1 else ''))
    lines.extend(['  ]','}'])
    (OUT/'layout.json').write_text('\n'.join(lines)+'\n')

if __name__=='__main__':
    assert SANS.is_file() and BOLD.is_file() and MONO.is_file()
    loaded_scene();particle();volume();faint('faint-inherited',True);faint('faint-edited')
    volume('signed',True);selection();analysis();analysis(True);faint('compact',compact=True)
    specimens();transport();seek_target();volume_details();mesh();help_detail()
    faint('quick-setup-details',help_open=True);svg_icons()
    write_layout()
    print(f'Rendered {len(MANIFEST)} static mockups with {len(ICONS)} vector icons.')

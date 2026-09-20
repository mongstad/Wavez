"""Render static issue-14 review diagrams, not an interactive prototype.
Run from repository root with Python + Pillow. Outputs only to this directory.
"""
from pathlib import Path
import json
import os
from PIL import Image, ImageDraw, ImageFont
OUT=Path(__file__).resolve().parent
FONT=Path(os.environ.get('UX_WIREFRAME_FONT', '/usr/share/fonts/google-noto/NotoSans-Regular.ttf'))
COL={'bg':'#0B101B','panel':'#111A29','input':'#1A2638','raised':'#243249','text':'#E6EAF0','muted':'#9AA5B3','border':'#465B76','accent':'#8CB8FF','warn':'#E8BF72'}
manifest=[]
class Frame:
 def __init__(self,w,h):
  self.w,self.h=w,h;self.im=Image.new('RGB',(w,h),COL['bg']);self.d=ImageDraw.Draw(self.im);self.overflow=[]
 def box(self,xy,fill='panel'):
  self.d.rectangle(xy,fill=COL[fill],outline=COL['border'])
 def text(self,x,y,text,size=14,color='text'):
  text=text.replace('▾','v').replace('▸','>').replace('↓','(scroll)')
  font=ImageFont.truetype(str(FONT),size)
  if x+self.d.textlength(text,font=font)>self.w or y+size>self.h:self.overflow.append(text)
  self.d.text((x,y),text,font=font,fill=COL[color])
 def wrap(self,x,y,text,width,size=14,color='text'):
  font=ImageFont.truetype(str(FONT),size);line='';lines=[]
  for word in text.split():
   test=(line+' '+word).strip()
   if self.d.textlength(test,font=font)>width and line:lines.append(line);line=word
   else:line=test
  if line:lines.append(line)
  for line in lines:
   if self.d.textlength(line,font=font)>width:self.overflow.append(line)
   self.text(x,y,line,size,color);y+=20
  return y
 def button(self,x,y,w,text):
  self.box((x,y,x+w,y+32),'input');self.text(x+8,y+7,text)
 def save(self,name):
  assert not self.overflow,self.overflow
  self.im.save(OUT/(name+'.png'),optimize=True)
  manifest.append({'name':name,'logical_size':[self.w,self.h],'overflowing_words':self.overflow})

def shell(name,kind='volume',w=1440,h=900,save=True):
 f=Frame(w,h);dock=320 if w<1200 else 360;x=w-dock;bottom=h-88
 f.box((0,0,w,40));f.text(12,11,'Open   |   '+('No capture' if kind=='empty' else 'combined.ssc  ·  Source details…'))
 f.text(w-290,11,'State   Export   View   Help')
 f.box((0,bottom,w,h-24));f.text(12,bottom+7,'Transport unavailable — open a capture with complete records' if kind=='empty' else 'Previous    Play / Pause    Next       Sample index (union)  1 / 9')
 f.text(12,bottom+36,'No recorded time or samples available' if kind=='empty' else 'Mode: Recorded time    Displayed t: 0    Seek: [ 0 ] [Go]    Rate: [ 1 ] units / playback second    Loop')
 f.box((0,h-24,w,h));f.text(12,h-20,'No capture' if kind=='empty' else ('Invalid draft: last committed mapping retained' if kind=='error' else ('Export: choose a new filename' if kind=='export' else 'Ready')),12)
 f.text(w-250,h-20,'Jobs (1)  ·  Open / Cancel' if kind=='export' else 'Jobs (0)  ·  Details',12)
 if kind=='empty':
  f.text(w//2-145,250,'Open a SIMSCP3 capture',18);f.button(w//2-105,300,210,'Open capture…')
  f.text(w//2-180,355,'No source bound. Scientific controls appear',14,'muted');f.text(w//2-180,377,'when the capture supplies their data.',14,'muted')
 else:
  f.box((x,40,w,bottom));f.button(x+12,52,dock-24,'Workspace: '+({'scene':'Scene','particle':'Appearance','selection':'Selection','analysis':'Analysis','results':'Analysis'}.get(kind,'Appearance'))+'  ▾')
  context={'particle':'particles · Particle','selection':'Snapshot bound · particles','analysis':'Temporal · particles · Selection A','results':'Population · Result A'}.get(kind,'density · Field · signed')
  f.text(x+12,98,context,14,'accent');f.text(x+12,121,'Source sample t: 0  ·  exact',12,'muted')
  f.text(16,56,'Frame scene   Reset camera   Navigation   Show panels',14)
  f.text(24,195,'Scientific viewport (schematic)',18,'muted')
  f.text(24,226,'No simulated data or new rendering is depicted.',14,'muted')
  f.box((24,280,min(x-24,720),458),'bg')
  notes={
   'volume':['1  Scene: hide only the particle row.','2  Appearance: choose this field and signed channel.','3  Apply Signed field once; inspect resolved mappings.','Color and opacity stay independent after Apply.'],
   'particle':['1  This form affects the named particle object.','2  Point rendering changes representation only.','3  Display type filters do not change selection members.','Existing particle legend remains particle-scoped.'],
   'selection':['1  Bind an explicit source snapshot.','2  Choose scientific source object and selection type.','3  Enter exact IDs, then Create.','Scene row selection never defines scientific membership.'],
   'analysis':['1  Effective request context stays with the task.','2  Choose operation and inclusive range.','3  Run explicitly; hide panel without cancelling.','Results retain source, units and missing-support meaning.'],
   'results':['1  Choose a named result, inspect provenance.','2  Exact lookup reaches members beyond the preview.','3  Values / Export operate on the complete result.','Expand temporarily; Return restores previous viewport.'],
   'export':['1  Export form has its own output time domain.','2  Fixed footer: Start / Cancel / Close panel.','3  Close continues work; Jobs reopens it.','Failure details remain until acknowledged.'],
   'error':['1  Invalid draft stays editable.','2  Last committed mapping remains in effect.','3  Correct and Enter, or Escape to discard draft.','Show panels and Exit fullscreen always have mouse paths.']}
  for j,line in enumerate(notes.get(kind,notes['volume'])):f.wrap(36,294+j*38,line,min(x-60,670),14)
  y=154
  def group(title,lines):
   nonlocal y
   if y > bottom-64: return
   f.text(x+12,y,title,14,'accent');y+=26
   for line in lines:
    if y+38>bottom-48:
     f.text(x+12,bottom-30,'More controls below (dock scroll)',12,'muted');y=bottom;return
    y=f.wrap(x+12,y,line,dock-34,14)+12
   y+=10
  if kind=='scene':
   group('Objects · choose context, not members',['[On] particles · Particle · t=0','[On] density · Field · t=0','[On] surface · Mesh · t=0'])
   group('Selected: density',['Kind: Uniform grid field','Source: combined.ssc · committed prefix','[ Appearance for density ]'])
   group('Source probe',['Channel: signed   World X/Y/Z','[ Probe source ]   Show marker: On','Last probe: not yet sampled'])
   group('> Geometry / Metadata',[])
  elif kind in ['volume','error']:
   group('Display starting point · apply once',['Action: Signed field  ▾','Color ± max|value|; magnitude opacity','[ Apply starting point ]'])
   group('Color · frozen from signed @ t=0',['Colormap: coolwarm   Normalization: Linear','Bounds: [ -96 ]  [ 96 ]' if kind!='error' else 'Minimum draft: [ abc ]  ! Enter a finite value','No clipping at current source sample','▸ Derive range from sample   Reset color'])
   group('Opacity · Magnitude 0–96 (independent)',['Mapping: Magnitude  ▾','Zero: [ 0 ]   Full: [ 96 ]   Strength: [ 0.25 ]','Reset opacity mapping'])
   group('Sampling quality',['Ray step: [ 0.5 ] world units','Smaller steps cost more GPU time.'])
   group('▸ Slice   ▸ Clipping   ▸ Surface',[])
  elif kind=='particle':
   group('Representation',['Visible: On    Point rendering: On','Size multiplier: [ 1 ]   Brightness: [ 1 ]'])
   group('Color',['Channel: value   Colormap: viridis','Policy: Automatic per sample','Show particle legend: On','▸ Normalization / Freeze interval'])
   group('Recorded history',['Off · Requires explicit IDs; Scientific suppresses history'])
   group('▸ Display type filters',[]);group('▸ Size / brightness channels',[]);group('▸ Spatial display slice',[])
  elif kind=='selection':
   group('Source binding',['[ Bind source snapshot ]','Object: particles   Source prefix: saved'])
   group('Definitions',['Selection A  ·  exact IDs','[ Rename ] [ Duplicate ] [ Delete ]'])
   group('Create selection',['Type: Persistent IDs','IDs: 9007199254740993','Name: Selection B','[ Create ] [ Cancel query ]'])
   group('▸ Value filter   ▸ Groups',[]);group('▸ Surface / cohort tools',[])
  elif kind=='analysis':
   group('Request context',['Capture: combined.ssc · bound prefix','Object: particles · Selection A','Channel: value · units: unknown'])
   group('Temporal request',['Operation: Population counts','Axis: Recorded time','Start inclusive: [ 0 ]   End inclusive: [ 2 ]','[ Use full layer range ]'])
   group('▸ Scientific interpretation',[]);group('▸ Missing support',[])
   group('Actions',['[ Run analysis ] [ Cancel ]','[ Results… ]'])
  elif kind=='results':
   group('Named result / provenance',['Result A · Population counts','Source: combined.ssc · pinned prefix','Range: [0, 2] inclusive · no inferred samples'])
   group('Inspect',['Series: Selection A','Exact member address: [ id:… ]','[ Show plot ] [ Expand results ]'])
   group('Values',['Full rows: available; preview bounded','[ First page ] [ Next page ]','[ Export numerical data… ]','[ Return to viewport ]'])
  if kind=='export':
   # Fixed footer and scrollable form illustrated over viewport; no second dock.
   left,top,right,foot=160,120,min(w-40,960),680
   f.box((left,top,right,foot),'raised');f.text(left+20,top+16,'Export video · proposed fixed actions',18)
   for j,line in enumerate(['Range: Custom   Start: [ 0 ]   End exclusive: [ 2 ]','Resolution: 1920 × 1080   Output FPS: 30','Recorded units / video second: [ 1 ]','Camera: Current locked   Rendering: Current state','Overlays: Off   History: Off','Output: /chosen/path/video.mp4   [Browse…]','! File exists. Choose a new filename.','Scrollable body includes quality, sidecars and quotas.']):
    f.text(left+20,top+66+j*44,line,14,'warn' if line.startswith('!') else 'text')
   f.box((left,foot-60,right,foot),'panel');f.text(left+20,foot-39,'Start (unavailable)   Cancel (unavailable)   Close panel',14)
 if save:f.save(name)
 assert not f.overflow,f.overflow
 return f

if __name__=='__main__':
 for kind in ['empty','scene','volume','particle','selection','analysis','results','export','error']:
  shell(kind,kind)
 shell('compact','volume',1024,640)
 # Detail sheet demonstrates adjacent inputs without changing preset semantics.
 f=Frame(800,620)
 f.text(24,20,'Volume detail · Faint structure / probe / recovery',18)
 for x,title,lines in [
  (24,'Starting point: Faint structure',['Choose percentiles explicitly:','Lower: [ 1 ]   Upper: [ 99 ]','Values above P99 saturate.','[ Apply starting point ]','After Dense core, show [0] [100]','until the user edits them.','No persistent active-preset badge.']),
  (414,'Source probe · density',['World X [0]  Y [0]  Z [0]','[ Probe source ]','Last probed: density @ t=0','Result: exact copyable source value','Current displayed t=2 (different)','Show probe marker: Off','Proposed timestamp binding, not current.'])]:
  f.box((x,70,x+362,420));f.text(x+12,86,title,14,'accent')
  for i,line in enumerate(lines):f.wrap(x+12,124+i*38,line,338,14)
 f.wrap(24,460,'Color reset: linear 0–1 color bounds/mapping only. Opacity reset: linear 0–1 opacity mapping only. Neither resets strength, step, particles or camera.',740)
 f.wrap(24,550,'Fullscreen / hidden dock: [Show panels] [Exit fullscreen]. Invalid input: retain draft and error; Enter commits valid input, Escape restores last committed value.',740)
 f.save('details')
 f=shell('results-expanded','results',save=False)
 f.box((16,100,1064,780),'panel')
 f.text(32,116,'Results workbench · temporary viewport expansion · Return to viewport',18)
 f.text(32,158,'Result A / combined.ssc / pinned source prefix / Population counts / [0,2] inclusive')
 f.box((32,202,1048,470),'bg')
 f.text(48,220,'Bounded plot area (schematic, no invented observations)',14,'muted')
 f.text(48,252,'Axes, units, gaps and hover provenance remain part of the result.')
 f.box((32,492,1048,690),'input')
 f.text(48,510,'Exact values table: time | member address | value | support (schematic)')
 f.text(48,550,'Copy exact value    First page    Next page    Export complete numerical data')
 f.text(48,590,'Horizontal scroll allowed for exact result columns; never truncate exported rows.')
 f.text(32,728,'This workbench replaces viewport space temporarily; it does not add a permanent second dock.')
 f.save('results-expanded')
 # Full 4K static diagrams stay ignored; retain only a compact contact sheet.
 root=OUT.parents[2]
 target=root/'results/issue-14-review/wireframe-4k';target.mkdir(parents=True,exist_ok=True)
 contact=Frame(1600,960)

 for i,scale in enumerate([1,1.25,1.5,2]):
  w,h=round(3840/scale),round(2160/scale)
  frame=shell('scale','volume',w,h,save=False)
  full=frame.im.resize((3840,2160),Image.Resampling.LANCZOS);full.save(target/(str(scale)+'.png'))
  x=(i%2)*800;y=(i//2)*480
  contact.text(x+12,y+6,f'4K at {scale*100:g}% · static layout; not physical DPI',14)
  contact.im.paste(full.resize((800,450)),(x,y+28))
  manifest.append({'physical_size':[3840,2160],'scale':scale,'logical_size':[w,h],'dock':360,'viewport':[w-360,h-128],'review':'allocation arithmetic; not native DPI acceptance'})
 contact.im.save(OUT/'scale-review.png',optimize=True)
 (OUT/'wireframe-layout.json').write_text(json.dumps(manifest,indent=2)+'\n')

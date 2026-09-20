"""Focused documentation/evidence checks for issue #14, run from repo root."""
import json
import re
import subprocess
from pathlib import Path
from PIL import Image
BASE='68e3b5abb548d2e95ba5ae5b8e57e03d652de502'
ROOT=Path(__file__).resolve().parents[3]
DOCS=[ROOT/p for p in ['UX_IMPLEMENTATION_PLAN.md','docs/CURRENT_STATUS.md','docs/UX1_DESIGN_SYSTEM.md','docs/UX_INFORMATION_ARCHITECTURE.md','docs/UX_CONTROL_MAP.md','docs/UX_IA_REVIEW.md','docs/evidence/issue-14/wireframes.md']]
def anchors(path):
 result=set();seen={}
 for line in path.read_text().splitlines():
  if re.match(r'^#+ ',line):
   slug=re.sub(r'[^\w\- ]','',re.sub(r'^#+ ','',line).lower()).replace(' ','-')
   n=seen.get(slug,0);seen[slug]=n+1;result.add(slug+(f'-{n}' if n else ''))
 return result
links=0
for doc in DOCS:
 for target in re.findall(r'\]\(([^)]+)\)',doc.read_text()):
  if target.startswith(('https:','http:')):continue
  path,_,anchor=target.partition('#');resolved=(doc.parent/path).resolve() if path else doc
  assert resolved.exists(),(doc,target)
  if anchor and resolved.suffix=='.md':assert anchor in anchors(resolved),(doc,target)
  links+=1
control=(ROOT/'docs/UX_CONTROL_MAP.md').read_text()
ids=re.findall(r'^\| (IA-\d+) ·',control,re.M)
assert len(ids)==96 and len(set(ids))==96
symbols=re.findall(r'\]\(\.\./([^)]*\.gd)\) `([^`]+)`',control)
for path,symbol in symbols:
 assert re.search(r'^func '+re.escape(symbol)+r'\(', (ROOT/path).read_text(),re.M),(path,symbol)
for row in control.splitlines():
 if row.startswith('| IA-'):
  cells=row.split('|')[1:-1]
  assert len(cells)==8 and all(c.strip() for c in cells),row
images=[]
for path in (ROOT/'docs/evidence/issue-14').glob('*.png'):
 with Image.open(path) as im:im.verify()
 assert path.stat().st_size<1048576,path
 images.append(path.name)
layout=json.loads((ROOT/'docs/evidence/issue-14/wireframe-layout.json').read_text())
assert len([x for x in layout if 'scale' in x])==4
assert all(not x.get('overflowing_words') for x in layout)
changed=subprocess.check_output(['git','diff','--name-only',BASE],cwd=ROOT,text=True).splitlines()
changed+=subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=ROOT,text=True).splitlines()
allowed={'UX_IMPLEMENTATION_PLAN.md','docs/CURRENT_STATUS.md','docs/UX1_DESIGN_SYSTEM.md','docs/UX_INFORMATION_ARCHITECTURE.md','docs/UX_CONTROL_MAP.md','docs/UX_IA_REVIEW.md'}
assert all(p in allowed or p.startswith('docs/evidence/issue-14/') for p in changed),changed
assert not subprocess.check_output(['git','diff',BASE,'--','viewer','simscope_export','tests','tools'],cwd=ROOT)
subprocess.run(['git','diff','--check'],cwd=ROOT,check=True)
print(json.dumps({'local_links_and_anchors':links,'inventory_rows':len(ids),'verified_source_symbols':len(symbols),'pngs_verified':len(images),'scale_allocations':4,'production_diff':'empty','scope':'pass','whitespace':'pass'},indent=2))

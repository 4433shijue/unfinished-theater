"""Regenerate the renamed OFL subset from repo root; requires fonttools.
The generated font is committed, so normal Flutter builds need no Python.
"""
from pathlib import Path
from fontTools import subset
from fontTools.ttLib import TTFont
chars=set(range(32,127))
for cp in range(0x10000):
 try:chr(cp).encode('gb2312');chars.add(cp)
 except UnicodeEncodeError:pass
for p in Path('lib').rglob('*.dart'):chars.update(map(ord,p.read_text(encoding='utf-8')))
f=TTFont('assets/fonts/SourceHanSansSC-Regular.otf')
opts=subset.Options();opts.name_IDs=['*'];opts.name_legacy=True;opts.name_languages=['*']
s=subset.Subsetter(options=opts);s.populate(unicodes=chars);s.subset(f)
for r in f['name'].names:
 if r.nameID in (1,3,4,6,16,17):
  value={1:'Theater Bootstrap Sans',3:'TheaterBootstrapSans-Regular',4:'Theater Bootstrap Sans Regular',6:'TheaterBootstrapSans-Regular',16:'Theater Bootstrap Sans',17:'Regular'}[r.nameID]
  r.string=value.encode(r.getEncoding())
if 'CFF ' in f:
 c=f['CFF '].cff;c.fontNames=['TheaterBootstrapSans-Regular'];c.topDictIndex[0].FamilyName='Theater Bootstrap Sans';c.topDictIndex[0].FullName='Theater Bootstrap Sans Regular'
f.save('assets/fonts/TheaterBootstrapSans.otf')
print('Generated assets/fonts/TheaterBootstrapSans.otf')

"""Build a static UI font containing every character used by game sources."""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools import subset

root = Path(__file__).resolve().parents[1]
font_path = root / 'assets/fonts/NotoSansTC.ttf'
characters = set(range(32, 127))
for folder in ('scripts', 'scenes'):
    for source in (root / folder).rglob('*'):
        if source.suffix in ('.gd', '.tscn', '.tres'):
            characters.update(map(ord, source.read_text(encoding='utf-8-sig')))
font = TTFont(font_path)
before_size = font_path.stat().st_size
original_map = font.getBestCmap()
required = characters.intersection(original_map)
if 'fvar' in font:
    font = instantiateVariableFont(font, {'wght': 500}, inplace=False)
options = subset.Options()
options.name_IDs = ['*']
options.name_languages = ['*']
options.notdef_glyph = True
options.notdef_outline = True
subsetter = subset.Subsetter(options=options)
subsetter.populate(unicodes=required)
subsetter.subset(font)
# Preserve the font license and give the modified subset its own family name.
for name_id, value in [(1,'Dungeon UI'),(2,'Regular'),(3,'DungeonUI-Subset'),(4,'Dungeon UI'),(6,'DungeonUI-Regular'),(16,'Dungeon UI'),(17,'Regular')]:
    font['name'].setName(value,name_id,3,1,0x409)
font.save(font_path)
verified = TTFont(font_path)
missing = required.difference(verified.getBestCmap())
assert not missing, f'Missing required UI characters: {missing}'
assert font_path.stat().st_size < before_size, 'Font size did not decrease'
print(f'UI_FONT_PASS: {len(required)} characters; {before_size} -> {font_path.stat().st_size} bytes')

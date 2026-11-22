"""Build a static UI font containing every character used by game sources."""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.ttLib.tables._g_l_y_f import Glyph
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools import subset

# Godot Label/RichTextLabel append U+200B (ZWSP) to every paragraph as a
# break opportunity. The advanced text server ignores it when the font has
# no glyph; the fallback text server draws .notdef (a tofu box) instead.
# Noto Sans TC does not include U+200B, so the subset injects a zero-width
# empty glyph. Also keep typographic characters the engine may insert.
ENGINE_CHARS = {
    0x00A0,  # NBSP
    0x00AD,  # soft hyphen
    0x2026,  # ellipsis (text overrun)
}


def inject_zerowidth_glyph(font: TTFont, codepoint: int, name: str) -> None:
    if codepoint in (font.getBestCmap() or {}):
        return
    if 'glyf' not in font:
        raise SystemExit(f'Cannot inject U+{codepoint:04X}: font has no glyf table')
    glyph = Glyph()
    glyph.numberOfContours = 0
    glyph.xMin = glyph.yMin = glyph.xMax = glyph.yMax = 0
    # Item assignment updates glyf.glyphOrder; do not append the name twice.
    font['glyf'][name] = glyph
    font['hmtx'][name] = (0, 0)
    if 'vmtx' in font:
        font['vmtx'][name] = (0, 0)
    for table in font['cmap'].tables:
        if table.isUnicode():
            table.cmap[codepoint] = name


root = Path(__file__).resolve().parents[1]
font_path = root / 'assets/fonts/NotoSansTC.ttf'
characters = set(range(32, 127)) | ENGINE_CHARS
for folder in ('scripts', 'scenes'):
    for source in (root / folder).rglob('*'):
        if source.suffix in ('.gd', '.tscn', '.tres'):
            characters.update(map(ord, source.read_text(encoding='utf-8-sig')))
# Only the active export set (data/word_set.json), not every set under
# tools/word_sets/, so the root font stays limited to the original glyphs.
word_set = root / 'data/word_set.json'
if word_set.exists():
    characters.update(map(ord, word_set.read_text(encoding='utf-8-sig')))
font = TTFont(font_path)
before_size = font_path.stat().st_size
original_map = font.getBestCmap()
# Word-set CJK (and any other non-ASCII source chars) must exist in the
# committed font; silently dropping them would ship tofu on the new set.
missing_from_font = characters.difference(original_map).difference(ENGINE_CHARS)
# ASCII control chars from source files can appear in strings; ignore those
# already covered by the 32-126 range plus common whitespace.
missing_from_font = {cp for cp in missing_from_font if cp > 127}
if missing_from_font:
    glyphs = ', '.join(f'U+{cp:04X} {chr(cp)}' for cp in sorted(missing_from_font))
    raise SystemExit(f'Font is missing required UI characters: {glyphs}')
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
inject_zerowidth_glyph(font, 0x200B, 'uni200B')
# Preserve the font license and give the modified subset its own family name.
for name_id, value in [(1,'Dungeon UI'),(2,'Regular'),(3,'DungeonUI-Subset'),(4,'Dungeon UI'),(6,'DungeonUI-Regular'),(16,'Dungeon UI'),(17,'Regular')]:
    font['name'].setName(value,name_id,3,1,0x409)
font.save(font_path)
verified = TTFont(font_path)
missing = required.difference(verified.getBestCmap())
assert not missing, f'Missing required UI characters: {missing}'
assert 0x200B in verified.getBestCmap(), 'ZWSP glyph was not embedded'
assert font_path.stat().st_size < before_size, 'Font size did not decrease'
print(f'UI_FONT_PASS: {len(required)} characters + ZWSP; {before_size} -> {font_path.stat().st_size} bytes')

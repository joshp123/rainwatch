"""HTML for one Paper screen: the text-free capture as the picture, RainWatch's words over it as
editable text in Apple's fonts, each named by its string key.

    python gen.py <capture dir> <state> <spec json>   ->  prints HTML

The spec lists the words on the screen in reading order: [key, text, style, align?]. Each is matched
to an ink box found by comparing the capture with its text-free twin, and placed so its ink lands on
the box."""
import json, sys, os
from PIL import Image, ImageDraw, ImageFont
from fontTools.ttLib import TTFont

sys.path.insert(0, os.path.dirname(__file__))
from boxes import boxes

D = '/Users/josh/Library/Fonts/'
# name: (css family, css weight, font file, size px, tracking em). Sizes are pixels of the 422 x 514
# capture (two to a point), fitted to the simulator's own rendering.
STYLES = {
    'nav':        ('SF Compact Rounded', 500, 'SF-Compact-Rounded-Medium.otf', 35.25, 0),
    'headline':   ('SF Compact Display', 600, 'SF-Compact-Display-Semibold.otf', 40, 0),
    'detail':     ('SF Compact Text', 400, 'SF-Compact-Text-Regular.otf', 33.75, -0.0034),
    'axis':       ('SF Compact Text', 400, 'SF-Compact-Text-Regular.otf', 24, 0.0195),
    'credit':     ('SF Compact Text', 400, 'SF-Compact-Text-Regular.otf', 28, 0.0137),
    'cuvTitle':   ('SF Compact Text', 600, 'SF-Compact-Text-Semibold.otf', 35.5, -0.0068),
    'cuvDetail':  ('SF Compact Display', 400, 'SF-Compact-Display-Regular.otf', 31, 0.002),
    'button':     ('SF Compact Text', 500, 'SF-Compact-Text-Medium.otf', 33.75, -0.0034),
    'body':       ('SF Compact Text', 400, 'SF-Compact-Text-Regular.otf', 33.75, -0.0034),
    'faceHead':   ('SF Compact Rounded', 600, 'SF-Compact-Rounded-Semibold.otf', 31, 0),
    'faceDetail': ('SF Compact Rounded', 500, 'SF-Compact-Rounded-Medium.otf', 26.25, 0),
    'faceAxis':   ('SF Compact Rounded', 500, 'SF-Compact-Rounded-Medium.otf', 21.25, 0),
}
_metrics = {}


def metrics(fontfile):
    """Ascender and descender in em, as Chrome lays out a line."""
    if fontfile not in _metrics:
        t = TTFont(D + fontfile)
        upm = t['head'].unitsPerEm
        os2 = t['OS/2']
        if os2.fsSelection & (1 << 7):
            a, d = os2.sTypoAscender, -os2.sTypoDescender
        else:
            a, d = t['hhea'].ascent, -t['hhea'].descent
        _metrics[fontfile] = (a / upm, d / upm)
    return _metrics[fontfile]


def ink_origin(text, style, size=None):
    """Where the ink starts relative to the pen origin at the top of the ascender (x, y), and the ink size."""
    fam, weight, fontfile, px, track = STYLES[style]
    px = size or px
    f = ImageFont.truetype(D + fontfile, size=px)
    pos = [f.getlength(text[:i]) + i * track * px for i in range(len(text))]
    pad = int(px * 2)
    img = Image.new('L', (int(pos[-1] + px * 2 + pad * 2), int(px * 3)), 0)
    d = ImageDraw.Draw(img)
    for c, x in zip(text, pos):
        d.text((x + pad, pad), c, font=f, fill=255)
    bb = img.getbbox()
    # PIL draws with the top of the ascender at y = pad.
    return bb[0] - pad, bb[1] - pad, bb[2] - bb[0], bb[3] - bb[1]


def colour_at(real, bg, box):
    crop = real.crop((box[0], box[1], box[2] + 1, box[3] + 1)).convert('RGB')
    back = bg.crop((box[0], box[1], box[2] + 1, box[3] + 1)).convert('RGB')
    best = max(zip(crop.getdata(), back.getdata()), key=lambda p: sum(abs(x - y) for x, y in zip(*p)))
    return '#%02x%02x%02x' % best[0]


def text_html(key, text, style, box, colour, align='left', width=None, pitch=None):
    fam, weight, fontfile, px, track = STYLES[style]
    asc, desc = metrics(fontfile)
    line = pitch or round((asc + desc) * px, 2)
    first = text.split('\n')[0] if width is None else text
    ox, oy, iw, ih = ink_origin(first if width is None else text[:20], style)
    top = box[1] - oy - (line - (asc + desc) * px) / 2
    esc = text.replace('&', '&amp;').replace('<', '&lt;')
    common = (f"position:absolute;top:{top:.2f}px;font-family:'{fam}';font-weight:{weight};font-size:{px}px;"
              f"line-height:{line}px;letter-spacing:{track}em;color:{colour};white-space:pre")
    if width:
        # A paragraph: the app's own width, so Paper wraps it where the watch does.
        centre = 211
        common = common.replace('white-space:pre', 'white-space:normal')
        return (f'<div layer-name="{key}" style="{common};left:{centre - width / 2:.2f}px;width:{width}px;'
                f'text-align:{align}">{esc}</div>')
    if align == 'center':
        # Centred on the ink's centre, across the whole screen, so edited words stay centred.
        centre = (box[0] + box[2] + 1) / 2
        half = min(centre, 422 - centre)
        return (f'<div layer-name="{key}" style="{common};left:{centre - half:.2f}px;width:{2 * half:.2f}px;'
                f'text-align:center">{esc}</div>')
    if align == 'right':
        right = 422 - (box[2] + 1) - (0)
        return f'<div layer-name="{key}" style="{common};right:{right:.2f}px;text-align:right">{esc}</div>'
    left = box[0] - ox
    return f'<div layer-name="{key}" style="{common};left:{left:.2f}px">{esc}</div>'


def screen(capdir, state, items, name, frame_asset=None):
    real = Image.open(f'{capdir}/{state}.png')
    bg = Image.open(f'{capdir}-notext/{state}.png')
    found = boxes(f'{capdir}/{state}.png', f'{capdir}-notext/{state}.png')
    found = [b for b in found if (b[2] - b[0]) > 6 or (b[3] - b[1]) > 12]
    need = sum(item[4] if len(item) > 4 else 1 for item in items)
    if len(found) != need:
        raise SystemExit(f'{state}: {len(found)} boxes for {need} lines: {found}')
    parts = []
    i = 0
    for item in items:
        key, text, style = item[:3]
        align = item[3] if len(item) > 3 else 'left'
        lines = item[4] if len(item) > 4 else 1
        width = item[5] if len(item) > 5 else None
        group = found[i:i + lines]
        i += lines
        box = (min(b[0] for b in group), group[0][1], max(b[2] for b in group), group[-1][3])
        pitch = (group[-1][1] - group[0][1]) / (lines - 1) if lines > 1 else None
        parts.append(text_html(key, text, style, group[0] if lines == 1 else box, colour_at(real, bg, group[0]), align,
                               width, round(pitch, 2) if pitch else None))
    return parts, found


if __name__ == '__main__':
    capdir, state, spec = sys.argv[1], sys.argv[2], json.loads(sys.argv[3])
    parts, found = screen(capdir, state, spec, state)
    print('\n'.join(parts))

"""Every screen's words as Paper HTML: reads each capture's lines with Apple's Vision, finds each
line's ink by comparing the capture with its text-free twin, works out its string key and style, and
places it as editable text in Apple's watch fonts. `python gen_all.py <capture dir> <en|nl> <app|face>
<states...>` prints what it found on each screen, to check. Written by AI on 2026.11.18 by model
claude opus 5.5."""
import os
WORK = os.environ.get('PAPER_WORK', '/tmp/rainwatch-paper')
import json, os, re, subprocess, sys
sys.path.insert(0, os.path.dirname(__file__))
from boxes import boxes
from gen import STYLES, text_html, colour_at, ink_origin
from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CAT = json.load(open(f'{REPO}/Sources/RainGraph/Localizable.xcstrings'))['strings']
OCR = os.path.join(WORK, 'ocr')

STYLES.update({
    'cuvDetail': ('SF Compact Display', 400, 'SF-Compact-Display-Regular.otf', 30.25, 0.0034),
    'intro': ('SF Compact Text', 400, 'SF-Compact-Text-Regular.otf', 33.75, -0.0034),
    'cuvTitleBold': ('SF Compact Display', 600, 'SF-Compact-Display-Semibold.otf', 40, 0),
    'faceProblem': ('SF Compact Rounded', 600, 'SF-Compact-Rounded-Semibold.otf', 28.5, 0),
    'faceHint': ('SF Compact Rounded', 500, 'SF-Compact-Rounded-Medium.otf', 24, 0),
})


def value(key, lang):
    if lang == 'en':
        return key
    return CAT[key]['localizations']['nl']['stringUnit']['value']


def pattern(text):
    """A catalogue string as a regex: %@ and %lld become groups."""
    text = re.sub(r'%\d\$', '%', text)
    parts = re.split(r'(%@|%lld)', text)
    out = ''
    for p in parts:
        out += '(.+?)' if p in ('%@', '%lld') else re.escape(p)
    return '^' + out + '$'


def normal(s):
    return (s.replace('А', 'A').replace('О', 'O').replace('’', "'").replace('‘', "'")
            .replace('—', '–').replace('-', '–').strip())


PARAGRAPHS = {'To see the rain where you are, choose Allow While Using App.',
              'Your location was allowed once. To keep your watch face up to date, choose Allow While Using App.',
              'Open Settings, then Privacy & Security > Location Services > %@ > While Using the App.',
              'Location Not Found', 'No Forecast Here', 'Location Not Set', 'Permission Expired', 'Location Off',
              'Forecast Unavailable', 'No Recent Forecast'}  # face problem headlines are the app titles in sentence case


def keys_for(lang):
    """(regex, key) for every catalogue string, longest first, plus the face's sentence-case titles."""
    out = []
    for key in CAT:
        v = value(key, lang)
        out.append((pattern(normal(v)), key))
        if key[0].isupper() and ' ' in key and key.istitle() is False:
            pass
    for key in ['Location Not Set', 'Permission Expired', 'Location Off', 'Location Not Found', 'Forecast Unavailable',
                'No Forecast Here', 'No Recent Forecast']:
        v = value(key, lang)
        words = v.split(' ')
        sentence = ' '.join([words[0]] + [w.lower() for w in words[1:]])
        out.append((pattern(normal(sentence)), key))
    return sorted(out, key=lambda kv: -len(kv[0]))


def identify(text, lang):
    t = re.sub(r'^[^\wÀ-ÿ<]+\s*', '', normal(text))
    for rx, key in keys_for(lang):
        if re.match(rx, t):
            return key
    if re.match(r'^\d{1,2}:\d\d$', t):
        return 'clock time'
    return None


def ocr(path, lang):
    out = subprocess.run([OCR, 'nl-NL,en-GB' if lang == 'nl' else 'en-GB', path], capture_output=True, text=True).stdout
    lines = []
    for row in out.splitlines()[1:]:
        coords, text = row.split('\t', 1)
        lines.append((tuple(int(float(c)) for c in coords.split()), text))
    return lines


def overlap(a, b):
    x = max(0, min(a[2], b[2]) - max(a[0], b[0]))
    y = max(0, min(a[3], b[3]) - max(a[1], b[1]))
    return x * y


def style_for(kind, key, text, box, lang, index, lines):
    """The style and alignment of a line, by what it says and where it is."""
    heads = ['Dry for %@', 'Dry for %lld min', 'Rain for %@', 'Rain stops in %lld min', 'Dry until %@', 'Rain until %@']
    titles = ['Location Not Set', 'Permission Expired', 'Location Off', 'Location Not Found', 'Forecast Unavailable',
              'No Forecast Here', 'No Recent Forecast']
    if kind == 'app':
        if key in ('Forecast Unavailable', 'No Recent Forecast'): return 'cuvTitle', 'center'
        if key in titles: return 'cuvTitleBold', 'center'
        if key in ('Your location was allowed once. To keep your watch face up to date, choose Allow While Using App.', 'Last forecast %@') or key and key.startswith('Open Settings'):
            return 'cuvDetail', 'center'
        if key == 'To see the rain where you are, choose Allow While Using App.': return 'intro', 'left'
        if key in ('Try Again', 'Choose a Place', 'Continue'): return 'button', 'center'
        if key == 'About': return 'credit', 'left'
        if key == 'Change Place': return 'button', 'left'
        if key in ('My Location',) or (box[1] < 125 and box[0] > 130): return 'nav', 'right'
        if key in heads: return 'headline', 'left'
        if key in ('Heavy', 'Light'): return 'axis', 'right'
        if key in ('Now',) or (key == 'clock time' and box[3] - box[1] < 22): return 'axis', 'left'
        if key in ('KNMI forecast made %@', 'Source: KNMI', 'Legal') or box[1] > 430: return 'credit', 'left'
        return 'detail', 'left'
    # face
    if box[1] > 390: return 'circle', 'center'
    if key in titles: return 'faceProblem', 'left'
    if key and key.startswith('Tap to') or key == 'Last forecast %@': return 'faceHint', 'left'
    if key in heads: return 'faceHead', 'left'
    if key in ('Now',) or key == 'clock time': return 'faceAxis', 'left'
    return 'faceDetail', 'left'


def screen(capdir, lang, kind, state):
    real_path = f'{capdir}/{kind}-{state}.png'
    bg_path = f'{capdir}-notext/{kind}-{state}.png'
    found = [b for b in boxes(real_path, bg_path) if (b[2] - b[0]) > 4 or (b[3] - b[1]) > 8]
    lines = ocr(real_path, lang)
    real, bg = Image.open(real_path), Image.open(bg_path)
    # Vision reads Apple's location arrow as a character before "My Location".
    lines = [(b, t.split(' ', 1)[1]) if identify(t, lang) is None and ' ' in t and identify(t.split(' ', 1)[1], lang) else (b, t)
             for b, t in lines]
    rows = []
    # Group boxes under the OCR line they overlap most; boxes with no line are reported.
    used = set()
    for lbox, text in lines:
        mine = [b for b in found if overlap(b, lbox) > 0.3 * (b[2] - b[0]) * (b[3] - b[1])]
        if not mine:
            continue
        used.update(mine)
        rows.append([lbox, text, mine])
    stray = [b for b in found if b not in used]
    def system(lbox, text):
        if kind == 'app': return lbox[1] < 75
        return 140 <= lbox[1] <= 215 or lbox[0] < 150 and lbox[1] > 380
    rows = [r for r in rows if not system(r[0], r[1])]
    # Wrapped paragraphs: consecutive lines that only match a key together.
    out, i = [], 0
    while i < len(rows):
        joined, j, key = rows[i][1], i, identify(rows[i][1], lang)
        k = i
        while key is None and k + 1 < len(rows) and k - i < 4 and kind == 'app' and rows[i][0][1] > 90:
            k += 1
            joined = joined + ' ' + rows[k][1]
            key = identify(joined, lang)
            if key not in PARAGRAPHS: key = None
            if key: j = k
        group = rows[i:j + 1]
        ink = [b for g in group for b in g[2]]
        box = (min(b[0] for b in ink), min(b[1] for b in ink), max(b[2] for b in ink), max(b[3] for b in ink))
        firstline = [b for b in group[0][2]]
        fbox = (min(b[0] for b in firstline), min(b[1] for b in firstline), max(b[2] for b in firstline), max(b[3] for b in firstline))
        out.append(dict(text=joined if key else rows[i][1], key=key, box=box, first=fbox, lines=len(group),
                        pitch=(group[-1][0][1] - group[0][0][1]) / (len(group) - 1) if len(group) > 1 else None,
                        colour=colour_at(real, bg, firstline[0])))
        i = j + 1
    return out, stray


if __name__ == '__main__':
    capdir, lang, kind = sys.argv[1], sys.argv[2], sys.argv[3]
    for state in sys.argv[4:]:
        out, stray = screen(capdir, lang, kind, state)
        print(f'== {lang} {kind} {state}')
        for o in out:
            st = style_for(kind, o['key'], o['text'], o['box'], lang, 0, out)
            print(f"  {o['box']} L{o['lines']} {st[0]:11} {o['key']!r:40} {o['text']!r}")
        if stray: print('  STRAY', stray)


def canonical(o, lang):
    """The words as the app writes them: the catalogue's own string with OCR's values filled in."""
    key, text = o['key'], normal(o['text'])
    text = re.sub(r'^[^\wÀ-ÿ<]+\s*', '', text)
    if key in (None, 'clock time'):
        return re.sub(r'(\d)\s*–\s*(\d)', r'\1–\2', text).replace("'", '’')
    v = value(key, lang)
    m = re.match(pattern(normal(v)), text)
    if not m:
        # the face's sentence-case title
        return text.replace("'", '’')
    args = iter(m.groups())
    out = re.sub(r'%(\d\$)?(@|lld)', lambda _: next(args), re.sub(r'%\d\$', '%', v) if False else v)
    return out


def html_for(capdir, lang, kind, state, asset_dir):
    out, stray = screen(capdir, lang, kind, state)
    import hashlib, shutil
    bg_path = f'{capdir}-notext/{kind}-{state}.png'
    h = hashlib.sha1(open(bg_path, 'rb').read()).hexdigest()[:8]
    asset = f'{asset_dir}/{lang}-{kind}-{state}-{h}.png'
    shutil.copy(bg_path, asset)
    parts = []
    for o in out:
        style, align = style_for(kind, o['key'], o['text'], o['box'], lang, 0, out)
        o['text'] = re.sub(r'^[^\wÀ-ÿ<]+\s*', '', o['text'])
        text = canonical(o, lang)
        name = o['key'] if o['key'] and o['key'] != 'clock time' else f'value: {text}'
        if style == 'circle':
            continue
        if re.match(r'^\S+ \d', text) and identify(text.split(' ')[0], lang):
            name = f"{identify(text.split(' ')[0], lang)} · times"
        if kind == 'app' and 'Weather' in text:
            # Apple's mark is a picture; the time and Legal are words.
            text = text.split('Weather', 1)[1].strip()
            name = 'Legal · with the time'
            box = o['box']
            html = text_html(name, text, style, box, o['colour'], 'left')
            word = text.split(' ', 1)[1] if ' ' in text else text
            parts.append(html.replace(f'>{text}</div>', f'>{text.split(" ")[0]}  <span style="text-decoration: underline">{word}</span></div>'))
            continue
        if kind == 'face' and 'Weather' in text:
            text = '\uf8ff' + text[text.index('Weather'):]
            name = 'Apple Weather mark' if text.endswith('Weather') else name
        width = None
        if o['lines'] > 1:
            width = 372 if align == 'center' else 356
        html = text_html(name, text, style, o['first'] if o['lines'] > 1 else o['box'], o['colour'], align, width,
                         round(o['pitch'], 2) if o['pitch'] else None)
        if o['key'] == 'About':
            html = html.replace('white-space:pre', 'white-space:pre;text-decoration:underline')
        parts.append(html)
    if kind == 'face':
        heads = [o['key'] for o in out if o['key'] and (o['key'].startswith('Dry') or o['key'].startswith('Rain'))]
        circle, _ = circle_parts(capdir, lang, state, heads[0] if heads else None)
        parts += circle
    inner = '\n'.join(parts)
    return asset, inner, stray, out


def circle_html(name, text, o, capdir, kind, state):
    """The circle's words: Rounded Semibold at the size that matches the capture's ink."""
    from PIL import ImageFont
    box = o['box']
    h = box[3] - box[1] + 1
    best = None
    for px in [x / 4 for x in range(40, 140)]:
        _, _, iw, ih = ink_origin(text, 'faceHead', px)
        err = abs(iw - (box[2] - box[0] + 1)) + abs(ih - h)
        if best is None or err < best[0]: best = (err, px)
    px = best[1]
    STYLES['circle'] = ('SF Compact Rounded', 600, 'SF-Compact-Rounded-Semibold.otf', px, 0)
    return text_html(name, text, 'circle', box, o['colour'], 'center')


LEADS = {'IN', 'FOR', 'OVER', 'NOG'}
UNITS = {'MIN', 'HRS', 'HR', 'UUR'}
FACTOR = 0.97   # the face draws SF Compact Rounded this much smaller than its nominal size


def disc(bg_path):
    """Centre and diameter of the circle slot's grey disc, in the text-free face."""
    im = Image.open(bg_path).convert('RGB')
    xs, ys = [], []
    for y in range(380, 514):
        for x in range(155, 270):
            r, g, b = im.getpixel((x, y))
            if 18 <= r <= 75 and abs(r - g) < 6 and abs(g - b) < 6:
                xs.append(x); ys.append(y)
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    return (x0 + x1 + 1) / 2, (y0 + y1 + 1) / 2, x1 - x0 + 1


def circle_words(capdir, lang, state):
    lines = ocr(f'{capdir}/face-{state}.png', lang)
    words = []
    for b, t in lines:
        if b[1] > 380 and b[0] > 150:
            words += [w for w in re.split(r'\s+', normal(t)) if w]
    clean = []
    for w in words:
        w2 = re.sub(r'[^A-Za-z0-9+<]', '', w)
        if w2: clean.append(w2)
    return clean


def circle_parts(capdir, lang, state, headline=None):
    real = Image.open(f'{capdir}/face-{state}.png').convert('RGB')
    cx, cy, side = disc(f'{capdir}-notext/face-{state}.png')
    words = circle_words(capdir, lang, state)
    lead = None
    # Rain in sight means a lead word ("IN", "FOR"); only "Dry for …" has none. Vision misses some
    # of the circle's small words, so the headline decides.
    if headline and headline not in ('Dry for %@',) and not any(w.lower() in ('dry', 'droog', 'no', 'geen') for w in words):
        lead = {'en': {True: 'IN', False: 'FOR'}, 'nl': {True: 'OVER', False: 'NOG'}}[lang][headline.startswith('Dry')]
        words = [lead] + [w for w in words if w.upper() not in LEADS]
    unit = next((w for w in words if w.upper() in UNITS and w != lead), None)
    value = next((w for w in words if re.match(r'^[<\d][\d+]*\+?$', w)), None)
    if value is None and lang == 'nl':
        # Vision misses some small Dutch circles; the English capture of the same state has the same number.
        value = next((w for w in circle_words(capdir.replace('raw-nl', 'raw'), 'en', state) if re.match(r'^[<\d][\d+]*\+?$', w)), None)
    if value is None and headline in ('Dry until %@', 'Rain until %@') and lead:
        value = '<1' if headline == 'Dry until %@' else '1+'
    if unit is None and value and lang == 'nl':
        unit = 'UUR' if value.startswith('<') or value.endswith('+') else 'MIN'
    word = lambda w: next((x for x in words if x.lower() == w.lower()), None)
    parts = []
    def place(key, text, centre_y, px, colour):
        STYLES['circle'] = ('SF Compact Rounded', 600, 'SF-Compact-Rounded-Semibold.otf', round(px * FACTOR, 2), 0)
        fam, weight, ff, size, tr = STYLES['circle']
        from gen import metrics
        asc, desc = metrics(ff)
        line = (asc + desc) * size
        top = centre_y - line / 2
        parts.append(f'<div layer-name="{key}" style="position:absolute;top:{top:.2f}px;left:{cx - side / 2:.2f}px;width:{side:.2f}px;'
                     f"text-align:center;font-family:'{fam}';font-weight:{weight};font-size:{size}px;line-height:{line:.2f}px;"
                     f'color:{colour};white-space:pre">{text}</div>')
    def colour(y):
        # the brightest text-coloured pixel on that row band in the real capture
        best, val = '#ffffff', -1
        for yy in range(int(y) - 6, int(y) + 6):
            for xx in range(int(cx - side * 0.3), int(cx + side * 0.3)):
                p = real.getpixel((xx, yy))
                if sum(p) > val: val, best = sum(p), '#%02x%02x%02x' % p
        return best
    blue, grey, white = '#5a9bd3', '#9e9e9e', '#ffffff'
    keys_nl = {'OVER': 'IN', 'NOG': 'FOR', 'UUR': 'HRS', 'Geen': 'No', 'PLEK': 'PLACE', 'Droog': 'Dry'}
    keyof = lambda w: keys_nl.get(w, w) if lang == 'nl' else w
    if lead:
        place(keyof(lead), lead, cy - side * (0.13 if len(lead) > 3 else 0.15), side * (0.14 if len(lead) > 3 else 0.18), blue)
        place('value: circle number', value, cy + side * 0.05, side * (0.22 if len(value) > 2 else 0.27), white)
        place('HR' if value.startswith('<') else keyof(unit), unit, cy + side * 0.3, side * 0.243, blue)
    elif word('No') or word('Geen'):
        no, what = word('No') or word('Geen'), next(w for w in words if w.upper() in ('PLACE', 'PLEK', 'DATA'))
        l1 = 30 * FACTOR * 1.19; l2 = 26 * FACTOR * 1.19
        top = cy - (l1 + l2) / 2
        place(keyof(no), no, top + l1 / 2, 30, white)
        place(keyof(what), what, top + l1 + l2 / 2, 26, grey)
    else:
        dry = word('Dry') or word('Droog')
        reach = [w for w in words if w not in (dry,)]
        v, u = reach[0], reach[1] if len(reach) > 1 else ''
        l1 = side * 0.27 * FACTOR * 1.19; l2 = side * 0.243 * FACTOR * 1.19
        top = cy - (l1 + l2) / 2
        place(keyof(dry), dry, top + l1 / 2, side * 0.27, white)
        place('value: circle reach', f'{v} {u}'.strip(), top + l1 + l2 / 2, side * 0.243, grey)
    return parts, (cx, cy, side, words)


FRAME = os.path.join(WORK, 'ultra3-frame-634.png')


def setup():
    """The work folder: Vision's reader, built once, and Apple's Ultra 3 frame cut to the screen."""
    os.makedirs(os.path.join(WORK, 'assets'), exist_ok=True)
    if not os.path.exists(OCR):
        subprocess.run(['swiftc', '-O', os.path.join(os.path.dirname(__file__), 'ocr.swift'), '-o', OCR], check=True)
    if not os.path.exists(FRAME):
        Image.open(os.path.join(REPO, 'design/captures/apple-ultra-3-frame.png')).convert('RGBA').crop((0, 163, 600, 797)).save(FRAME)


setup()


def watch_block(capdir, lang, kind, state, label=None):
    asset, inner, stray, out = html_for(capdir, lang, kind, state, os.path.join(WORK, 'assets'))
    name = f'{kind} · {state} · {lang}'
    return (f'<div layer-name="{name}" style="position:relative;width:600px;height:634px;flex-shrink:0">'
            f'<img layer-name="frame" src="paper-asset://{FRAME}" style="position:absolute;left:0;top:0;width:600px;height:634px" />'
            f'<div layer-name="screen" style="position:absolute;left:89px;top:60px;width:422px;height:514px;overflow:hidden;border-radius:114px;background-color:#000">'
            f'<img layer-name="picture without words" src="paper-asset://{asset}" style="position:absolute;left:0;top:0;width:422px;height:514px" />'
            f'{inner}</div></div>')


if __name__ == '__main__' and False:
    pass

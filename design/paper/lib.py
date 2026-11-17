"""Draws RainWatch screens as SVG with Apple's real SF Compact outlines and system symbols.
Written by AI on 2026.11.17 by model claude fable 5.2. Units are watch pixels (2 per point)."""
import base64, math, os, struct
import uharfbuzz as hb
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

FONTS = os.path.expanduser('~/Library/Fonts/')
HERE = os.path.dirname(os.path.abspath(__file__))
BLUE = '#5A9BD3'
WHITE = '#FFFFFF'
GREY = '#98989F'          # watchOS secondary label on black
W, H, R = 422, 514, 104   # Ultra 3 screen and its corner radius

_fonts = {}
def _font(family, weight):
    key = (family, weight)
    if key not in _fonts:
        path = f'{FONTS}SF-Compact-{family}-{weight}.otf'
        blob = hb.Blob.from_file_path(path)
        face = hb.Face(blob)
        _fonts[key] = (hb.Font(face), TTFont(path).getGlyphSet(), TTFont(path).getGlyphOrder(), face.upem)
    return _fonts[key]

# Apple's tracking tables (HIG, Typography, watchOS), in 1/1000 em by point size.
TRACK_TEXT = {6: 50, 7: 30, 8: 30, 9: 30, 10: 30, 11: 24, 12: 20, 13: 16, 14: 14, 15: 4, 16: 0, 17: -4, 18: -8, 19: -12,
              20: 0, 21: -2, 22: -4, 23: -6, 24: -8, 25: -10, 26: -11, 27: -12, 28: -12, 30: -14, 32: -16, 34: -18, 36: -20, 40: -20}
TRACK_ROUND = {6: 28, 7: 26, 8: 24, 9: 22, 10: 20, 11: 18, 12: 16, 13: 14, 14: 12, 15: 10, 16: 8, 17: 6, 18: 4, 19: 2,
               20: 0, 21: -2, 22: -4, 23: -6, 24: -8, 25: -10, 26: -11, 27: -12, 28: -12, 30: -14, 32: -16, 34: -18, 36: -20, 40: -20}

def _tracking(points, rounded):
    """Rounded: Apple's table. Text: fitted to real Ultra 3 screenshots, which set 15 pt and up
    about a hundredth of an em tighter than these font files."""
    if not rounded:
        return -0.011 if points >= 15 else 0
    nearest = min(TRACK_ROUND, key=lambda k: abs(k - points))
    return TRACK_ROUND[nearest] / 1000

def _shape(s, size, weight, rounded, tracking=None):
    family = 'Rounded' if rounded else ('Display' if size / 2 >= 20 else 'Text')
    font, glyphs, order, upem = _font(family, weight)
    buf = hb.Buffer(); buf.add_str(s); buf.guess_segment_properties()
    hb.shape(font, buf, {'kern': True, 'tnum': False})
    scale = size / upem
    track = (_tracking(size / 2, rounded) if tracking is None else tracking) * size
    out, x = [], 0.0
    for info, pos in zip(buf.glyph_infos, buf.glyph_positions):
        out.append((order[info.codepoint], x + pos.x_offset * scale, pos.y_offset * scale))
        x += pos.x_advance * scale + track
    return out, x - track, glyphs, scale

def width(s, size, weight='Regular', rounded=False, tracking=None):
    return _shape(s, size, weight, rounded, tracking)[1]

def text(s, x, y, size, weight='Regular', fill=WHITE, anchor='start', rounded=False, opacity=1, tracking=None):
    """Outlined text with its baseline at y. Size in watch pixels."""
    run, w, glyphs, scale = _shape(s, size, weight, rounded, tracking)
    x0 = x - (w if anchor == 'end' else w / 2 if anchor == 'middle' else 0)
    d = []
    for name, gx, gy in run:
        pen = SVGPathPen(glyphs, ntos=lambda v: f'{v:.2f}')
        glyphs[name].draw(TransformPen(pen, (scale, 0, 0, -scale, x0 + gx, y - gy)))
        d.append(pen.getCommands())
    op = f' fill-opacity="{opacity}"' if opacity != 1 else ''
    return f'<path d="{" ".join(d)}" fill="{fill}"{op}/>'

def wrap(s, size, max_width, weight='Regular'):
    lines, line = [], ''
    for word in s.split(' '):
        trial = (line + ' ' + word).strip()
        if width(trial, size, weight) <= max_width or not line:
            line = trial
        else:
            lines.append(line); line = word
    return lines + [line]

_sym = {}
_ids = [0]
def symbol(name, cx, cy, points, weight='regular', fill=WHITE, opacity=1):
    """An SF Symbol at a font point size, centred on (cx, cy)."""
    key = f'{name}-{weight}'
    if key not in _sym:
        data = open(f'{HERE}/sym/{key}.png', 'rb').read()
        pw, ph = struct.unpack('>II', data[16:24])
        _sym[key] = (base64.b64encode(data).decode(), pw, ph)
    b64, pw, ph = _sym[key]
    w, h = pw / 4 * points / 100 * 2, ph / 4 * points / 100 * 2
    _ids[0] += 1
    i = f'm{_ids[0]}'
    x, y = cx - w / 2, cy - h / 2
    op = f' fill-opacity="{opacity}"' if opacity != 1 else ''
    return (f'<mask id="{i}" mask-type="alpha" maskUnits="userSpaceOnUse" x="{x:.2f}" y="{y:.2f}" width="{w:.2f}" height="{h:.2f}">'
            f'<image x="{x:.2f}" y="{y:.2f}" width="{w:.2f}" height="{h:.2f}" href="data:image/png;base64,{b64}"/></mask>'
            f'<rect x="{x:.2f}" y="{y:.2f}" width="{w:.2f}" height="{h:.2f}" fill="{fill}"{op} mask="url(#{i})"/>')

def svg(body, w=W, h=H, radius=R, background='#000', defs=''):
    clip = f'<clipPath id="screen"><rect width="{w}" height="{h}" rx="{radius}"/></clipPath>'
    bg = f'<rect width="{w}" height="{h}" fill="{background}"/>' if background else ''
    return (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
            f'<defs>{clip}{defs}</defs><g clip-path="url(#screen)">{bg}{body}</g></svg>')

# ---------------------------------------------------------------- the forecast, as the app computes it

def clock(minute):
    minute = int(minute) % 1440
    return f'{minute // 60:02d}:{minute % 60:02d}'

def graph_height(rate):
    if rate <= 0: return 0
    return 20 * rate if rate <= 2 else min(100, 40 + (rate - 2) * 3.75)

def display(height):
    if height <= 0: return 0
    return max(0.16, math.sqrt(min(height, 100) / 100))

class Forecast:
    """Rain in mm/h every five minutes from `start` (minutes of the day); `now` is when it is shown."""
    def __init__(self, rates, start, now=None, hourly=False, span=120):
        self.rates, self.start, self.now, self.hourly, self.span = rates, start, start if now is None else now, hourly, span
        self.dates = [start + 5 * i for i in range(len(rates))]
        self.end = start + span
        self.forecast_end = min(self.end, self.dates[-1])

    def position(self, minute): return (minute - self.start) / self.span
    @property
    def has_rain(self): return any(r > 0 and d < self.forecast_end for r, d in zip(self.rates, self.dates))
    @property
    def minutes_known(self): return max(0, int(self.forecast_end - self.now))

    @property
    def spells(self):
        raw = []
        for rate, date in zip(self.rates, self.dates):
            if date >= self.forecast_end: break
            end, wet, h = min(date + 5, self.forecast_end), rate > 0, graph_height(rate)
            if raw and raw[-1][0] == wet:
                raw[-1][2] = end; raw[-1][3] = max(raw[-1][3], h)
            else:
                raw.append([wet, date, end, h])
        i = 1
        while i < len(raw) - 1:
            wet, s, e, _ = raw[i]
            if not wet and e - s < 10:
                raw[i - 1:i + 2] = [[True, raw[i - 1][1], raw[i + 1][2], max(raw[i - 1][3], raw[i + 1][3])]]
                i = max(1, i - 1)
            else:
                i += 1
        return raw

    def curve(self, subdivisions=10):
        steps = [(d, display(graph_height(r))) for r, d in zip(self.rates, self.dates) if d < self.forecast_end]
        values = [v for _, v in steps]
        times = [self.position(d + 2.5) for d, _ in steps]
        n = len(values)
        stop = min(1, self.position(self.forecast_end))
        if n < 2: return [(0, values[0]), (stop, values[0])] if values else []
        slopes = [(values[k + 1] - values[k]) / (times[k + 1] - times[k]) for k in range(n - 1)]
        tan = [0.0] * n
        for k in range(1, n - 1):
            a, b = slopes[k - 1], slopes[k]
            tan[k] = 0 if a * b <= 0 else (a + b) / 2
        for k in range(n - 1):
            if slopes[k] != 0:
                a, b = tan[k] / slopes[k], tan[k + 1] / slopes[k]
                length = math.hypot(a, b)
                if length > 3:
                    tan[k] = 3 / length * a * slopes[k]; tan[k + 1] = 3 / length * b * slopes[k]
        out = [(0, values[0]), (times[0], values[0])]
        for k in range(n - 1):
            t0, t1 = times[k], times[k + 1]; h = t1 - t0
            for step in range(1, subdivisions + 1):
                s = step / subdivisions; s2, s3 = s * s, s * s * s
                v = ((2 * s3 - 3 * s2 + 1) * values[k] + (s3 - 2 * s2 + s) * h * tan[k]
                     + (-2 * s3 + 3 * s2) * values[k + 1] + (s3 - s2) * h * tan[k + 1])
                out.append((min(t0 + s * h, 1), max(0, v)))
        if out[-1][0] < stop: out.append((stop, values[-1]))
        return [p for p in out if p[0] <= stop]

    def wet_runs(self):
        runs, run, last_dry = [], [], None
        for t, v in self.curve():
            if v > 0.0005:
                if not run: run.append((last_dry[0] if last_dry else t, 0))
                run.append((t, v))
            else:
                if run:
                    run.append((t, 0)); runs.append(run); run = []
                last_dry = (t, v)
        if run: runs.append(run + [(run[-1][0], 0)])
        return runs

PHRASE = ['Drizzle', 'Light rain', 'Rain', 'Heavy rain']
def phrase(peak): return PHRASE[3 if peak >= 75 else 2 if peak >= 50 else 1 if peak >= 25 else 0]

class Copy:
    """The app's words (RainCopy.swift), with the two changes this design proposes: the headline
    always starts with Dry or Rain, and nothing else."""
    def __init__(self, f):
        self.f, self.spells = f, f.spells
        self.now_spell = self.spells[0] if self.spells else None
        self.whole = len(self.spells) == 1

    @property
    def reach(self):
        m = self.f.minutes_known
        if m >= 120: return ('2+ hours', '2+', 'HRS')
        if m >= 60: return ('1+ hours', '1+', 'HRS')
        five = max(5, m // 5 * 5)
        return (f'{five}+ min', f'{five}+', 'MIN')

    @property
    def change(self): return None if self.whole or not self.now_spell else self.now_spell[2]
    @property
    def minutes_left(self):
        return None if self.change is None else max(1, round(self.change - self.f.now))
    @property
    def raining(self): return bool(self.now_spell and self.now_spell[0])

    @property
    def headline(self):
        if not self.f.has_rain: return f'Dry for {self.reach[0]}'
        if self.minutes_left is None: return f'Rain for {self.reach[0]}'
        state = 'Rain' if self.raining else 'Dry'
        if self.minutes_left >= 60 or self.f.hourly: return f'{state} until {clock(self.change)}'
        return f'Rain stops in {self.minutes_left} min' if self.raining else f'Dry for {self.minutes_left} min'

    @property
    def peak(self):
        best = max(((graph_height(r), d) for r, d in zip(self.f.rates, self.f.dates) if d < self.f.forecast_end), key=lambda p: p[0])
        return f'Heaviest around {clock(best[1])}'

    @property
    def detail(self):
        if self.f.hourly: return 'Hourly forecast'
        if not self.f.has_rain: return None
        rest = self.spells[1:]
        if not rest: return self.peak if self.raining else None
        wet, s, e, peak = rest[0]
        ends = f'–{clock(e)}' if e < self.f.forecast_end else ''
        if wet: return f'{phrase(peak)} from {clock(s)}' if not ends else f'{phrase(peak)} {clock(s)}{ends}'
        if not ends and (self.minutes_left or 0) >= 60: return self.peak
        return f'Dry from {clock(s)}' if not ends else f'Dry {clock(s)}{ends}'

    @property
    def circular(self):
        if not self.f.has_rain: return (None, 'Dry', f'{self.reach[1]} {self.reach[2]}')
        if self.minutes_left is None: return ('FOR', self.reach[1], self.reach[2])
        lead = 'FOR' if self.raining else 'IN'
        if self.minutes_left >= 60: return (lead, '1+', 'HRS')
        return (lead, '<1', 'HR') if self.f.hourly else (lead, str(self.minutes_left), 'MIN')

RATES = {
    'dry': [0] * 23,
    'showerComing': [0, 0, 0, 0, 0, 0, 0, 0, 0.13, 0.17, 0.22, 0.14, 0.12, 0.12, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    'onAndOff': [0.12, 0.95, 0.36, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.10, 0.12, 0.16, 0.21, 0.17, 0.18, 0.21, 0.18, 0.13],
    'drizzleStops': [0.12, 0, 0, 0.36, 0.60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    'rainingEasing': [3.02, 1.58, 3.16, 5.50, 1.32, 0.40, 0.55, 0.60, 0.48, 0.40, 0.32, 0.29, 0.19, 0.13, 0.13, 0, 0, 0, 0, 0, 0, 0, 0],
    'rainComing': [0, 0, 0, 0, 0, 0.12, 0.12, 0.24, 0.36, 0.55, 0.66, 0.60, 0.58, 0.42, 0.25, 0.24, 0.20, 0.12, 0.18, 0.12, 0.13, 0.11, 0],
    'rainAllWindow': [0.36, 0.36, 0.24, 3.31, 1.82, 0.48, 0.79, 0.72, 0.87, 1.20, 1.15, 1.10, 1.05, 1.00, 0.95, 0.72, 0.55, 0.38, 0.24, 0.16, 0.12, 0.14, 0.22],
    'heavy': [2.40, 5.01, 6.92, 7.24, 2.88, 0.29, 0.24, 0.32, 0.21, 0.28, 0.30, 0.29, 0.19, 0.16, 0, 0, 0.16, 0.12, 0, 0, 0, 0, 0],
}

def polar(cx, cy, r, degrees):
    a = math.radians(degrees)
    return cx + r * math.cos(a), cy + r * math.sin(a)

def hour_marks(f):
    first = (f.start // 60 + 1) * 60
    return [h for h in range(first, f.end + 1, 60)]

"""Every RainWatch screen in the design file. Run: uv run --with fonttools --with uharfbuzz python screens.py
Written by AI on 2026.11.17 by model claude fable 5.2."""
import base64, math, os, subprocess, sys
from lib import *

def about_rain(line):
    return not line.startswith(('Dry', 'Hourly'))


OUT = os.path.join(HERE, 'screens')
os.makedirs(OUT, exist_ok=True)
REPO = os.path.expanduser('~/code/buienradar-apple-watch/')
LEFT, RIGHT = 36, 386

def rain_background():
    return ('<linearGradient id="rainbg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#16283A"/>'
            '<stop offset="0.55" stop-color="#0A121B"/><stop offset="1" stop-color="#05090E"/></linearGradient>')

def status(time, x=RIGHT):
    return text(time, x, 68, 36, 'Medium', anchor='end', tracking=-0.06)

def round_button(name, cx=74, cy=79, points=17):
    return (f'<circle cx="{cx}" cy="{cy}" r="37" fill="#FFFFFF" fill-opacity="0.16"/>'
            + symbol(name, cx, cy, points, 'medium'))

def title(place):
    return text(place, RIGHT, 107, 34, 'Regular', GREY, 'end')

def wide_button(label, y, icon=None, prominent=False, height=108):
    fill = f'fill="{BLUE}"' if prominent else 'fill="#FFFFFF" fill-opacity="0.14"'
    out = f'<rect x="34" y="{y}" width="354" height="{height}" rx="{height / 2}" {fill}/>'
    w = width(label, 34, 'Medium')
    if icon:
        total = w + 48
        out += symbol(icon, 211 - total / 2 + 15, y + height / 2, 18, 'medium')
        out += text(label, 211 - total / 2 + 48, y + height / 2 + 12, 34, 'Medium')
    else:
        out += text(label, 211, y + height / 2 + 12, 34, 'Medium', anchor='middle')
    return out

# ---------------------------------------------------------------- the rain graph on the forecast page

def chart(f, top=244, base=442, scale=True, x0=LEFT, x1=RIGHT):
    span, height = x1 - x0, base - top
    X = lambda t: x0 + t * span
    Y = lambda v: base - v * height
    out, defs = '', ''
    if scale and f.has_rain:
        for label, v in (('Light', display(25)), ('Heavy', display(75))):
            y = Y(v)
            out += f'<line x1="{x0}" y1="{y:.1f}" x2="{x1}" y2="{y:.1f}" stroke="#FFFFFF" stroke-opacity="0.22" stroke-width="2" stroke-dasharray="4 6"/>'
            out += text(label, x1 - 2, y - 9, 24, 'Regular', GREY, 'end')
    known = X(min(1, f.position(f.forecast_end)))
    out += f'<line x1="{x0}" y1="{base}" x2="{known:.1f}" y2="{base}" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="2"/>'
    if f.end - f.forecast_end > 10 or True:
        if known < x1 - 4:
            out += f'<line x1="{known + 6:.1f}" y1="{base}" x2="{x1}" y2="{base}" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="3" stroke-linecap="round" stroke-dasharray="0.2 8"/>'
    out += text('Now', x0, base + 30, 24, 'Regular', GREY)
    for minute in [f.start] + hour_marks(f):
        x = X(f.position(minute))
        out += f'<line x1="{x:.1f}" y1="{base}" x2="{x:.1f}" y2="{base + 8}" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="2"/>'
        if minute - f.start >= 30:
            half = width(clock(minute), 24) / 2
            out += text(clock(minute), min(x, x1 - half), base + 30, 24, 'Regular', GREY, 'middle')
    for i, run in enumerate(f.wet_runs()):
        pts = [(X(t), Y(v)) for t, v in run]
        peak = min(y for _, y in pts)
        gid = f'area{id(f)}{i}'
        defs += (f'<linearGradient id="{gid}" gradientUnits="userSpaceOnUse" x1="0" y1="{peak:.1f}" x2="0" y2="{base}">'
                 f'<stop offset="0" stop-color="{BLUE}" stop-opacity="0.8"/><stop offset="1" stop-color="{BLUE}" stop-opacity="0.25"/></linearGradient>')
        out += f'<path d="M{" L".join(f"{x:.1f},{y:.1f}" for x, y in pts)} Z" fill="url(#{gid})"/>'
        edge = pts[1:-1]
        out += f'<path d="M{" L".join(f"{x:.1f},{y:.1f}" for x, y in edge)}" fill="none" stroke="{BLUE}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>'
    change = Copy(f).change
    if change is not None:
        out += f'<circle cx="{X(f.position(change)):.1f}" cy="{base}" r="7" fill="#FFFFFF"/>'
    return out, defs

def forecast_page(f, place, time, radar=True, age=None, failed=False, end=False, chosen=False, issued='17:25'):
    """The forecast page. `age` puts the forecast's time on the second line, as a forecast 20
    minutes old does; `failed` says the last update failed and offers Try Again; `end` shows the
    page turned to its end with the crown."""
    c = Copy(f)
    rain = f.has_rain
    body = text(c.headline, LEFT, 168, 40, 'Semibold')
    if failed:
        body += symbol('exclamationmark.triangle.fill', LEFT + 17, 202, 15, 'regular', GREY)
        body += text('Couldn’t update', LEFT + 44, 214, 34, 'Regular', GREY)
    elif age:
        body += text(f'Forecast from {age}', LEFT, 214, 34, 'Regular', GREY)
    elif c.detail:
        body += text(c.detail, LEFT, 214, 34, 'Regular', BLUE if about_rain(c.detail) else GREY)
    if rain and failed:
        ch, defs = chart(f, base=410)
        y = 456
    elif rain:
        ch, defs = chart(f)
        y = 526
    else:
        ch, defs = chart(f, top=214, base=236, scale=False)
        y = 296
    body += ch
    y += 28
    body += text(f'KNMI forecast from {issued}', LEFT, y, 28, 'Regular', GREY)
    y += 26
    if failed:
        body += wide_button('Try Again', y + 10)
        y += 130
    body += wide_button('Change Place' if chosen else 'Choose a Place', y, 'mappin.and.ellipse')
    bottom = y + 108 + 22
    defs += rain_background()
    if end:
        scroll = bottom - H
        defs += ('<linearGradient id="fade" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity="0"/>'
                 '<stop offset="1" stop-color="#fff"/></linearGradient>'
                 f'<mask id="top" maskUnits="userSpaceOnUse" x="0" y="0" width="{W}" height="{H}"><rect y="150" width="{W}" height="70" fill="url(#fade)"/>'
                 f'<rect y="220" width="{W}" height="{H}" fill="#fff"/></mask>')
        body = f'<g mask="url(#top)"><g transform="translate(0,{-scroll})">{body}</g></g>' + status(time)
    else:
        body += (round_button('map') if radar else '') + status(time) + title(place)
    return svg(body, background='url(#rainbg)' if rain else '#000', defs=defs)

# ---------------------------------------------------------------- first launch

def intro(time):
    body = status(time)
    body += text('Rain where you are', LEFT, 132, 40, 'Semibold')
    y = 180
    for line in wrap('Allow While Using App keeps your watch face on where you are.', 34, 350):
        body += text(line, LEFT, y, 34, 'Regular', GREY); y += 39
    body += wide_button('Continue', 384, prominent=True)
    return svg(body)

def location_question(time):
    """watchOS draws this; the app supplies only the sentence under the title."""
    body = status(time)
    for i, line in enumerate(['Allow “RainWatch” to', 'use your location?']):
        body += text(line, 211, 138 + 35 * i, 34, 'Bold', anchor='middle')
    for i, line in enumerate(wrap('RainWatch rounds your location to about 1 km to get the rain forecast.', 34, 372)):
        body += text(line, 211, 212 + 35 * i, 34, 'Regular', anchor='middle')
    from PIL import Image
    shot = Image.open(REPO + 'renders/simulator/first-run.png').crop((422, 318, 844, 514))
    shot.save(OUT + '/_map.png')
    b64 = base64.b64encode(open(OUT + '/_map.png', 'rb').read()).decode()
    body += f'<image x="0" y="318" width="422" height="196" href="data:image/png;base64,{b64}"/>'
    return svg(body)

def spinner(time):
    body = status(time)
    for i in range(8):
        a = i * 45 - 90
        x0, y0 = polar(211, 272, 11, a); x1, y1 = polar(211, 272, 24, a)
        body += f'<line x1="{x0:.1f}" y1="{y0:.1f}" x2="{x1:.1f}" y2="{y1:.1f}" stroke="#FFFFFF" stroke-opacity="{0.25 + 0.75 * i / 7:.2f}" stroke-width="6" stroke-linecap="round"/>'
    return svg(body)

def place_search(time):
    body = round_button('xmark', points=15) + status(time) + title('Place')
    row = lambda y, h: f'<rect x="12" y="{y}" width="398" height="{h}" rx="28" fill="#FFFFFF" fill-opacity="0.14"/>'
    body += '<rect x="12" y="134" width="398" height="76" rx="38" fill="#FFFFFF" fill-opacity="0.14"/>'
    body += symbol('magnifyingglass', 46, 172, 14, 'medium', GREY) + text('Utrecht', 70, 184, 34, 'Regular')
    for i, (name, detail) in enumerate([('Utrecht', 'Netherlands'), ('Utrecht', 'South Africa')]):
        y = 222 + i * 116
        body += row(y, 108) + text(name, 34, y + 46, 34, 'Regular') + text(detail, 34, y + 84, 28, 'Regular', GREY)
    return svg(body)

# ---------------------------------------------------------------- when something goes wrong

def unavailable(time, icon, heading, description=None, buttons=('Try Again',), back=False):
    """Apple's empty-state layout (ContentUnavailableView), measured from the app on an Ultra 3.
    The system centres the block, so a second button moves everything up."""
    up = 46 if len(buttons) > 1 else 0
    body = status(time) + (round_button('chevron.left', points=16) if back else '')
    body += symbol(icon, 211, 139 - up, 23, 'regular', GREY)
    body += text(heading, 211, 240 - up, 34, 'Bold', anchor='middle')
    y = 281 - up
    for line in (wrap(description, 28, 370, 'Medium') if description else []):
        body += text(line, 211, y, 28, 'Medium', GREY, 'middle'); y += 33
    y = (y + 35) if description else 290 - up
    for label in buttons:
        w = width(label, 34, 'Medium') + 26
        body += f'<rect x="{211 - w / 2:.1f}" y="{y}" width="{w:.1f}" height="110" rx="42" fill="#FFFFFF" fill-opacity="0.22"/>'
        body += text(label, 211, y + 67, 34, 'Medium', anchor='middle')
        y += 120
    return svg(body)

def screenshot(path):
    b64 = base64.b64encode(open(path, 'rb').read()).decode()
    return svg(f'<image x="0" y="0" width="{W}" height="{H}" href="data:image/png;base64,{b64}"/>')

# ---------------------------------------------------------------- on the watch face

def gauge(f, cx, cy, side, plate=True, plate_fill=None):
    """The circular complication (CircularRainGauge in RainViews.swift)."""
    half = side / 2
    START, SWEEP, RIM, TRACK = 150, 240, 0.98, 0.66
    stroke = max(4 * side / 90, side * 0.045)
    hs = stroke / side
    c = Copy(f)
    out, defs = '', ''
    if plate and plate_fill:
        out += f'<circle cx="{cx}" cy="{cy}" r="{half}" fill="{plate_fill}"/>'
    elif plate:
        out += f'<circle cx="{cx}" cy="{cy}" r="{half}" fill="#FFFFFF" fill-opacity="0.115"/>'
    if f.has_rain:
        reach = min(1, f.position(f.forecast_end))
        r = half * TRACK
        dot = None
        if c.change is not None:
            dot_angle = START + f.position(c.change) * SWEEP
            dot = polar(cx, cy, r, dot_angle)
        hole = side * 0.065
        mid = f'g{id(f)}{int(cx)}{int(side)}'
        mask = f'<mask id="{mid}" maskUnits="userSpaceOnUse" x="{cx - half}" y="{cy - half}" width="{side}" height="{side}"><rect x="{cx - half}" y="{cy - half}" width="{side}" height="{side}" fill="#fff"/>'
        mask2 = mask.replace(mid, mid + 'w')
        if dot:
            mask += f'<circle cx="{dot[0]:.2f}" cy="{dot[1]:.2f}" r="{hole:.2f}" fill="#000"/>'
            spread = math.degrees(hole / r)
            a0, a1 = polar(cx, cy, half * 1.1, dot_angle - spread), polar(cx, cy, half * 1.1, dot_angle + spread)
            mask2 += f'<path d="M{cx},{cy} L{a0[0]:.2f},{a0[1]:.2f} L{a1[0]:.2f},{a1[1]:.2f} Z" fill="#000"/>'
        defs += mask + '</mask>' + mask2 + '</mask>'
        s, e = polar(cx, cy, r, START), polar(cx, cy, r, START + SWEEP * reach)
        large = 1 if SWEEP * reach > 180 else 0
        round_start = f.rates[0] == 0
        round_end = f.rates[-1] == 0
        track = f'<path d="M{s[0]:.2f},{s[1]:.2f} A{r:.2f},{r:.2f} 0 {large} 1 {e[0]:.2f},{e[1]:.2f}" fill="none" stroke="#FFFFFF" stroke-width="{stroke:.2f}"/>'
        caps = ''
        if round_start: caps += f'<circle cx="{s[0]:.2f}" cy="{s[1]:.2f}" r="{stroke / 2:.2f}" fill="#FFFFFF"/>'
        if round_end: caps += f'<circle cx="{e[0]:.2f}" cy="{e[1]:.2f}" r="{stroke / 2:.2f}" fill="#FFFFFF"/>'
        out += f'<g mask="url(#{mid})" opacity="0.38">{track}{caps}</g>'
        base, full, floor = TRACK - hs, RIM, TRACK + hs
        def point(t, v):
            b = floor if v > 0 else base
            return polar(cx, cy, half * (b + v * (full - b)), START + t * SWEEP)
        curve = f.curve()
        pts = [point(0, 0)] + [point(t, v) for t, v in curve] + [point(t, 0) for t, _ in reversed(curve)]
        out += f'<path d="M{" L".join(f"{x:.2f},{y:.2f}" for x, y in pts)} Z" fill="{BLUE}" mask="url(#{mid}w)"/>'
        if dot:
            out += f'<circle cx="{dot[0]:.2f}" cy="{dot[1]:.2f}" r="{side * 0.1 * 0.62 / 2:.2f}" fill="#FFFFFF"/>'
        lead, value, unit = c.circular
        size = side * (0.22 if len(value) > 2 else 0.27)
        if lead:
            out += text(lead, cx, cy - side * 0.15 + side * 0.2 * 0.345, side * 0.2, 'Semibold', BLUE, 'middle', rounded=True)
        out += text(value, cx, cy + side * (0.05 if lead else 0) + size * 0.345, size, 'Semibold', WHITE, 'middle', rounded=True)
        out += text(unit, cx, cy + side * 0.3 + side * 0.243 * 0.345, side * 0.243, 'Semibold', BLUE, 'middle', rounded=True)
    else:
        _, value, unit = c.circular
        out += two_words(value, unit, cx, cy, side)
    return out, defs

def two_words(top, bottom, cx, cy, side, top_size=0.27, bottom_size=0.243):
    a, b = side * top_size, side * bottom_size
    line_a, line_b = a * 1.19, b * 1.19
    y0 = cy - (line_a + line_b) / 2
    return (text(top, cx, y0 + line_a * 0.5 + a * 0.345, a, 'Semibold', WHITE, 'middle', rounded=True)
            + text(bottom, cx, y0 + line_a + line_b * 0.5 + b * 0.345, b, 'Semibold', BLUE, 'middle', rounded=True))

def problem_circle(word, cx, cy, side):
    out = f'<circle cx="{cx}" cy="{cy}" r="{side / 2}" fill="#FFFFFF" fill-opacity="0.115"/>'
    return out + two_words('No', word, cx, cy, side, 15 / 45, 12 / 45)

def rect_chart(f, x, y, w, h, k):
    """The rain line in the large slot (RainChart in RainViews.swift). k is pixels per point."""
    X = lambda t: x + t * w
    Y = lambda v: y + h - v * h
    out, defs = '', ''
    if h >= 24 * k:
        for line in (25, 50, 75):
            yy = Y(display(line))
            out += f'<line x1="{x}" y1="{yy:.1f}" x2="{x + w}" y2="{yy:.1f}" stroke="#FFFFFF" stroke-opacity="0.16" stroke-width="{k}" stroke-dasharray="{k} {3 * k}"/>'
    c = Copy(f)
    dot = None if c.change is None else (X(f.position(c.change)), y + h)
    mid = f'r{id(f)}{int(x)}{int(y)}'
    mask = f'<mask id="{mid}" maskUnits="userSpaceOnUse" x="{x - 10}" y="{y - 10}" width="{w + 20}" height="{h + 30}"><rect x="{x - 10}" y="{y - 10}" width="{w + 20}" height="{h + 30}" fill="#fff"/>'
    if dot: mask += f'<circle cx="{dot[0]:.1f}" cy="{dot[1]:.1f}" r="{4.5 * k}" fill="#000"/>'
    defs += mask + '</mask>'
    g = ''
    for run in f.wet_runs():
        pts = [(X(t), Y(v)) for t, v in run]
        g += f'<path d="M{" L".join(f"{a:.1f},{b:.1f}" for a, b in pts)} Z" fill="{BLUE}" fill-opacity="0.55"/>'
        g += f'<path d="M{" L".join(f"{a:.1f},{b:.1f}" for a, b in pts[1:-1])}" fill="none" stroke="{BLUE}" stroke-width="{1.5 * k}" stroke-linecap="round" stroke-linejoin="round"/>'
    known = X(min(1, f.position(f.forecast_end)))
    if known < x + w - 4:
        g += f'<line x1="{known + 3 * k:.1f}" y1="{y + h}" x2="{x + w}" y2="{y + h}" stroke="#FFFFFF" stroke-opacity="0.38" stroke-width="{1.5 * k}" stroke-linecap="round" stroke-dasharray="{0.1 * k} {4 * k}"/>'
    g += f'<line x1="{x}" y1="{y + h}" x2="{known:.1f}" y2="{y + h}" stroke="#FFFFFF" stroke-opacity="0.38" stroke-width="{1.5 * k}"/>'
    for hour in hour_marks(f):
        hx = X(f.position(hour))
        g += f'<line x1="{hx:.1f}" y1="{y + h}" x2="{hx:.1f}" y2="{y + h + 4 * k}" stroke="#FFFFFF" stroke-opacity="0.38" stroke-width="{1.5 * k}"/>'
    out += f'<g mask="url(#{mid})">{g}</g>'
    if dot: out += f'<circle cx="{dot[0]:.1f}" cy="{dot[1]:.1f}" r="{2.5 * k}" fill="#FFFFFF"/>'
    return out, defs

def rect_view(f, x, y, w, h, k=2, age=None, second_line=True):
    """The large slot and the Smart Stack (RectangularRainView). k is pixels per point."""
    c = Copy(f)
    out = text(c.headline, x, y + 15.5 * k, 16 * k, 'Semibold', rounded=True)
    second = (f'Forecast from {age}' if age else c.detail) if second_line else None
    yy = y + 19 * k + 1 * k
    if second:
        grey = age or not about_rain(second)
        out += text(second, x, yy + 12.6 * k, 13.5 * k, 'Medium', '#FFFFFF' if grey else BLUE, rounded=True, opacity=0.62 if grey else 1)
        yy += 16 * k + 1 * k
    axis_h = 12 * k
    top = yy + 3 * k
    ch, defs = rect_chart(f, x, top, w, y + h - axis_h - 4 * k - top, k)
    out += ch
    ay = y + h - 2 * k
    out += text('Now', x, ay, 11 * k, 'Medium', rounded=True, opacity=0.62)
    for hour in hour_marks(f):
        hx = x + w * f.position(hour)
        if 50 * k < hx - x < w - 14 * k:
            out += text(clock(hour), hx, ay, 11 * k, 'Medium', anchor='middle', rounded=True, opacity=0.62)
        elif hx - x > 50 * k:
            out += text(clock(hour), x + w, ay, 11 * k, 'Medium', anchor='end', rounded=True, opacity=0.62)
    return out, defs

def rect_problem(headline, detail, x, y, w, h, k=2):
    mid = y + h / 2
    out = symbol('drop', x + 6 * k, mid - 9.5 * k, 13, 'semibold') if k == 2 else symbol('drop', x + 6 * k, mid - 9.5 * k, 13 * k / 2, 'semibold')
    out += text(headline, x + 17 * k, mid - 4 * k, 15 * k, 'Semibold', rounded=True)
    out += text(detail, x, mid + 13 * k, 12.5 * k, 'Medium', rounded=True, opacity=0.62)
    return out

def tile(body, w, h, defs='', radius=0, background='#000'):
    return svg(body, w, h, radius, background, defs)

def circle_tile(kind):
    side, pad = 360, 30
    c = side / 2 + pad
    if kind in RATES:
        body, defs = gauge(forecast(kind), c, c, side)
    else:
        body, defs = problem_circle(kind, c, c, side), ''
    return tile(body, side + 2 * pad, side + 2 * pad, defs, radius=64)

def rect_tile(kind, stack=False, k=4):
    w, h = (198 if stack else 183) * k, (81.5 if stack else 76) * k
    inset = 11 * k if stack else 0
    x, y, iw, ih = inset, 7 * k if stack else 0, w - 2 * inset, h - (14 * k if stack else 0)
    defs = ''
    if kind == 'fresh':
        body, defs = rect_view(forecast('onAndOff'), x, y, iw, ih, k, second_line=not stack)
    elif kind == 'old':
        body, defs = rect_view(Forecast(RATES['onAndOff'][4:], 17 * 60 + 55, 17 * 60 + 57), x, y, iw, ih, k, age='17:25')
    elif kind == 'withdrawn':
        body = rect_problem('Last forecast 17:25', 'Tap to refresh', x, y, iw, ih, k)
    else:
        body = rect_problem('Location off', 'Tap to choose a place', x, y, iw, ih, k)
    pad = 0 if stack else 10 * k
    bg = '#12213A' if stack else '#000'
    if stack:
        return tile(body, w, h, defs, radius=20 * k, background='#122136')
    return tile(f'<g transform="translate({pad},{pad})">{body}</g>', w + 2 * pad, h + 2 * pad, defs, radius=14 * k)

def face(large_slot=False):
    """Josh's Modular Ultra face, captured from his watch, with RainWatch drawn over it from one
    forecast: raining, stops in 14 minutes, more rain an hour later."""
    b64 = base64.b64encode(open(REPO + 'renders/watch/face.png', 'rb').read()).decode()
    f = Forecast(RATES['onAndOff'], 14 * 60 + 24, 14 * 60 + 25)
    body = f'<image x="0" y="0" width="422" height="514" href="data:image/png;base64,{b64}"/>'
    body += '<circle cx="211" cy="433" r="48" fill="#000"/>'
    circle, defs = gauge(f, 211, 433, 89, plate_fill='#141414')
    body += circle
    if large_slot:
        body += '<rect x="22" y="232" width="378" height="150" fill="#000"/>'
        view, more = rect_view(f, 28, 236, 366, 146, 2)
        body += view
        defs += more
    return svg(body, defs=defs)

def render(name, markup, zoom=3):
    path = f'{OUT}/{name}.svg'
    open(path, 'w').write(markup)
    subprocess.run(['resvg', '--zoom', str(zoom), path, f'{OUT}/{name}.png'], check=True)

def forecast(key, start=17 * 60 + 35, now=17 * 60 + 36, **kw):
    return Forecast(RATES[key], start, now, **kw)

if __name__ == '__main__':
    only = sys.argv[1:]
    def make(name, fn, zoom=3):
        if not only or any(name.startswith(o) for o in only):
            render(name, fn(), zoom)
    T = '17:36'
    make('forecast-shower', lambda: forecast_page(forecast('showerComing'), 'Eindhoven', T))
    make('forecast-raining', lambda: forecast_page(forecast('onAndOff'), 'Hoorn', T))
    make('forecast-all', lambda: forecast_page(forecast('rainAllWindow'), 'Düsseldorf', T))
    make('forecast-dry', lambda: forecast_page(forecast('dry'), 'Groningen', T))
    make('forecast-end', lambda: forecast_page(forecast('showerComing'), 'Eindhoven', T, end=True))
    make('forecast-place', lambda: forecast_page(forecast('showerComing', now=17 * 60 + 38), 'Utrecht', '17:38', chosen=True))
    make('forecast-ageing', lambda: forecast_page(Forecast(RATES['showerComing'][4:], 17 * 60 + 55, 17 * 60 + 57), 'Eindhoven', '17:57', age='17:25'))
    make('forecast-not-updated', lambda: forecast_page(Forecast(RATES['rainingEasing'][6:], 18 * 60 + 5, 18 * 60 + 7), 'Den Helder', '18:07', failed=True))
    for kind in ('dry', 'showerComing', 'heavy', 'DATA', 'PLACE'):
        make(f'circle-{kind}', lambda: circle_tile(kind), 2)
    for kind in ('fresh', 'old', 'withdrawn', 'location'):
        make(f'slot-{kind}', lambda: rect_tile(kind), 2)
    make('stack-fresh', lambda: rect_tile('fresh', stack=True), 2)
    make('face-circle-14', lambda: face())
    make('face-slot-14', lambda: face(True))
    make('first-launch', lambda: intro('17:34'))
    make('question', lambda: location_question('17:34'))
    make('choices', lambda: screenshot(HERE + '/ref/location-choices.png'))
    make('place-search', lambda: place_search('17:37'))
    make('error-location-off', lambda: unavailable('17:35', 'location.slash', 'Location Off', 'Allow it in Settings.', ('Choose a Place',)))
    make('error-location-lost', lambda: unavailable(T, 'location.slash', 'Location Not Found', None, ('Try Again', 'Choose a Place')))
    make('error-none', lambda: unavailable(T, 'icloud.slash', 'No Forecast Here', None, ('Try Again', 'Choose a Place')))
    make('error-load', lambda: unavailable(T, 'exclamationmark.icloud', 'Forecast Unavailable'))
    make('error-late', lambda: unavailable('18:31', 'clock.badge.exclamationmark', 'No Recent Forecast', 'Last forecast 17:25'))
    make('error-radar-back', lambda: unavailable(T, 'map', 'Radar Unavailable', back=True))

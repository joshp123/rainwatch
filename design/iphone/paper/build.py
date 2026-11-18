# Written by AI on 2026.11.18 by model claude fable 5.2. Joins the screens into rows of HTML for Paper's write_html. See ../README.md.
import sys, re, pathlib
import os
V = os.environ.get("V", "-c")
def rgba(m):
    r, g, b = int(m[1]), int(m[2]), int(m[3]); a = float(m[4]) if m[4] else 1
    return "#%02X%02X%02X" % (r, g, b) + ("%02X" % round(a * 255) if a < 1 else "")
def cell(name, caption, width=None):
    h = pathlib.Path(f"/tmp/rainwatch-iphone-paper/{name}{V}.html").read_text()
    head, rest = h.split(">", 1)
    rest = re.sub(r"rgba?\((\d+), ?(\d+), ?(\d+)(?:, ?([\d.]+))?\)", rgba, rest)
    head = head.replace(", ", ",")
    h = head + ">" + rest
    h = h.replace(' layer-name="Text"', "").replace(";white-space:nowrap", "").replace("font-weight:400;", "")
    h = re.sub(r"letter-spacing:(0\.\d{3})\d*em", r"letter-spacing:\1em", h)
    h = re.sub(r"border-radius:(\d+px) \1 \1 \1", r"border-radius:\1", h).replace("36px 36px 0px 0px", "36px 36px 0 0")
    h = h.replace("left:0px;", "left:0;").replace("top:0px;", "top:0;")
    w = width or re.search(r"width:([\d.]+)px", h).group(1)
    cap = f"<div style=\"font-family:'SF Pro';font-size:20px;line-height:28px;color:#666\">{caption}</div>" if caption else ""
    return f'<div layer-name="{(caption or name)[:40]}" style="display:flex;flex-direction:column;gap:16px;width:{w}px;flex-shrink:0">{h}{cap}</div>'
rows = {
 "r1": [("open", "At rest: the map shows now"), ("in20", "Playing: the rain reaches the yellow dot as the line rises"), ("raining", "Raining: the white dot is when it stops"), ("dry", "No rain: no scale, and a wider map")],
 "r2": [("old", "Forecast over 20 minutes old"), ("apple", "Outside KNMI’s area: Apple Weather, no radar"), ("light", "Light appearance"), ("nl", "Dutch")],
 "r3": [("lock0", "Rain on the way"), ("lock1", "Raining"), ("lock3", "No rain"), ("lock4", "Forecast over 20 minutes old"), ("lock5", "Location off")],
 "r4": [("small0", "Rain on the way"), ("small1", "Raining"), ("small3", "No rain"), ("small4", "Over 20 minutes old"), ("small5", "Location off"), ("medium0", "Medium: room for what comes next"), ("medium1", "")],
 "r5": [("small6", ""), ("small7", "")],
 "r6": [("nllock", ""), ("nlsmall", ""), ("nlmedium", "")],
}
for key, cells in rows.items():
    html = "".join(cell(n, c) for n, c in cells)
    pathlib.Path(f"/tmp/rainwatch-iphone-paper/row-{key}.html").write_text(html)
    print(key, len(html))

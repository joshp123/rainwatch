"""One row of the design file: up to two states, each a title, a line and its watches (English, Dutch)."""
import os
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
import sys, os, html, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_all
spec = json.loads(sys.argv[1])   # {"kind":..., "langs":["en","nl"], "states":[[state,title,line],...]}
out = '<div layer-name="row" style="display:flex;flex-direction:row;gap:64px">'
for state, title, line in spec['states']:
    out += f'<div layer-name="{html.escape(title)}" style="display:flex;flex-direction:column;gap:12px;width:{600 * len(spec["langs"])}px">'
    out += f'<div style="font-family:\'SF Pro\';font-weight:600;font-size:30px;line-height:38px;color:#000">{html.escape(title)}</div>'
    out += f'<div style="font-family:\'SF Pro\';font-size:22px;line-height:31px;color:#666;width:{600 * len(spec["langs"]) - 60}px">{html.escape(line)}</div>'
    out += '<div style="display:flex;flex-direction:row">'
    for lang in spec['langs']:
        cap = os.path.join(REPO, 'design/captures/raw' + ('-nl' if lang == 'nl' else ''))
        out += gen_all.watch_block(cap, lang, spec['kind'], state)
    out += '</div></div>'
out += '</div>'
print(out)

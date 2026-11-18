"""App Store screenshot artboards: the caption-free picture from make.py, the captions as editable text."""
import os
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
import os
WORK = os.environ.get('PAPER_WORK', '/tmp/rainwatch-paper')
import sys, os, re, html, json, hashlib, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen import metrics
src = open(os.path.join(REPO, 'store/screenshots/make.py')).read()
ns = {}
exec(src[src.index('SHOTS = {'):src.index('\n}\n', src.index('SHOTS = {')) + 3], ns)
asc, desc = metrics('SF-Compact-Rounded-Bold.otf')
L = (asc + desc) * 30
sasc, sdesc = metrics('SF-Compact-Rounded-Semibold.otf')
SL = (sasc + sdesc) * 15
locale, number = sys.argv[1], int(sys.argv[2])
capture, plain, marked, note = ns['SHOTS'][locale][number - 1]
pic = f'{WORK}/wordless/{locale}-{number}-{capture}.png'
h = hashlib.sha1(open(pic, 'rb').read()).hexdigest()[:8]
asset = f'{WORK}/assets/store-{locale}-{number}-{h}.png'
shutil.copy(pic, asset)
k = f'store.{locale}.{number}'
font = "font-family:'SF Compact Rounded';font-weight:700;font-size:30px"
out = (f'<img layer-name="picture without captions" src="paper-asset://{asset}" style="position:absolute;left:0;top:0;width:422px;height:514px" />'
       f'<div layer-name="{k}.headline" style="position:absolute;left:0;top:16px;width:422px;text-align:center;{font};line-height:{L:.2f}px;color:#ffffff;white-space:pre">{html.escape(plain)}</div>'
       f'<div layer-name="{k}.marked box" style="position:absolute;left:0;top:49px;width:422px;display:flex;flex-direction:row;justify-content:center">'
       f'<div style="display:flex;padding:5px 9px 0px 9px;height:41px;border-radius:8px;background-color:rgb(40,108,190)">'
       f'<div layer-name="{k}.marked" style="{font};line-height:{L:.2f}px;color:#ffffff;white-space:pre">{html.escape(marked)}</div></div></div>')
if note:
    out += (f'<div layer-name="{k}.note" style="position:absolute;left:0;top:{101 - SL / 2:.2f}px;width:422px;text-align:center;'
            f"font-family:'SF Compact Rounded';font-weight:600;font-size:15px;line-height:{SL:.2f}px;color:rgb(210,210,215);white-space:pre\">{html.escape(note)}</div>")
print(out)

"""Puts each raw simulator capture in Apple's Ultra 3 frame and rounds the bare screens.
Run: uv run --with pillow python design/frame.py
Written by AI on 2026.11.17 by model claude fable 5.2."""
import os, glob
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
RAW, SCREENS, FRAMED = (f'{HERE}/captures/{d}' for d in ('raw', 'screens', 'framed'))
# Apple's frame (Apple Design Resources, Product Bezels) is 600 x 960 with the screen at (89, 223).
FRAME = Image.open(f'{HERE}/captures/apple-ultra-3-frame.png').convert('RGBA')
HOLE = (89, 223)
CROP = (0, 150, 600, 810)   # the case without most of the band

def rounded(shot):
    """The screen's own corners: XCUITest screenshots are square."""
    scale = 4
    mask = Image.new('L', (422 * scale, 514 * scale), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 422 * scale - 1, 514 * scale - 1), radius=104 * scale, fill=255)
    shot = shot.convert('RGBA')
    shot.putalpha(mask.resize((422, 514), Image.LANCZOS))
    return shot

for d in (SCREENS, FRAMED):
    os.makedirs(d, exist_ok=True)
for path in sorted(glob.glob(f'{RAW}/*.png')):
    name = os.path.basename(path)
    shot = Image.open(path)
    if shot.size != (422, 514):
        continue
    rounded(shot).save(f'{SCREENS}/{name}')
    canvas = Image.new('RGBA', FRAME.size, (0, 0, 0, 0))
    canvas.paste(shot.convert('RGBA'), HOLE)
    canvas.alpha_composite(FRAME)
    canvas.crop(CROP).save(f'{FRAMED}/{name}')

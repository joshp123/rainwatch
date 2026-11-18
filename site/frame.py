"""Makes the pictures in assets/ for the website. Run from this folder:
  uv run --with pillow python frame.py
The face, the circles and the Smart Stack card are the launch film's: one real KNMI run drawn minute
by minute by marketing/video/export, read from marketing/video/public/gen or from FILM_GEN. The app
screens are the App Store's captures in Apple's Ultra 3 bezel. The App Store badges are Apple's
artwork, fetched by marketing/video/render.sh; like there, they are copied in and never committed.
Written by AI on 2026.11.18 by model claude fable 5.2."""
import os, shutil
from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CAPTURES = f'{REPO}/design/captures'
VIDEO = f'{REPO}/marketing/video/public'
FILM = os.environ.get('FILM_GEN', f'{VIDEO}/gen')
FRAME = Image.open(f'{CAPTURES}/apple-ultra-3-frame.png').convert('RGBA')
os.makedirs('assets', exist_ok=True)


def framed(shot, scale=1):
    """A 422 x 514 screen in the bezel, cut above the case and below it."""
    frame = FRAME.resize((FRAME.width * scale, FRAME.height * scale), Image.LANCZOS)
    shot = Image.open(shot).convert('RGBA').resize((422 * scale, 514 * scale), Image.LANCZOS)
    canvas = Image.new('RGBA', frame.size, (0, 0, 0, 0))
    canvas.paste(shot, (89 * scale, 223 * scale))
    canvas.alpha_composite(frame)
    return canvas.crop((0, 120 * scale, 600 * scale, 840 * scale))


Image.open(f'{VIDEO}/icon.png').resize((120, 120), Image.LANCZOS).save('assets/icon.png')
for language, store, raw in (('en', 'store/en-GB', 'raw'), ('nl', 'store/nl-NL', 'raw-nl')):
    shutil.copy(f'{VIDEO}/badge/{language}.svg', f'assets/badge-{language}.svg')
    # Minutes of the film's shower: 07:39 on the face; 07:39, 07:47, 07:51 and 08:06 as circles.
    framed(f'{FILM}/{language}/face/00.png', 2).save(f'assets/{language}-hero.png')
    for minute in ('00', '08', '12', '27'):
        Image.open(f'{FILM}/{language}/circle/{minute}.png').resize((480, 480), Image.LANCZOS).save(f'assets/{language}-circle-{minute}.png')
    Image.open(f'{FILM}/{language}/stack/12.png').resize((792, 326), Image.LANCZOS).save(f'assets/{language}-stack.png')
    framed(f'{CAPTURES}/{store}/app-raining.png').save(f'assets/{language}-app-graph.png')
    framed(f'{CAPTURES}/{store}/app-radar.png').save(f'assets/{language}-app-radar.png')
    # Apple Weather: the store's London capture in English; the Dutch store set has none.
    abroad = f'{CAPTURES}/store/en-GB/app-uk.png' if language == 'en' else f'{CAPTURES}/{raw}/app-abroad.png'
    framed(abroad).save(f'assets/{language}-app-abroad.png')

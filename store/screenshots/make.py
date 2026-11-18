"""The App Store screenshots: a headline over a real capture of the app, 422 x 514, no alpha.
Run after design/capture.sh, in English and with SIM_LANGUAGE=nl. The London capture is the
real Apple Weather forecast, from a simulator placed in London (LAUNCH.md, item 21):
    uv run --with pillow python store/screenshots/make.py
Written by AI on 2026.11.18 by model claude fable 5.2."""
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
CAPTURES = f'{HERE}/../../design/captures'
W, H, S = 422, 514, 3          # Apple's size for the Ultra; drawn at three times it, then reduced
BAND = 78                      # the headline's band, in store pixels
FONT = '/System/Library/Fonts/SFCompactRounded.ttf'

# In the order of the store page. Eight words or fewer each; no claim the app can't show.
SHOTS = {
    'en-GB': ('raw', [
        ('face-coming', 'Will I get wet?'),
        ('face-raining', 'Heavy rain stands out'),
        ('app-raining', 'Two hours at a glance'),
        ('app-radar', 'Radar on your wrist'),
        ('face-dry', 'Dry? One look says so'),
        ('app-london', 'Works abroad too'),
    ]),
    'nl-NL': ('raw-nl', [
        ('face-coming', 'Word ik nat?'),
        ('face-raining', 'Zware regen valt op'),
        ('app-raining', 'Twee uur in één blik'),
        ('app-radar', 'De radar op je pols'),
        ('face-dry', 'Droog? Dat zie je zo'),
        ('app-london', 'Ook over de grens'),
    ]),
}

def headline_font(text, draw):
    # One size for every headline, so the set reads as one.
    font = ImageFont.truetype(FONT, 36 * S)
    font.set_variation_by_name('Bold')
    if draw.textlength(text, font=font) > (W - 28) * S:
        raise SystemExit(f'"{text}" does not fit on one line')
    return font

for locale, (folder, shots) in SHOTS.items():
    os.makedirs(f'{HERE}/{locale}', exist_ok=True)
    for number, (capture, headline) in enumerate(shots, 1):
        canvas = Image.new('RGB', (W * S, H * S), 'black')
        draw = ImageDraw.Draw(canvas)
        font = headline_font(headline, draw)
        draw.text((W * S / 2, BAND * S / 2 + 4 * S), headline, font=font, fill='white', anchor='mm')
        # The capture, as large as the space under the headline allows, with the screen's corners.
        shot = Image.open(f'{CAPTURES}/{folder}/{capture}.png').convert('RGB')
        height = (H - BAND - 8) * S
        width = round(height * shot.width / shot.height)
        shot = shot.resize((width, height), Image.LANCZOS)
        radius = round(104 * height / 514)
        mask = Image.new('L', shot.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, width - 1, height - 1), radius=radius, fill=255)
        left, top = (W * S - width) // 2, BAND * S
        canvas.paste(shot, (left, top), mask)
        # A hairline round the screen, so a black watch face still reads as a screen.
        draw.rounded_rectangle((left, top, left + width - 1, top + height - 1), radius=radius, outline=(58, 58, 60), width=S)
        canvas.resize((W, H), Image.LANCZOS).save(f'{HERE}/{locale}/{number}-{capture}.png')
        print(f'{locale}/{number}-{capture}.png')

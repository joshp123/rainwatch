"""The App Store screenshots: a two-line headline over the real app on an Apple Watch Ultra 3,
422 x 514, no alpha. The captures come from design/capture-store.sh, which replays a real KNMI run
and the live Apple Weather forecast through the app in the simulator:
    uv run --with pillow python store/screenshots/make.py
Written by AI on 2026.11.18 by model claude opus 5.5, after the version by claude fable 5.2."""
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
CAPTURES = f'{HERE}/../../design/captures/store'
FRAME = f'{HERE}/../../design/captures/apple-ultra-3-frame.png'
W, H, S = 422, 514, 3                 # Apple's size for the Ultra; drawn at three times it, then reduced
FONT = '/System/Library/Fonts/SFCompactRounded.ttf'
BLUE = (40, 108, 190)                 # a deeper shade of the app's accent, so white text on it reads
SCALE = 0.665                         # the watch: its screen is 281 of the 422 pixels across
HOLE = (89, 223)                      # where the screen sits in Apple's 600 x 960 frame
CASE_TOP = 163                        # first row of the case in the frame; the band above it is cut

# In the order of the store page: the question and its answer on the face, then four screens of the app
# (App Review 2.3.3 wants mostly the app in use). Each headline is eight words or fewer and says only
# what its capture shows; the grey note says where it applies. No app name: the English one may change.
SHOTS = {
    'en-GB': [
        ('face-coming', 'The next rain,', 'on your watch face.', None),
        ('app-uk', 'The next hour of rain,', 'in the UK too.', 'From Apple Weather; hour by hour in some countries'),
        ('app-raining', 'When the rain stops,', 'and how hard it falls.', 'Benelux and western Germany: up to two hours ahead'),
        ('app-radar', 'Turn the crown', 'to see the rain move.', 'Radar map in the Benelux and western Germany'),
        ('app-later', 'Free, with no ads.', 'No account needed.', None),
    ],
    'nl-NL': [
        ('face-coming', 'De volgende bui,', 'op je wijzerplaat.', None),
        ('app-coming', 'Wanneer het gaat regenen,', 'en hoe hard.', 'KNMI-radar, tot twee uur vooruit'),
        ('app-raining', 'Wanneer de bui stopt,', 'en hoe hard het regent.', None),
        ('app-radar', 'Draai aan de kroon', 'en zie de bui komen.', 'Radarkaart van de Benelux en West-Duitsland'),
        ('app-later', 'Gratis en zonder reclame.', 'Geen account nodig.', None),
    ],
}


def font(size, weight='Bold'):
    f = ImageFont.truetype(FONT, size * S)
    f.set_variation_by_name(weight)
    return f


def watch(capture):
    """The capture in Apple's Ultra 3 frame, cut at the top of the case, at SCALE."""
    frame = Image.open(FRAME).convert('RGBA')
    shot = Image.open(capture).convert('RGBA')
    if shot.size != (422, 514):
        raise SystemExit(f'{capture} is {shot.size}, not 422 x 514')
    canvas = Image.new('RGBA', frame.size, (0, 0, 0, 0))
    canvas.paste(shot, HOLE)
    canvas.alpha_composite(frame)
    canvas = canvas.crop((0, CASE_TOP - 40, frame.width, frame.height))
    # The band above the case fades into the black, so it reads as going on behind the headline.
    alpha = canvas.getchannel('A')
    fade = Image.linear_gradient('L').resize((canvas.width, 40))
    alpha.paste(Image.composite(alpha.crop((0, 0, canvas.width, 40)), Image.new('L', (canvas.width, 40), 0), fade), (0, 0))
    canvas.putalpha(alpha)
    size = (round(canvas.width * SCALE * S), round(canvas.height * SCALE * S))
    return canvas.resize(size, Image.LANCZOS)


def headline(draw, top, plain, marked):
    """The plain line in white, the marked line in white on the accent, both centred."""
    big = font(30)
    for text in (plain, marked):
        if draw.textlength(text, font=big) > (W - 36) * S:
            raise SystemExit(f'"{text}" does not fit on one line')
    draw.text((W * S / 2, top * S), plain, font=big, fill='white', anchor='mt')
    y = (top + 38) * S
    left, _, right, _ = draw.textbbox((W * S / 2, y), marked, font=big, anchor='mt')
    pad = 9 * S
    draw.rounded_rectangle((left - pad, y - 5 * S, right + pad, y + 36 * S), radius=8 * S, fill=BLUE)
    draw.text((W * S / 2, y), marked, font=big, fill='white', anchor='mt')


for locale, shots in SHOTS.items():
    os.makedirs(f'{HERE}/{locale}', exist_ok=True)
    for old in os.listdir(f'{HERE}/{locale}'):
        os.remove(f'{HERE}/{locale}/{old}')
    for number, (capture, plain, marked, note) in enumerate(shots, 1):
        canvas = Image.new('RGBA', (W * S, H * S), 'black')
        device = watch(f'{CAPTURES}/{locale}/{capture}.png')
        top = (106 if note is None else 122) - round(40 * SCALE)
        canvas.alpha_composite(device, ((W * S - device.width) // 2, top * S))
        if os.environ.get('WORDLESS'):
            # The design file lays the headline over this as editable text.
            canvas.convert('RGB').resize((W, H), Image.LANCZOS).save(f"{os.environ['WORDLESS']}/{locale}-{number}-{capture}.png")
        draw = ImageDraw.Draw(canvas)
        headline(draw, 16, plain, marked)
        if note:
            small = font(15, 'Semibold')
            if draw.textlength(note, font=small) > (W - 24) * S:
                raise SystemExit(f'"{note}" does not fit on one line')
            draw.text((W * S / 2, 101 * S), note, font=small, fill=(210, 210, 215), anchor='mm')
        name = f'{HERE}/{locale}/{number}-{capture}.png'
        canvas.convert('RGB').resize((W, H), Image.LANCZOS).save(name)
        print(os.path.relpath(name, HERE))

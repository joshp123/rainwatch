"""Draws what the film's comparison shows in the circle's slot for the two other rain apps.
Run: uv run --with pillow python others.py <gen folder>
Written by AI on 2026.11.18 by model claude fable 5.2.

These are the film's own drawings, not the apps' artwork (competitors.md has the sources):
Buienradar's complication is a button that opens its app, and iCulture's screenshot of July 2022
shows it as two dashes on the slot's grey disc; Buienalarm has no complication, so its slot is empty,
drawn as the dashed outline of a slot with nothing in it.
"""
import math, sys
from PIL import Image, ImageDraw, ImageFont

gen = sys.argv[1]
SIZE = 1080
# RainPalette.fullColour: the plate is white at 13%, the baseline white at 38%.
# White at 13% over the face's black, as the screen shows it.
plate = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(plate)
draw.ellipse((0, 0, SIZE - 1, SIZE - 1), fill=(33, 33, 33, 255))
font = ImageFont.truetype(f"{gen}/fonts/SFCompactRounded-Semibold.ttf", int(SIZE * 0.34))
draw.text((SIZE / 2, SIZE / 2), "--", font=font, fill=(255, 255, 255, 255), anchor="mm")
plate.save(f"{gen}/other-button.png")

empty = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(empty)
draw.ellipse((0, 0, SIZE - 1, SIZE - 1), fill=(0, 0, 0, 255))
radius, dashes = SIZE / 2 - 14, 28
for k in range(dashes):
    a0 = 360 * k / dashes
    draw.arc((14, 14, SIZE - 14, SIZE - 14), a0, a0 + 360 / dashes * 0.55, fill=(97, 97, 97, 255), width=12)
empty.save(f"{gen}/other-empty.png")

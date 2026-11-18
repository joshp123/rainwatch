"""Makes fixed-weight copies of the watch's face font for the film's 3D words.
Run: uv run --with fonttools python fonts.py <gen folder>
Written by AI on 2026.11.18 by model claude fable 5.2.

SF Compact Rounded comes with macOS as one variable font; Blender wants one file a weight. The
copies stay out of git: the font is Apple's.
"""
import os, sys
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

out = f"{sys.argv[1]}/fonts"
os.makedirs(out, exist_ok=True)
for name, weight in (("Medium", 556.0), ("Semibold", 656.2), ("Bold", 794.8)):
    font = TTFont("/System/Library/Fonts/SFCompactRounded.ttf")
    instantiateVariableFont(font, {"wght": weight}, inplace=True)
    font.save(f"{out}/SFCompactRounded-{name}.ttf")

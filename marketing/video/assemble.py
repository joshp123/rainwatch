"""Joins the rendered shots into one run of frames, in the order of the cut.
Run: uv run python assemble.py <shots folder> <cut folder> [--unnamed] [--step 4]
Written by AI on 2026.11.18 by model claude fable 5.2.

The cut is the one in blender/film.py (SHOTS). Every join is a plain cut, so frames are linked, not copied.
"""
import os, sys

shots, cut = sys.argv[1], sys.argv[2]
unnamed = "--unnamed" in sys.argv
step = int(sys.argv[sys.argv.index("--step") + 1]) if "--step" in sys.argv else 1
END = "end-unnamed" if unnamed else "end"
# (first frame, shot); a shot runs to the next one's first frame.
ORDER = [(0, "glance"), (196, "street"), (392, "rain"), (616, "se"), (644, "series"), (672, END)]

os.makedirs(cut, exist_ok=True)
for name in os.listdir(cut):
    os.remove(f"{cut}/{name}")
missing = []
for frame in range(0, 840, step):
    shot = [name for first, name in ORDER if first <= frame][-1]
    # The two cuts end on the same frames (SAME_FROM in blender/film.py).
    if shot == "end-unnamed" and frame >= 800:
        shot = "end"
    source = f"{shots}/{shot}/{frame:04d}.png"
    if not os.path.exists(source):
        missing.append(frame)
        continue
    os.symlink(os.path.abspath(source), f"{cut}/{frame // step:04d}.png")
print(f"{840 // step - len(missing)} frames in {cut}" + (f"; missing {missing}" if missing else ""))
sys.exit(1 if missing else 0)

# /// script
# requires-python = ">=3.12"
# dependencies = ["numpy==2.3.4", "scipy==1.16.3"]
# ///
# Written by AI on 2026.11.18 by model claude opus 5.5, for the RainWatch launch film.
"""Measure a render of the score without playing it.

    uv run check.py [OUT_DIR]

Needs a render made with --stems. Prints the onsets against the cues, the
loudness through the film, the voice band in the middle of the image, the
mono fold-down, what a phone speaker keeps, and the loop seam.
"""

import json
import sys
import wave
from pathlib import Path

import numpy as np
from scipy import signal

out = Path(sys.argv[1] if len(sys.argv) > 1 else "/Volumes/Josh Extreme Pro USB4 4TB/rainwatch-film/music")
cues = json.loads((out / "cues.json").read_text())
SR = 48_000


def read(path):
    with wave.open(str(path)) as w:
        raw = np.frombuffer(w.readframes(w.getnframes()), np.uint8).reshape(-1, 3)
    pcm = np.zeros((len(raw), 4), np.uint8)
    pcm[:, 1:] = raw
    return (pcm.view("<i4")[:, 0] / 2 ** 31).reshape(-1, 2).T


def db(x):
    return 10 * np.log10(np.maximum(x, 1e-20))


def onset(x, expected, window=0.06):
    """First sample within the window around a cue where the stem's envelope rises to
    half of its local peak."""
    env = np.abs(x).max(axis=0)
    a, b = int((expected - window) * SR), int((expected + window) * SR)
    seg = env[max(a, 0):b]
    return (max(a, 0) + np.argmax(seg >= 0.5 * seg.max())) / SR


music = read(out / "music.wav")
print(f"samples {music.shape[1]} ({music.shape[1] / SR:.4f} s), expected {cues['samples']}")

print("\nonsets, measured on the stems:")
worst = 0.0
for name, stem in [("tick", "ticks"), ("arrival", "impact"), ("cut", "hits"), ("name", "bells")]:
    x = read(out / "stems" / f"{stem}.wav")
    for cue, c in cues["cues"].items():
        if cue.startswith(name):
            err = (onset(x, c["seconds"]) - c["seconds"]) * 1000
            worst = max(worst, abs(err))
            print(f"  {cue:10s} {c['seconds']:8.4f} s  error {err:+6.2f} ms")
print(f"  worst {worst:.2f} ms (one frame is 33.3 ms)")


def k_weight(x):
    b1, a1 = [1.53512485958697, -2.69169618940638, 1.19839281085285], [1, -1.69065929318241, 0.73248077421585]
    b2, a2 = [1.0, -2.0, 1.0], [1, -1.99004745483398, 0.99007225036621]
    return signal.lfilter(b2, a2, signal.lfilter(b1, a1, x, axis=-1), axis=-1)


def momentary(x, length=3.0, hop=0.25):
    y = k_weight(x) ** 2
    n, h = int(length * SR), int(hop * SR)
    return [(i / SR, -0.691 + db(y[:, i:i + n].mean(axis=1).sum())) for i in range(0, y.shape[1] - n + 1, h)]


st = momentary(music)
t_max, l_max = max(st, key=lambda p: p[1])
m = momentary(music, 0.4, 0.05)
print("\nloudest 400 ms windows:", ", ".join(f"{a:.2f} s {b:.1f}" for a, b in sorted(m, key=lambda p: -p[1])[:4]))
print(f"loudest 3 s window starts at {t_max:.2f} s ({l_max:.1f} LUFS short-term)")

sections = [("glance", 0, "push"), ("push", "push", "two_hours"), ("two hours", "two_hours", "arrival"),
            ("arrival", "arrival", "groove_back"), ("widgets", "groove_back", "three_watches"),
            ("end", "three_watches", "end")]


def t(c):
    return 0 if c == 0 else cues["cues"][c]["seconds"]


def band(x, lo, hi):
    return signal.sosfilt(signal.butter(4, [lo, hi], "bandpass", fs=SR, output="sos"), x)


mid = music.mean(axis=0)
side = (music[0] - music[1]) / 2
voice = band(mid, 300, 4000)
low = band(mid, 30, 300)
high = signal.sosfilt(signal.butter(4, 4000, "highpass", fs=SR, output="sos"), mid)
phone = signal.sosfilt(signal.butter(4, 200, "highpass", fs=SR, output="sos"), mid)
lowphone = band(mid, 200, 500)
print("\nper section (dB, relative to the whole mid channel of that section):")
print(f"  {'section':10s} {'LUFS':>6s} {'<300':>6s} {'300-4k':>7s} {'>4k':>6s} {'side':>6s} {'mono drop':>9s} {'200-500 on phone':>17s}")
for name, a, b in sections:
    i, j = int(t(a) * SR), int(t(b) * SR)
    total = (mid[i:j] ** 2).mean()
    rel = lambda y: db((y[i:j] ** 2).mean() / total)
    stereo_power = (music[:, i:j] ** 2).mean(axis=0).mean()
    mono_drop = db((mid[i:j] ** 2).mean() / stereo_power)
    lufs = -0.691 + db((k_weight(music[:, i:j]) ** 2).mean(axis=1).sum())
    phone_low = db((lowphone[i:j] ** 2).mean() / (phone[i:j] ** 2).mean())
    print(f"  {name:10s} {lufs:6.1f} {rel(low):6.1f} {rel(voice):7.1f} {rel(high):6.1f} {rel(side):6.1f} {mono_drop:9.1f} {phone_low:17.1f}")
corr = np.corrcoef(music[0], music[1])[0, 1]
print(f"\nleft/right correlation {corr:.2f}")

join = np.concatenate([music, music], axis=1)
n = music.shape[1]
diffs = np.abs(np.diff(join, axis=1)).max(axis=0)
around = diffs[n - SR // 2:n + SR // 2]
print(f"loop seam: largest sample step within 0.5 s of the join {around.max():.4f}, "
      f"at the join {diffs[n - 1]:.4f}, largest anywhere in the film {diffs[:n - 1].max():.4f}")

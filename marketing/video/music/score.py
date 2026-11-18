# /// script
# requires-python = ">=3.12"
# dependencies = ["numpy==2.3.4", "scipy==1.16.3"]
# ///
# Written by AI on 2026.11.18 by model claude opus 5.5, for the RainWatch launch film.
"""The score for the RainWatch launch film, synthesised from nothing.

    uv run score.py [OUT_DIR] [--stems]

writes OUT_DIR/music.wav (48 kHz, stereo, 24-bit) and OUT_DIR/cues.json.
With --stems it also writes each instrument on its own to OUT_DIR/stems/.
"""

import json
import sys
import wave
from pathlib import Path

import numpy as np
from scipy import ndimage, signal

# ---------------------------------------------------------------- the cut ---
# Every time in the film is a beat number. One beat is 14 frames at 30 fps.
SR = 48_000
BPM = 900 / 7
BEATS = 60                       # 15 bars of 4/4: the film loops after beat 60

PUSH = 8                         # bar 3: the camera pushes through the glass
TWO_HOURS = 12                   # bar 4: the full groove
COUNTDOWN = [12 + 2 * i for i in range(10)]   # "10" .. "1", one every two beats
ARRIVAL = 32                     # bar 9 beat 1: the rain arrives
GROOVE_BACK = 40                 # bar 11: the widgets lift off the face
CUTS = [44, 46, 48]              # the cuts to the other watches, and from them to the comparison
THREE_WATCHES = 48               # the comparison
NAME = 55                        # "RainWatch"
LOWER = 56                       # bar 15: the watch lowers, hand back to bar 1

BEAT_S = 60 / BPM
N = round(BEATS * BEAT_S * SR)   # the length of the loop in samples
TAIL = 4 * SR                    # rendered past the end, then folded onto the start


def at(beat):
    """Sample index of a beat."""
    return round(beat * BEAT_S * SR)


def secs(beat):
    return beat * BEAT_S


# ------------------------------------------------------------- harmony ------
def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


# (start beat, chord tones for the pad, bass root)
A_MIN = [57, 60, 64, 71]    # A minor add 9
F_MAJ = [53, 57, 60, 64]    # F major 7
C_MAJ = [55, 60, 62, 67]    # C add 9
G_MAJ = [55, 59, 62, 69]    # G 6/9
E_SUS = [57, 59, 64, 71]    # E sus 4
E_MAJ = [56, 59, 64, 68]    # E major
CHORDS = [
    (0, A_MIN, 33), (8, F_MAJ, 29), (10, G_MAJ, 31),
    (12, A_MIN, 33), (16, F_MAJ, 29), (20, C_MAJ, 36), (24, G_MAJ, 31),
    (28, E_SUS, 28), (30, E_MAJ, 28),
    (32, F_MAJ, 29), (36, G_MAJ, 31),
    (40, A_MIN, 33), (44, F_MAJ, 29), (48, C_MAJ, 36), (52, F_MAJ, 29), (56, G_MAJ, 31),
]
PENTATONIC = [81, 84, 86, 88, 91, 93, 96, 98, 100, 103, 105, 108]   # A5 up


def chord_at(beat):
    current = CHORDS[0]
    for c in CHORDS:
        if c[0] <= beat:
            current = c
    return current


def automation(points, n=N + TAIL):
    """A curve through (beat, value) points, linear between them."""
    beats = np.arange(n) / (BEAT_S * SR)
    xs, ys = zip(*points)
    return np.interp(beats, xs, ys).astype(np.float32)


# ------------------------------------------------------------ primitives ----
def stem():
    return np.zeros((2, N + TAIL), dtype=np.float32)


def place(bus, sound, beat, gain=1.0, pan=0.0):
    """Add a mono or stereo sound to a bus at a beat; pan -1 left to 1 right."""
    i = at(beat)
    if sound.ndim == 1:
        left, right = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        sound = np.stack([sound * left, sound * right]) * np.sqrt(2)
    n = min(sound.shape[1], bus.shape[1] - i)
    bus[:, i:i + n] += gain * sound[:, :n]


def t_axis(seconds):
    return np.arange(int(seconds * SR)) / SR


def saw(freq, seconds, phase=0.0):
    """Band-limited sawtooth (PolyBLEP)."""
    n = int(seconds * SR)
    dt = np.full(n, freq / SR) if np.isscalar(freq) else freq / SR
    t = (phase + np.cumsum(dt)) % 1.0
    y = 2 * t - 1
    lo = t < dt
    x = t[lo] / dt[lo]
    y[lo] -= 2 * x - x * x - 1
    hi = t > 1 - dt
    x = (t[hi] - 1) / dt[hi]
    y[hi] -= x * x + 2 * x + 1
    return y


def sweep_sine(freq):
    return np.sin(2 * np.pi * np.cumsum(freq) / SR)


def sos(kind, cutoff, order=2):
    return signal.butter(order, cutoff, kind, fs=SR, output="sos")


def filt(x, kind, cutoff, order=2):
    return signal.sosfilt(sos(kind, cutoff, order), x, axis=-1).astype(np.float32)


def moving_lowpass(x, cutoff, q=0.8, block=64):
    """Resonant low-pass whose cutoff follows a per-sample curve."""
    y = np.empty_like(x)
    zi = np.zeros(2)
    for i in range(0, len(x), block):
        w = 2 * np.pi * min(float(cutoff[i:i + block].mean()), 0.45 * SR) / SR
        alpha = np.sin(w) / (2 * q)
        cw = np.cos(w)
        b = np.array([(1 - cw) / 2, 1 - cw, (1 - cw) / 2])
        a = np.array([1 + alpha, -2 * cw, 1 - alpha])
        y[i:i + block], zi = signal.lfilter(b / a[0], a / a[0], x[i:i + block], zi=zi)
    return y


def moving_bandpass(x, centre, q=1.2, block=128):
    y = np.empty_like(x)
    zi = np.zeros(2)
    for i in range(0, len(x), block):
        w = 2 * np.pi * min(float(centre[i:i + block].mean()), 0.45 * SR) / SR
        alpha = np.sin(w) / (2 * q)
        b = np.array([alpha, 0, -alpha])
        a = np.array([1 + alpha, -2 * np.cos(w), 1 - alpha])
        y[i:i + block], zi = signal.lfilter(b / a[0], a / a[0], x[i:i + block], zi=zi)
    return y


def widen(x, amount):
    """Scale the side of a stereo sound; the mono fold-down stays the same."""
    mid, side = (x[0] + x[1]) / 2, (x[0] - x[1]) / 2 * amount
    return np.stack([mid + side, mid - side])


def fade(x, attack=0.002, release=0.01):
    n = x.shape[-1]
    env = np.ones(n)
    a, r = min(int(attack * SR), n), min(int(release * SR), n)
    if a:
        env[:a] = np.linspace(0, 1, a)
    if r:
        env[n - r:] *= np.linspace(1, 0, r)
    return x * env


# ----------------------------------------------------------- instruments ----
def kick(length=0.42, f_end=50.0, decay=0.17, rng=None):
    t = t_axis(length)
    f = f_end + 110 * np.exp(-t / 0.032) + 380 * np.exp(-t / 0.003)
    body = sweep_sine(f) * np.exp(-t / decay)
    body = np.tanh(2.4 * body) / np.tanh(2.4)
    click = filt(rng.standard_normal(len(t)) * np.exp(-t / 0.002), "highpass", 2500)
    return fade(body + 0.25 * click, 0.0005, 0.03)


def boom(rng):
    """The sub drop under the rain's arrival, on F."""
    t = t_axis(3.5)
    f = hz(29) + 60 * np.exp(-t / 0.06)
    x = sweep_sine(f) * np.exp(-t / 0.7)
    return fade(np.tanh(2.0 * x) / np.tanh(2.0), 0.001, 0.4)


def noise_hit(rng, length, decay, hp, lp=16000, stereo=True):
    t = t_axis(length)
    env = np.exp(-t / decay)
    chans = [filt(filt(rng.standard_normal(len(t)), "highpass", hp), "lowpass", lp) * env
             for _ in range(2 if stereo else 1)]
    x = np.stack(chans) if stereo else chans[0]
    return fade(x, 0.0005, 0.02)


def hat(rng, open_=False):
    t = t_axis(0.35 if open_ else 0.06)
    ratios = [2.0, 3.0, 4.16, 5.43, 6.79, 8.21]
    metal = sum(np.sign(np.sin(2 * np.pi * 330 * r * t + rng.uniform(0, 6.28))) for r in ratios)
    x = 0.5 * metal / len(ratios) + rng.standard_normal(len(t))
    x = filt(x, "highpass", 7500, 4)
    return fade(x * np.exp(-t / (0.11 if open_ else 0.018)), 0.0003, 0.01)


def clap(rng):
    t = t_axis(0.3)
    bursts = sum(np.exp(-np.clip(t - d, 0, None) / 0.006) * (t >= d) for d in (0, 0.009, 0.019))
    env = 0.6 * bursts + np.exp(-np.clip(t - 0.02, 0, None) / 0.07) * (t >= 0.02)
    x = filt(filt(rng.standard_normal(len(t)), "highpass", 1100), "lowpass", 9000) * env
    return fade(x, 0.0003, 0.02)


def snare(rng):
    t = t_axis(0.18)
    body = np.sin(2 * np.pi * np.cumsum(185 + 60 * np.exp(-t / 0.01)) / SR) * np.exp(-t / 0.035)
    rattle = filt(rng.standard_normal(len(t)), "bandpass", [1800, 9000]) * np.exp(-t / 0.05)
    return fade(0.5 * body + rattle, 0.0003, 0.02)


def drop(midi, length=0.16, decay=0.045, rise=0.6):
    """A water drop: a short sine that bends up as the bubble closes."""
    t = t_axis(length)
    f = hz(midi) * (1 + rise * (1 - np.exp(-t / 0.015)))
    x = sweep_sine(f) + 0.12 * np.sin(2 * np.cumsum(2 * np.pi * f) / SR)
    return fade(x * np.exp(-t / decay), 0.0008, 0.01)


def pluck(midi, length=0.5, index=1.6, decay=0.13):
    """Glassy FM pluck for the arpeggio."""
    t = t_axis(length)
    f = hz(midi)
    mod = index * np.exp(-t / 0.05) * np.sin(2 * np.pi * f * t)
    x = np.sin(2 * np.pi * f * t + mod) * np.exp(-t / decay)
    return fade(x, 0.001, 0.05)


def bell(midi, rng, length=3.0):
    t = t_axis(length)
    f = hz(midi)
    mod = 2.2 * np.exp(-t / 0.4) * np.sin(2 * np.pi * f * 3.5 * t)
    x = np.sin(2 * np.pi * f * t + mod) * np.exp(-t / 0.9)
    return fade(x, 0.001, 0.3)


def supersaw(midi, seconds, rng, voices=5, spread=0.11):
    """One note of the pad, two channels detuned differently so they stay wide in stereo
    without cancelling in mono."""
    chans = []
    for _ in range(2):
        x = np.zeros(int(seconds * SR))
        for v in range(voices):
            cents = (v - (voices - 1) / 2) / ((voices - 1) / 2) * spread * 100 + rng.normal(0, 3)
            x += saw(hz(midi) * 2 ** (cents / 1200), seconds, rng.uniform())
        chans.append(x / voices)
    return np.stack(chans)


# ----------------------------------------------------------------- score ----
def compose():
    rng = np.random.default_rng(20261118)
    s = {name: stem() for name in
         ("kick", "bass", "hats", "claps", "pad", "arp", "ticks", "build", "impact", "hits",
          "bells", "rain")}

    groove = [b for b in range(BEATS) if not ARRIVAL <= b < GROOVE_BACK]

    # Four on the floor, from the first sample, except while the rain arrives.
    for b in groove:
        place(s["kick"], kick(rng=rng), b)
    place(s["impact"], kick(1.2, 42, 0.45, rng), ARRIVAL, 1.3)
    for b in (38, 39):                                    # it creeps back in
        place(s["kick"], filt(kick(rng=rng), "lowpass", 300), b, 0.5 + 0.2 * (b - 38))

    # Rolling bass on the three sixteenths between kicks, filter following the film.
    bass_raw = np.zeros(N + TAIL, dtype=np.float32)
    sub = np.zeros(N + TAIL, dtype=np.float32)
    env = np.zeros(N + TAIL, dtype=np.float32)
    for b in groove:
        root = chord_at(b)[2]
        for k in (1, 2, 3):
            note = root + (12 if (k == 3 and b % 2) else 0)
            length = BEAT_S / 4 * 0.85
            t = t_axis(length)
            amp = fade(np.exp(-t / 0.09), 0.003, 0.012)
            i = at(b + k / 4)
            n = len(t)
            bass_raw[i:i + n] += (saw(hz(note + 12), length) * amp).astype(np.float32)
            sub[i:i + n] += (np.sin(2 * np.pi * hz(note) * t) * amp).astype(np.float32)
            env[i:i + n] = np.maximum(env[i:i + n], np.exp(-t / 0.035))
    cutoff = automation([(0, 300), (PUSH, 330), (TWO_HOURS, 520), (24, 560), (31.75, 1100),
                         (GROOVE_BACK, 560), (THREE_WATCHES, 640), (LOWER, 640), (BEATS, 300),
                         (BEATS + 8, 300)])
    bass = moving_lowpass(bass_raw, cutoff * (1 + 2.5 * env), q=1.1) + 0.5 * sub
    bass = np.tanh(1.5 * bass) / 1.5
    s["bass"] += np.stack([bass, bass])

    # Hats: sixteenths, the off-beat opens once the groove is full.
    for b in range(BEATS):
        if ARRIVAL <= b < 36:
            continue
        full = TWO_HOURS <= b < ARRIVAL or GROOVE_BACK <= b
        for k, vel in enumerate((0.35, 0.6, 1.0, 0.6)):
            vel *= rng.uniform(0.85, 1.0) * (0.8 if not full else 1.0)
            if 36 <= b < GROOVE_BACK:
                vel *= 0.35 + 0.15 * (b - 36)
                if k % 2:
                    continue
            if k == 2 and full:
                place(s["hats"], hat(rng, open_=True), b + 0.5, 0.55, 0.15)
            else:
                place(s["hats"], hat(rng), b + k / 4, 0.5 * vel, -0.25 if k % 2 else 0.25)

    # Claps on two and four in the full groove.
    for b in groove:
        if b % 2 and (TWO_HOURS <= b < ARRIVAL or GROOVE_BACK <= b < BEATS - 1):
            place(s["claps"], clap(rng), b)

    # Snare builds into the push, the arrival and the return.
    def roll(start, end, step, g0, g1):
        hits = np.arange(start, end, step)
        for j, h in enumerate(hits):
            place(s["build"], snare(rng), h, g0 + (g1 - g0) * j / max(len(hits) - 1, 1))
    roll(10, 12, 0.25, 0.15, 0.55)
    roll(28, 30, 0.5, 0.25, 0.45)
    roll(30, 31.75, 0.25, 0.45, 0.9)
    roll(38, 40, 0.25, 0.15, 0.6)

    # Noise risers: into the groove, into the rain, into the return, and into the loop.
    def riser(start, end, f0, f1, gain):
        n = at(end) - at(start)
        x = rng.standard_normal((2, n))
        centre = np.geomspace(f0, f1, n)
        y = np.stack([moving_bandpass(c, centre) for c in x])
        y *= np.linspace(0, 1, n) ** 2.5
        place(s["build"], fade(y, 0.01, 0.004), start, gain)
    riser(PUSH, TWO_HOURS, 300, 5000, 0.35)
    riser(24, 31.75, 400, 9000, 0.6)
    riser(36, GROOVE_BACK, 500, 7000, 0.4)
    riser(BEATS - 1.5, BEATS, 1000, 6000, 0.18)

    # The pad: one supersaw chord a bar, pumping against the kick, filter following the film.
    pad = stem()
    for j, (b, tones, _) in enumerate(CHORDS):
        end = CHORDS[j + 1][0] if j + 1 < len(CHORDS) else BEATS + 1
        length = secs(end - b) + 0.35
        for m in tones:
            note = supersaw(m, length, rng)
            t = t_axis(length)
            env_ = np.minimum(1, t / 0.02) * np.clip((length - t) / 0.35, 0, 1)
            place(pad, note * env_, b, 0.25)
    pad = filt(pad, "highpass", 230)
    cutoff = automation([(0, 650), (PUSH, 700), (TWO_HOURS, 1900), (31.75, 2600),
                         (ARRIVAL, 6500), (34, 2200), (GROOVE_BACK, 1800), (THREE_WATCHES, 2100),
                         (LOWER, 2100), (BEATS, 650), (BEATS + 8, 650)])
    pad = np.stack([moving_lowpass(c, cutoff, q=0.9) for c in pad])
    idx = np.array([at(b) for b in groove + [BEATS]])
    pos = np.searchsorted(idx, np.arange(N + TAIL), side="right") - 1
    since = np.where(pos >= 0, (np.arange(N + TAIL) - idx[np.clip(pos, 0, None)]) / SR, 10.0)
    pump = 1 - 0.7 * np.exp(-since / 0.11)
    pump = signal.sosfilt(sos("lowpass", 150, 1), pump).astype(np.float32)
    swell = automation([(0, 0.8), (TWO_HOURS, 1.0), (ARRIVAL, 1.6), (36, 0.9),
                        (GROOVE_BACK, 1.0), (BEATS, 0.8), (BEATS + 8, 0.8)])
    s["pad"] += widen(pad * pump * swell, 1.6)

    # The arpeggio: glass drops on the chord, sixteenths in the groove, eighths in the space.
    arp = stem()
    order = [0, 2, 1, 3, 2, 0, 3, 1]
    step = 0
    for q in range(int(PUSH * 4), BEATS * 4):
        b = q / 4
        if 31.75 <= b < ARRIVAL:
            continue
        sparse = b < TWO_HOURS or ARRIVAL <= b < GROOVE_BACK
        if sparse and q % 2:
            continue
        tones = chord_at(b)[1]
        note = sorted(tones)[order[step % 8]] + 24
        step += 1
        gain = (0.9 if q % 4 == 0 else 0.6) * rng.uniform(0.85, 1.0)
        if b < TWO_HOURS:
            gain *= 0.25 + 0.75 * (b - PUSH) / (TWO_HOURS - PUSH)
        if b >= LOWER:
            gain *= 1 - (b - LOWER) / (BEATS - LOWER)
        place(arp, pluck(note), b, 0.22 * gain, 0.45 if step % 2 else -0.45)
    delay = at(0.75)
    echoes = stem()
    for k in range(1, 7):
        g = 0.42 ** k
        src = arp[::-1] if k % 2 else arp      # ping-pong: swap channels each repeat
        echoes[:, k * delay:] += g * src[:, :-k * delay]
    s["arp"] += widen(arp + filt(echoes, "lowpass", 5000), 1.4)

    # The countdown: one drop on each number, climbing, and closer together near zero.
    for i, b in enumerate(COUNTDOWN):
        place(s["ticks"], drop(PENTATONIC[i]), b, 0.5)
        if i == 7:
            extra = [1.0]
        elif i == 8:
            extra = [0.5, 1.0, 1.5]
        elif i == 9:
            extra = [0.25 * k for k in range(1, 7)]
        else:
            extra = []
        for j, e in enumerate(extra):
            note = PENTATONIC[min(i + 1 + j // 2, len(PENTATONIC) - 1)]
            place(s["ticks"], drop(note, decay=0.03), b + e, 0.22 + 0.05 * j,
                  0.3 if j % 2 else -0.3)

    # The rain arrives: sub drop, crash, the first drops, then rain until the watch lowers.
    place(s["impact"], boom(rng), ARRIVAL, 1.0)
    place(s["impact"], noise_hit(rng, 3.0, 0.9, 3500), ARRIVAL, 0.35)
    for _ in range(16):
        dt = rng.uniform(0, 0.9) ** 1.6
        place(s["impact"], drop(int(rng.choice(PENTATONIC[3:])), decay=0.04),
              ARRIVAL + dt / BEAT_S, 0.35 * (1 - dt), rng.uniform(-0.8, 0.8))
    n = at(BEATS) - at(ARRIVAL)
    rain = filt(filt(rng.standard_normal((2, n)), "highpass", 3000), "lowpass", 12000) * 0.12
    for _ in range(int(40 * n / SR)):
        i = rng.integers(0, n - 2000)
        d = drop(int(rng.choice(PENTATONIC[2:])), 0.04, 0.008, 0.9)
        p = rng.uniform(0, 1)
        rain[0, i:i + len(d)] += d * (1 - p) * 0.25
        rain[1, i:i + len(d)] += d * p * 0.25
    level = automation([(ARRIVAL, 1.0), (36, 0.6), (LOWER, 0.6), (BEATS, 0.0)])
    rain *= level[at(ARRIVAL):at(BEATS)]
    place(s["rain"], fade(rain, 0.002, 0.05), ARRIVAL)

    # The cuts to the other watches: a low tom and a short splash.
    for b in CUTS:
        t = t_axis(0.5)
        tom = sweep_sine(95 + 70 * np.exp(-t / 0.03)) * np.exp(-t / 0.16)
        place(s["hits"], fade(tom, 0.0005, 0.05), b, 0.7)
        place(s["hits"], noise_hit(rng, 0.8, 0.25, 5000), b, 0.25)

    # The name: a struck glass chord, F major 7, rolled upwards.
    for j, m in enumerate([77, 81, 84, 88, 93]):
        place(s["bells"], bell(m, rng), NAME + j * 0.02 / BEAT_S, 0.16, (j - 2) * 0.3)
    place(s["bells"], noise_hit(rng, 2.0, 0.6, 6000), NAME, 0.12)

    # Silence for the last sixteenth before the rain, so the arrival hits from nothing.
    gate = np.ones(N + TAIL, dtype=np.float32)
    a, z = at(31.75), at(ARRIVAL)
    gate[a:z] = 0
    gate[a:a + 240] = np.linspace(1, 0, 240)
    for name in s:
        if name != "impact":
            s[name] *= gate
    return s, gate


def reverb(x, rng, seconds=2.4):
    t = t_axis(seconds)
    ir = rng.standard_normal((2, len(t))) * np.exp(-t / (seconds / 6.9))
    ir = filt(filt(ir, "highpass", 350), "lowpass", 7000)
    ir /= np.sqrt((ir ** 2).sum(axis=1, keepdims=True))
    wet = np.stack([signal.oaconvolve(x[c], ir[c])[:x.shape[1]] for c in range(2)])
    return wet.astype(np.float32)


# ----------------------------------------------------------------- master ---
def k_weight(x):
    """ITU-R BS.1770 K-weighting at 48 kHz."""
    b1, a1 = [1.53512485958697, -2.69169618940638, 1.19839281085285], [1, -1.69065929318241, 0.73248077421585]
    b2, a2 = [1.0, -2.0, 1.0], [1, -1.99004745483398, 0.99007225036621]
    return signal.lfilter(b2, a2, signal.lfilter(b1, a1, x, axis=-1), axis=-1)


def integrated_lufs(x):
    y = k_weight(x)
    block, hop = int(0.4 * SR), int(0.1 * SR)
    power = np.array([(y[:, i:i + block] ** 2).mean(axis=1).sum()
                      for i in range(0, y.shape[1] - block + 1, hop)])
    loud = -0.691 + 10 * np.log10(power + 1e-12)
    power = power[loud > -70]
    rel = -0.691 + 10 * np.log10(power.mean()) - 10
    power = power[-0.691 + 10 * np.log10(power) > rel]
    return -0.691 + 10 * np.log10(power.mean())


def true_peak(x):
    return np.abs(signal.resample_poly(x, 4, 1, axis=-1)).max()


def limit(x, ceiling_db=-1.5, release=0.08):
    """Look-ahead limiter on the 4x over-sampled peak, treating the music as a loop."""
    ceiling = 10 ** (ceiling_db / 20)
    over = np.abs(signal.resample_poly(np.concatenate([x[:, -64:], x, x[:, :64]], axis=1), 4, 1, axis=-1))
    peak = over.max(axis=0).reshape(-1, 4).max(axis=1)[64:-64]
    want = np.minimum(1.0, ceiling / np.maximum(peak, 1e-9))
    look = int(0.0015 * SR)
    want = np.roll(ndimage.minimum_filter1d(want, 2 * (look // 2) + 1, mode="wrap"), -(look // 2))
    gain = np.empty_like(want)
    r = np.exp(-1 / (release * SR))
    g = 1.0
    for _ in range(2):                    # second pass so the loop's start inherits its end
        for i, w in enumerate(want):
            g = w if w < g else w + (g - w) * r
            gain[i] = g
    gain = np.convolve(np.concatenate([gain[-look:], gain]), np.ones(look) / look, "valid")[1:]
    return x * np.minimum(gain[:x.shape[1]], 1.0)


def master(mix, target=-16.0):
    mix = filt(mix, "highpass", 32)
    # Leave the voice room: a gentle dip at its presence band, in the middle of the image only.
    mid, side = (mix[0] + mix[1]) / 2, (mix[0] - mix[1]) / 2
    b, a = peaking(2200, -3.0, 0.7)
    mid = signal.lfilter(b, a, mid)
    mix = np.stack([mid + side, mid - side])
    for _ in range(3):
        mix = mix * 10 ** ((target - integrated_lufs(mix)) / 20)
        mix = limit(mix)
    return mix.astype(np.float32)


def peaking(freq, gain_db, q):
    A = 10 ** (gain_db / 40)
    w = 2 * np.pi * freq / SR
    alpha = np.sin(w) / (2 * q)
    b = np.array([1 + alpha * A, -2 * np.cos(w), 1 - alpha * A])
    a = np.array([1 + alpha / A, -2 * np.cos(w), 1 - alpha / A])
    return b / a[0], a / a[0]


LEVELS = {   # dB, set by measuring each stem against the kick
    "kick": -2.0, "bass": -5.0, "hats": -6.0, "claps": -8.0, "pad": -3.0, "arp": -6.0,
    "ticks": -5.0, "build": -8.0, "impact": -3.0, "hits": -5.0, "bells": -4.0, "rain": -8.0,
}
SENDS = {"claps": 0.25, "pad": 0.2, "arp": 0.35, "ticks": 0.3, "build": 0.15, "impact": 0.4,
         "hits": 0.3, "bells": 0.45, "rain": 0.2}


def loop(x):
    """Fold everything that rings past the end back onto the start."""
    out = x[:, :N].copy()
    out[:, :TAIL] += x[:, N:N + TAIL]
    return out


def write_wav(path, x):
    pcm = np.ascontiguousarray(np.clip(np.round(x.T * (2 ** 23 - 1)), -2 ** 23, 2 ** 23 - 1).astype("<i4"))
    raw = pcm.view(np.uint8).reshape(-1, 4)[:, :3].tobytes()
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(3)
        w.setframerate(SR)
        w.writeframes(raw)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    out = Path(args[0] if args else "/Volumes/Josh Extreme Pro USB4 4TB/rainwatch-film/music")
    out.mkdir(parents=True, exist_ok=True)
    stems, gate = compose()
    rng = np.random.default_rng(7)
    mix = np.zeros((2, N + TAIL), dtype=np.float32)
    send = np.zeros_like(mix)
    for name, x in stems.items():
        g = 10 ** (LEVELS[name] / 20)
        mix += g * x
        send += g * SENDS.get(name, 0) * x
    mix += reverb(send, rng) * 0.6 * np.where(np.arange(N + TAIL) < at(ARRIVAL), gate, 1)
    music = master(loop(mix))
    write_wav(out / "music.wav", music)
    if "--stems" in sys.argv:
        (out / "stems").mkdir(exist_ok=True)
        for name, x in stems.items():
            write_wav(out / "stems" / f"{name}.wav", np.clip(loop(x) * 0.25, -1, 1))
    cues = {"bpm": BPM, "frames_per_beat": round(BEAT_S * 30, 6), "samples": N, "seconds": N / SR,
            "cues": {name: {"beat": b, "seconds": round(secs(b), 4), "frame": round(secs(b) * 30)}
                     for name, b in [("push", PUSH), ("two_hours", TWO_HOURS), ("arrival", ARRIVAL),
                                     ("groove_back", GROOVE_BACK), ("three_watches", THREE_WATCHES),
                                     ("name", NAME), ("lower", LOWER), ("end", BEATS)]
                     + [(f"tick_{10 - i}", b) for i, b in enumerate(COUNTDOWN)]
                     + [(f"cut_{i + 1}", b) for i, b in enumerate(CUTS)]}}
    (out / "cues.json").write_text(json.dumps(cues, indent=2) + "\n")
    print(f"{out / 'music.wav'}: {N} samples, {integrated_lufs(music):.2f} LUFS, "
          f"true peak {20 * np.log10(true_peak(music)):.2f} dBTP")


if __name__ == "__main__":
    main()

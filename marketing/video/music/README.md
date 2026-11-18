<!-- Written by AI on 2026.11.18 by model claude opus 5.5, for the RainWatch launch film. -->

# The film's music

```sh
cd marketing/video/music && uv run score.py --stems && uv run check.py
```

`score.py` synthesises the whole score with numpy and scipy (no samples, no MIDI, nothing bought) and writes `music.wav` (48 kHz, stereo, 24-bit, exactly 28.000 s) and `cues.json` to `/Volumes/Josh Extreme Pro USB4 4TB/rainwatch-film/music/`, or to the folder given as its first argument. `--stems` also writes each instrument on its own to `stems/`. The same code gives the same file, bit for bit. `check.py` measures the render: onsets against the cues, loudness through the film, the voice band, the mono fold-down and the loop seam.

## How it follows the cut

The tempo is 900/7 BPM (about 128.6), so one beat is exactly 14 frames at 30 fps and the 15 bars are 840 frames. Every cue is a beat number at the top of `score.py`; move one there and render again.

| Beats | Picture | Music |
|---|---|---|
| 0 to 8 | the glance | kick, rolling bass and hats from the first sample, pad and bass filtered down |
| 8 to 12 | through the glass | filters open, glass-drop arpeggio fades in, noise riser and snare roll |
| 12 to 32 | the two hours | full groove; a water drop on each number of the countdown, climbing the A minor pentatonic; from "3" the drops double, then come in eighths, then sixteenths; snare roll and riser; one sixteenth of silence |
| 32 | the rain arrives | sub drop, crash, a splash of drops, the pad wide open on F major 7; rain starts |
| 32 to 40 | back out to the watch | no drums, the pad and arpeggio in eighths over the rain; the groove creeps back in bar 10 |
| 40 to 48 | the widgets, the other watches | full groove; a low tom and splash on each cut (beats 44, 46 and 48) |
| 48 to 60 | the comparison, the name | full groove; a struck glass chord on the name (beat 55); the filters close and the rain stops through bar 15, so bar 1 follows on |

Key A minor: A minor, F, G | A minor, F, C, G, E | F, G | A minor, F, C, F, G. Whatever rings past the end is folded back onto the start, so the loop joins without a click or gap. The join is still a change of section: the open hats, claps and rain stop and the filters are back where bar 1 starts.

## Room for the voice

In the middle of the stereo image, where the voice will sit, the 300 Hz to 4 kHz band carries about 5 % of the power (12 to 14 dB under the whole, most of which is kick and sub), and the master dips 3 dB at 2.2 kHz there only. The pad and arpeggio are widened by their side channel, so the mono fold-down loses under 0.5 dB. The mix is -16 LUFS integrated with a true peak of -1.5 dBTP; under speech, duck it a further 8 to 12 dB.

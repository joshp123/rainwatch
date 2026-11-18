<!-- Written by AI on 2026.11.18 by model claude fable 5.2, at Josh's request. It replaces the README of the second film, by claude opus 5.5, of the same day. -->

# The launch film

A 28-second film for X: vertical, 1080 x 1920, in English, with music, made for Josh to talk over. It is one glance at the watch, opened up.

1. **0 to 3 s.** A wrist turns the watch to the wearer on a wet street before dawn, and the screen wakes: 07:40, "Dry for 10 min".
2. **3 to 6.5 s.** The circle lifts off the face and hangs large before the eyes, "IN 10 MIN". Beyond it the widget's line runs out along the street to the rain, which is coming.
3. **6.5 to 13 s.** Down on the street beside "Now": the next two hours run away from it as a ridge of glass as tall as its rain is heavy, with that rain falling over it. The camera stays where it is and the rain comes in, a minute a second, while the circle counts down.
4. **13 to 17.5 s.** Back at the wrist. The rain arrives, the first drops land on the glass, and the circle turns to "FOR 20 MIN" and drops home.
5. **17.5 to 22.5 s.** The three widgets (the circle, the wide slot, the Smart Stack card) lift off the face as tiles of black glass, turn once and drop back. Then the same complications on an SE 3 and a Series 12.
6. **22.5 to 28 s.** The circle's slot for each rain app, with its name; then "RainWatch. Free. No ads."; and the wrist lowers to where the film began, so it loops.

| Cut | What its last six seconds show |
|---|---|
| `rainwatch-en-9x16.mp4` | the circle's slot for RainWatch, Buienradar and Buienalarm, by name |
| `rainwatch-en-9x16-unnamed.mp4` | no other app: the camera stays on RainWatch's circle as it counts |

The finished films are in `~/Movies/RainWatch/`, with the music on its own (`music.wav`) for mixing a voice over it. There is no 16:9 cut, because every shot is composed for the tall frame, and no Dutch cut (Josh, 18 November 2026); the pipeline can still make one (`./render.sh nl`).

The only words the film adds are in `words.json`: the app's name, "Free. No ads." and the two other apps' names. The same words are on the "Launch video" page of the Paper design file (https://app.paper.design/file/01M7NBWW1V3TM4BBDNRMXEMP2F), where Josh edits them: after an edit, copy them into `words.json` and render. Every other word on screen is the app's own, drawn by the app's code.

## Make it again

```sh
./render.sh        # the two English cuts: about 45 minutes on an M4 Pro with 8 GB of memory to spare
./animatic.sh en   # a small draft of every fourth frame, in about fifteen minutes, to judge a change
```

`render.sh` rebuilds the film from the app's current code, with no simulator:

1. `data.py` picks the forecast (`forecast/shower.json`, see below) and `export/`, a small Swift program, draws the app's own views with it (`RainGraph`) for each minute: the Ultra's face, the same face with its slots empty, the two other watches' faces, the three complications alone, and the rain line as numbers (`line.json`), from which the line on the street is built.
2. `music/score.py` synthesises the music (`music/README.md`).
3. `shots.sh` renders each shot in Blender with Cycles (`blender/film.py`; the cut is `SHOTS` at its top, in frames, on the music's beats). `blender/world.py` is the street with the rain line and its rain, `blender/wrist.py` the watch on the wrist and the glass tiles, `blender/watch.py` and `blender/arm.py` the watches and the sleeve, all modelled in code.
4. `assemble.py` puts the shots in order and `finish.sh` enlarges them, adds the lens's glow, a little grain and the music.

Blender needs 6 to 8 GB of memory while it renders. `guard.sh '<commands>'` runs a render only while that fits, and stops it if the Mac starts swapping; use it on a Mac that is doing other work. Renders and caches go on the external SSD when it is mounted (`paths.sh`). Blender is taken from the nix store, because nixpkgs has no ready-built Blender for Apple silicon and compiles it for an hour. The picture is rendered at 810 x 1440 and enlarged (`paths.sh`, `SIZE`), which halves the time.

## What is real, and what was arranged

- **The forecast** is KNMI's forecast of 17 November 2025, 05:25 UTC, for the 1 km cell over the centre of Arnhem, as the watch would have received it (`forecast/README.md` says how it was found and how to check it). It was dry for 20 minutes, then a shower of up to 5.8 mm/h for 20 minutes, then dry. Its times are moved by 65 minutes to fit the clock on the face: the film opens at 07:40 and the rain arrives at 07:50; that morning it was 06:35 and 06:45. It was the forecast, not what fell: KNMI's radar later measured a lighter shower there.
- **Every picture on a watch's screen and every tile** is drawn by the app's own views from that forecast, minute by minute. The face behind them is a screenshot from the watch simulator: Modular Ultra on the Ultra, one a minute from 07:39 to 08:06 (`face/en`), and Infograph Modular on the SE 3 at 07:53 and the Series 12 at 07:54 (`face/se`, `face/series`), all taken on 18 November 2026 in a far-off time zone to get a morning clock. The app's two complications are drawn into each face's slots at the size and place that face gives them, which agrees with the simulator to a pixel or two (Ultra: the circle is 45 points, the wide slot is laid out at 190 x 73.5 points and shrunk to 0.884, and the watch spaces small text 0.6 points wider than the Mac; the other two are in the exporter, from measurements of their screenshots). On all three faces the wide slot has room for one line of words, so it shows the headline and not the line under it.
- **One screenshot was mended.** The simulator's screenshot for 07:41 in English showed 07:42. Its clock was replaced with the clock from the Dutch screenshot of the same face at 07:41 (`face/en/002.png`).
- **On the street** the line and its heights are the app's own curve (`line.json`), and the circle hanging before the lens is the app's circle for that minute. The rain falls only where the forecast has rain, higher and thicker where it is heavier. The street, its lamps and the wet ground are scenery, and so is the idea that the forecast's time lies along a street: the rain "walks" two metres a minute.
- **Time is compressed.** A minute of the forecast passes in 28 frames from the moment the line runs out until the widgets lift off, when the clock waits at 07:53; it runs again from 07:55 at the end. The app redraws once a minute and its line moves in five-minute steps; the film moves the line smoothly between them.
- **The tiles** are the complications as the face shows them, enlarged as they come towards the camera, with the picture on both sides. No watch does this. The Smart Stack card is not on the watch face; in the film it rises from under the face's lower edge.
- **The watches and the arm** are 3D models made in code from Apple's published sizes and its front-on product pictures, not Apple's own artwork. The watch is on a jacket sleeve and a glove; no person was filmed.
- **The comparison** (the named cut) is drawn from `competitors.md`: Buienradar's complication as two dashes on the slot's disc, Buienalarm's slot empty. Its sources are from 2022 and 2024, and nobody has checked both apps on a watch this month; check before the named cut goes out. Other rain apps do put rain on the watch face (Droog, launched 18 November 2026, has two complications); the film names only these two.

## Not ours

- SF Compact Rounded, the watch's face font, is Apple's. `fonts.py` makes the weights the film needs from the copy in macOS, outside git.
- KNMI's data is CC BY 4.0.

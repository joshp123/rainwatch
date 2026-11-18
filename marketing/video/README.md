<!-- Written by AI on 2026.11.18 by model claude opus 5.5, at Josh's request. Replaces the version of the same day by claude fable 5.2. -->

# The launch video

A 46-second film for X and similar, made to narrate over. It follows one real forecast: KNMI's radar closes in on the square kilometre at Middenmeer, that square's next two hours become the app's rain line, the line bends into the circle, and the watch face counts down to the rain. Then the Smart Stack, the radar in the app, what each rain app puts on the watch face, and the name.

| Cut | For |
|---|---|
| `nl-9x16`, `en-9x16` | X, TikTok, Reels, Shorts: 1080 x 1920 |
| `nl-16x9`, `en-16x9` | 1920 x 1080 |
| the same with `-unnamed` | the comparison names no other app |

The finished cuts are in `~/Movies/RainWatch/` (too big for git).

## Make it again

```sh
./render.sh                 # every cut, about 2.5 minutes in all
./render.sh en-9x16         # one cut
nix shell nixpkgs#nodejs_22 -c npx remotion studio src/index.ts    # scrub through it in a browser, after one render
```

`render.sh` rebuilds everything from the app's current code each time, so a change to the app's views or words shows in the next render with no simulator:

1. `data.py` reads the KNMI run in `App/RainUITests/Server` and writes `public/gen/`: Middenmeer's forecast, KNMI's 1 km cells round it, the radar over the Netherlands frame by frame in the app's radar colours (`RadarPage.swift`), and the coast and borders from Natural Earth (public domain, downloaded once into `~/.cache`).
2. `export/` is a small Swift program that draws the app's own views with `RainGraph`, in English and Dutch: the face at every minute, the circle and the wide slot on their own, the Smart Stack card, and the rain line as numbers (`line.json`) for the film to draw large and bend into the circle.
3. Remotion (`src/`) puts it together. It is free for one person or a company of three or fewer.

The film's own words are in `src/copy.ts`, and the same words are on the "Launch video" page of the Paper design file (https://app.paper.design/file/01M7NBWW1V3TM4BBDNRMXEMP2F), where Josh edits them: after an edit, copy them from Paper into `copy.ts` and render. The timing is `cut` in `src/theme.ts`. The app's words on the watch come from the app.

## What is real, and what was arranged

- **The forecast** is KNMI's plain forecast of 16 November 2026, 00:35 UTC, for the 1 km cell at Middenmeer (52.815 N, 5.012 E), the run the UI tests use. Its times are moved to the morning on the face: radar time 07:30, so at 07:40 it says "Dry for 10 min" and the rain arrives at 07:50. On a real watch newer runs would replace it every 15 to 30 minutes; the film shows this one run throughout, as if just arrived, and says "Sequence shortened".
- **The face** is a screenshot of Modular Ultra in the watch simulator, one a minute from 07:39 to 08:06, taken on 18 November 2026 with the old `capture.sh` (in git history, commit f98ac68) in Kabul's time zone to get a morning; that is why `render.sh` runs the exporter with `TZ=Asia/Kabul`. The app's two complications are drawn over the old ones by the exporter, at the size and place the face gives them. Recapture the face only if Apple changes it.
- **How true the drawn complications are.** Measured against the simulator's own screenshots: the circle is 45 points and matches; the face lays out the wide slot at 190 x 73.5 points and shrinks it to 0.884; the watch spaces small text about 0.6 points wider than the Mac draws SF Compact Rounded, so the exporter adds that. With those, the Mac's drawing and the simulator's agree to a pixel or two.
- **The radar on the watch** (`public/radar/`) is the app playing in the simulator, captured the same day, over Den Helder. It cannot be drawn on the Mac because it needs MapKit; recapture it if the radar page changes.
- **The comparison** is worded from `competitors.md`. Its sources are from 2022 and 2024; check both apps on a watch before the named cuts go out.

## Apple's rules this follows

From Apple's App Store marketing guidelines (developer.apple.com/app-store/marketing/guidelines):

- The watch is Apple's Ultra 4 bezel from Apple Design Resources (`public/bezel.png`), the newest Ultra, upright and unchanged: no tilt, shadow or spin, no words or rain over it, and no graphics that "appear to enter or come out of the product screen". The app's graphics move and turn on their own, away from the watch.
- The one push-in, on the face's countdown, comes after the whole watch has been shown, as the video section allows: "once you show an establishing shot of the entire Apple device, you may pan and zoom to focus on your app". It stops where the watch would pass under the words. The product-image section forbids cropping; this reads the video section as the rule for camera moves.
- Time that is compressed says "Sequence shortened".
- The App Store badge is Apple's own artwork (`public/badge/`, from Apple's marketing tools, in English and Dutch), once, still, with a quarter of its height clear round it, and Apple's credit line at the end.
- "Apple Watch" is never split, never has "the" before it, and "watch" is never a verb or a pun.

## Not ours

- `public/fonts/Inter.ttf`: Inter, SIL Open Font Licence (`public/fonts/Inter-OFL.txt`).
- `public/bezel.png`: Apple's product bezel, from Apple Design Resources, for showing apps on Apple Watch.
- `public/badge/`: Apple's App Store badges.
- SF Compact Rounded, the watch's face font, is copied from macOS at render time and never committed.

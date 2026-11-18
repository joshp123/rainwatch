<!-- Written by AI on 2026.11.18 by model claude fable 5.2, at Josh's request. -->

# The launch video

A 28-second film for X and similar: the hook, the chore it replaces, the rain coming on the watch face, the three places it sits, the radar, the comparison, the name. It reads without sound and leaves room for a voice-over. The finished cuts are in `~/Movies/RainWatch/` (too big for git); `render.sh` makes them again in `out/`.

| Cut | For |
|---|---|
| `nl-9x16`, `en-9x16` | X, TikTok, Reels, Shorts: 1080 x 1920 |
| `nl-16x9`, `en-16x9` | 1920 x 1080 |
| the same with `-unnamed` | the comparison names no other app |

## What is real

Every picture on the watch is a screenshot of the app in the watch simulator, in Apple's Ultra 3 frame (`design/README.md`). Nothing on the screen is drawn or retouched.

- **The face** was photographed in real time for 25 minutes while rain came, so its clock, words and line agree in every frame. The forecast is the saved KNMI forecast for Alkmaar (`Scenario.rainComing`).
- **The forecast page and the radar** are the saved forecast for Den Helder (`Scenario.rainingEasing`) and KNMI's frames from the UI tests' copy of the server's files. The radar pictures are the app playing; the film steps through them. No tool can turn the simulator's crown without the UI tests, which make sound.
- **Two things were arranged**, by `capture.patch` on a throwaway worktree, in debug builds only. The simulator's clock is the Mac's, so a time zone moves it to a morning. And the face's saved forecast is written minute by minute, arriving from the newest five-minute run, as a watch that refreshes gets it; left alone, one forecast would age for 25 minutes and the face would say so.

The comparison's wording and its sources are in `competitors.md`.

## Make it again

```sh
nix shell nixpkgs#nodejs_22 -c npm install
./render.sh                 # every cut, about 30 seconds each
./render.sh nl-9x16         # one cut
nix shell nixpkgs#nodejs_22 -c npx remotion studio src/index.ts    # scrub through it in a browser
```

The words are in `src/copy.ts`, the timing in `src/theme.ts` (`cut`), the shots in `src/Film.tsx`. It is built with Remotion, which is free for one person or a company of three or fewer.

New captures: `capture.sh <folder>` (40 minutes, silent), then `radar_order.py` and `prepare.py` as its header says. `capture.sh` was put together from the commands run by hand on 18 November 2026 and has not been run from start to finish.

## Not ours

- `public/fonts/Archivo.ttf`: Archivo, SIL Open Font Licence (`public/fonts/OFL.txt`).
- `public/ultra-3-frame.png`: Apple's product bezel, from Apple Design Resources, for showing apps on Apple Watch.

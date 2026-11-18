<!-- Written by AI on 2026.11.18 by model claude fable 5.2, at Josh's request. -->

# The design file's screens

The Paper file "RainWatch: design for approval" (https://app.paper.design/file/01M7NBWW1V3TM4BBDNRMXEMP2F) holds every screen and every word RainWatch shows, in English and Dutch, and the App Store screenshots. Each watch screen is a capture of the app in the "Rain Ultra 3" simulator with RainWatch's own words left out, and those words laid over it as editable text in SF Compact, each text layer named by its key in `Sources/RainGraph/Localizable.xcstrings` ("value: …" for times and numbers). The text lands within a pixel or two of the real screen. When Josh edits a word in Paper, carry it into the catalogue (English keys change in the code too), rebuild, recapture and regenerate the screen, so Paper and the app stay the same.

To regenerate it:

1. Build for the simulator, then `NO_TEXT=1 design/capture.sh <udid>` and `NO_TEXT=1 SIM_LANGUAGE=nl design/capture.sh <udid>`: each state twice, with and without the words (`-hideText YES` draws no text of RainWatch's own, in the app and on the face).
2. `uv run --with pillow --with fonttools python design/paper/row.py '{"kind":"app","langs":["en","nl"],"states":[["dry","No rain","…"]]}'` prints one row of the file as HTML for Paper's `write_html`; `design/paper/gen_all.py` shows what it read on each screen. Fonts and sizes were fitted to the simulator (`calib.py`); Paper must be restarted after fonts are installed, as it lists a Mac's fonts only when it starts.
3. For the App Store page, `WORDLESS=/tmp/rainwatch-paper/wordless store/screenshots/make.py` also saves each screenshot without its captions, and `design/paper/store_html.py <locale> <n>` lays the captions over it.

- `capture.sh <simulator udid> [states]` saves the app and the face in each state in `captures/raw`, without a sound. It only launches the app with a debug option and takes screenshots, and it fails if any simulator process played anything. Build first: in `App/`, `xcodebuild -project Rain.xcodeproj -scheme Rain -destination 'generic/platform=watchOS Simulator' -derivedDataPath build build`.
- `SIM_LANGUAGE=nl design/capture.sh <simulator udid>` does the same in Dutch, into `captures/raw-nl`. The `radar` state serves the UI tests' copy of the server's files itself; give it a free port with `PORT=` when 8765 is taken.
- Apple's location question and the place search need taps, which make the simulator play sounds through the Mac. `App/test.sh` covers them and keeps a screenshot of each screen; run it where the sound bothers no one.
- `capture-store.sh <simulator udid>` makes the App Store screenshots' captures in `captures/store`: it replays the KNMI run saved in `captures/store/run` (a heavy shower over Friesland, 18 November 2026) from a local server, with its run time moved to ten minutes ago, so the app, the face and the radar show real data at the real clock; and it takes the live Apple Weather forecast for London. Run it on the Mac mini. `store/screenshots/make.py` then puts them in the frame with their headlines.
- `frame.py` rounds each screenshot's corners (`captures/screens`) and puts it in Apple's Ultra 3 frame (`captures/framed`). The frame, `captures/apple-ultra-3-frame.png`, is from Apple's design resources (Product Bezels), which its licence allows for mock-ups of watchOS apps.
- `captures/josh-watch-2026-11-17.png` is Josh's real watch face that evening, with the circle as it is on `main`.
- `listen.swift` measures what chosen processes play, with Core Audio process taps: `swiftc -O listen.swift -o listen && ./listen 60 CoreSimulator`.

The simulator's face is Modular Ultra with RainWatch in the large slot and the bottom middle circle. `testSetUpFaceWithoutLocation` sets the two slots once the face has been added from All Watch Faces.

Paper keeps the picture it was given, so give a changed screen a new file name before replacing it there.

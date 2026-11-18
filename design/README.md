<!-- Written by AI on 2026.11.18 by model claude fable 5.2, at Josh's request. -->

# The design file's screens

The Paper file "RainWatch: design for approval" (https://app.paper.design/file/01M7NBWW1V3TM4BBDNRMXEMP2F) is the design Josh approves before the app is changed to match it. Every watch in it is a screenshot of this branch's app in the "Rain Ultra 3" simulator; nothing is drawn.

- `capture.sh <simulator udid> [states]` saves the app and the face in each state in `captures/raw`, without a sound. It only launches the app with a debug option and takes screenshots, and it fails if any simulator process played anything. Build first: in `App/`, `xcodebuild -project Rain.xcodeproj -scheme Rain -destination 'generic/platform=watchOS Simulator' -derivedDataPath build build`.
- `SIM_LANGUAGE=nl design/capture.sh <simulator udid>` does the same in Dutch, into `captures/raw-nl`. The `radar` state serves the UI tests' copy of the server's files itself; give it a free port with `PORT=` when 8765 is taken.
- Apple's location question and the place search need taps, which make the simulator play sounds through the Mac. `App/test.sh` covers them and keeps a screenshot of each screen; run it where the sound bothers no one.
- `frame.py` rounds each screenshot's corners (`captures/screens`) and puts it in Apple's Ultra 3 frame (`captures/framed`). The frame, `captures/apple-ultra-3-frame.png`, is from Apple's design resources (Product Bezels), which its licence allows for mock-ups of watchOS apps.
- `captures/josh-watch-2026-11-17.png` is Josh's real watch face that evening, with the circle as it is on `main`.
- `listen.swift` measures what chosen processes play, with Core Audio process taps: `swiftc -O listen.swift -o listen && ./listen 60 CoreSimulator`.

The simulator's face is Modular Ultra with RainWatch in the large slot and the bottom middle circle. `testSetUpFaceWithoutLocation` sets the two slots once the face has been added from All Watch Faces.

Paper keeps the picture it was given, so give a changed screen a new file name before replacing it there.

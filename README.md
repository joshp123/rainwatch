<!-- Written by AI on 2026.11.13 by model claude opus 5.5. -->

# Rain on the watch: mock-ups

Buienradar's rain line for the next two hours on Apple Watch Ultra 3, in every widget family. What it must do, and why, is in [REQUIREMENTS.md](REQUIREMENTS.md).

- `renders/on-your-face.png`: the circular and rectangular widgets in Josh's own Modular Ultra face, at true size, for five real forecasts.
- `renders/families.png` and `renders/families-night-mode.png`: every family for seven real forecasts from 13 November 2026.
- `renders/circular-detail.png`: the circular gauge enlarged, in full colour and Night Mode.

## Run

```sh
swift run render-mockups renders research/josh-face-2026-11-05.jpeg
swift run copy-check
xcodebuild -scheme RainComplication -destination 'generic/platform=watchOS' build
```

The renderer draws the shared SwiftUI views on the Mac, in the watch's SF Compact Rounded. It draws corner text itself, because only the watch curves text for real. `Sources/RainComplication` is the WidgetKit code with `#Preview`s for every family; it compiles against the watchOS 27.2 SDK. `copy-check` prints the words for every forecast.

`research/` holds the evidence: the Buienradar user study, the wording survey, visual prior art, and the live Buienradar data the forecasts come from.

<!-- Written by AI on 2026.11.13 by model claude opus 5.5. -->

# Rain

A watch-only Apple Watch app with complications and a Smart Stack widget: Buienradar's rain for the next two hours where you are. What it must do, and why, is in [REQUIREMENTS.md](REQUIREMENTS.md).

## Parts

- `Sources/RainGraph`: everything the app and the widget share. `Buienradar.swift` fetches Buienradar's graph feed (RainNL3Hour, falling back to RainEU3Hour outside the Netherlands). `Place.swift` finds where you are. `Forecast.swift` turns the feed into a forecast for each minute. `RainCopy.swift` holds the words, and `RainViews.swift` the views.
- `App/Rain`: the watch app. It asks for location permission, shows the forecast, saves the place for the widget, and reloads the complications.
- `App/RainWidget`: the widget extension. One fetch gives an entry every minute for about 45 minutes, so the countdown stays exact between the system's reloads. If the widget cannot get its own fix, it uses the place the app saved.
- `App/project.yml`: the Xcode project spec. Regenerate `App/Rain.xcodeproj` after changing it.

## Build and run

```sh
cd App
nix run nixpkgs#xcodegen -- generate
xcodebuild -project Rain.xcodeproj -scheme Rain -destination 'platform=watchOS Simulator,name=Rain Ultra 3' -derivedDataPath build build
```

Install `build/Build/Products/Debug-watchsimulator/Rain.app` with `xcrun simctl install`, then set a location with `xcrun simctl location <device> set 51.92,4.48`. On watchOS the location permission has to be granted by tapping Allow in the app; `simctl privacy` does not reach it.

Device builds sign with team 7M8BR7R488 and automatic signing, with the app group `group.nl.jjp.rain`.

## Mock-ups

```sh
swift run render-mockups renders research/josh-face-2026-11-05.jpeg
swift run copy-check
```

The renderer draws the shared views on the Mac, in the watch's SF Compact Rounded; `renders/simulator/` has what watchOS itself drew. `copy-check` prints the words for every saved forecast. `research/` holds the evidence: the Buienradar user study, the wording survey, visual prior art, and the live Buienradar data the saved forecasts come from.

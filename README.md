<!-- Written by AI on 2026.11.13 by model claude opus 5.5. -->

# Rain

A watch-only Apple Watch app with complications and a Smart Stack widget: Buienradar's rain for the next two hours where you are. What it must do, and why, is in [REQUIREMENTS.md](REQUIREMENTS.md).

## Parts

- `Sources/RainGraph`: everything the app and the widget share. `Buienradar.swift` fetches Buienradar's graph feed (RainNL3Hour, falling back to RainEU3Hour outside the Netherlands). `Place.swift` finds where you are. `Forecast.swift` turns the feed into a forecast for each minute. `RainCopy.swift` holds the words, and `RainViews.swift` the views.
- `App/Rain`: the watch app. It asks for location permission, shows the forecast, and opens Buienradar's radar over Apple Maps from a toolbar button. Each time it opens it fetches, saves the forecast and place for the widget, and reloads the complications.
- `App/RainWidget`: the widget extension. Each reload fetches once, writes an entry for every minute until the forecast is 30 minutes old, then a stale entry; it asks to be reloaded after 15 minutes. If it cannot get its own fix, it uses the place last saved. Every reload is logged to `reloads.log` in the app group.
- `App/project.yml`: the Xcode project spec. Regenerate `App/Rain.xcodeproj` after changing it.

## Build and run

```sh
cd App
nix run nixpkgs#xcodegen -- generate
xcodebuild -project Rain.xcodeproj -scheme Rain -destination 'platform=watchOS Simulator,name=Rain Ultra 3' -derivedDataPath build build
```

Install `build/Build/Products/Debug-watchsimulator/Rain.app` with `xcrun simctl install`, then set a location with `xcrun simctl location <device> set 51.92,4.48`. On watchOS the location permission has to be granted by tapping Allow in the app; `simctl privacy` does not reach it.

Device builds sign with team 7M8BR7R488 and automatic signing, with the app group `group.nl.jjp.rain`.

To read the reload log from the real watch:

```sh
xcrun devicectl device copy from --device <watch> --domain-type appGroupDataContainer --domain-identifier group.nl.jjp.rain --source reloads.log --destination reloads.log
```

## Mock-ups

```sh
swift run render-mockups renders research/josh-face-2026-11-05.jpeg
swift run copy-check
```

The renderer draws the shared views on the Mac, in the watch's SF Compact Rounded; `renders/simulator/` has what watchOS itself drew. `copy-check` prints the words for every saved forecast. `research/` holds the evidence: the Buienradar user study, the wording survey, visual prior art, and the live Buienradar data the saved forecasts come from.

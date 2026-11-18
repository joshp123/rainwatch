<!-- Written by AI on 2026.11.13 by model claude opus 5.5. -->

# Rain

A watch-only Apple Watch app with complications and a Smart Stack widget: the rain for the next two hours where you are. In KNMI's area (the Netherlands, Belgium, Luxembourg, western Germany) it reads KNMI's forecast from our server (`server/`); everywhere else it asks Apple's WeatherKit. What it must do, and why, is in [REQUIREMENTS.md](REQUIREMENTS.md).

## Parts

- `Sources/RainGraph`: everything the app and the widget share. `KNMI.swift` reads the server's files: it works out the place's 1 km grid cell, reads `latest`, and fetches the cell's 32 km square with one range request (none when the square is dry), as `server/watch_client.py` does. `AppleWeather.swift` makes one WeatherKit call per refresh for the minute and hourly forecasts together. `Snapshot.swift` picks the source, keeps the forecast in the app group and dates it by when the data was made, never by when it was fetched. `Place.swift` finds where you are. `Forecast.swift` cuts the forecast into what is left from each minute. `RainCopy.swift` holds the words, and `RainViews.swift` the views.
- `App/Rain`: the watch app. It asks for location permission, shows the forecast with its source, and in KNMI's area opens the radar from a toolbar button: KNMI's frames, drawn on the watch from the squares under the map, over Apple Maps. Each time it opens it fetches, saves the forecast and place for the widget, and reloads the complications.
- `App/RainWidget`: the widget extension. Each reload fetches once (or reuses a forecast fetched under two minutes ago, or Apple's hourly forecast until it expires and at least an hour), writes an entry for every minute until the data is an hour old or runs out, then a stale entry; it asks to be reloaded after 15 minutes. If it cannot get its own fix, it uses the place last saved.
- `App/project.yml`: the Xcode project spec. Regenerate `App/Rain.xcodeproj` after changing it.

## Build and run

```sh
cd App
nix run nixpkgs#xcodegen -- generate
xcodebuild -project Rain.xcodeproj -scheme Rain -destination 'platform=watchOS Simulator,name=Rain Ultra 3' -derivedDataPath build build
```

Install `build/Build/Products/Debug-watchsimulator/Rain.app` with `xcrun simctl install`, then set a location with `xcrun simctl location <device> set 51.92,4.48`. Until `rain.jjpcodes.com` is live, debug builds read a local copy of the server's files: build one with `server/job.py`, serve it with range requests (`nix run nixpkgs#caddy -- file-server --listen 127.0.0.1:8765 --root <folder>`) and launch with `-server http://127.0.0.1:8765`. `App/test.sh` does this with the copy in `App/RainUITests/Server`. On watchOS the location permission has to be granted by tapping Allow in the app; `simctl privacy` does not reach it.

Device builds sign with team 7M8BR7R488 and automatic signing, with the app group `group.nl.jjp.rain` and WeatherKit. The watch app is `nl.jjp.rain.watchkitapp`. For the App Store, archive the `RainContainer` scheme for `generic/platform=iOS`: App Store Connect only takes a watch-only app inside an iPhone app, `nl.jjp.rain`, that never runs.

## The event log

`Sources/RainGraph/Log.swift` records every key event of the app and the widget: launch, each change of what is on screen, the location permission and each fix with its age, each request with its HTTP status, size and time, forecasts reused, failures, and each widget timeline. Every build sends them to the system log and to signposts under the subsystem `nl.jjp.rain`, so Console and Instruments show them. No message holds a position or a place name.

Debug builds also keep the last events (about 200 KB) in the app group. To read them from the real watch, which must be awake:

```sh
xcrun devicectl device copy from --device <watch> --domain-type appGroupDataContainer --domain-identifier group.nl.jjp.rain --source Library/events.log --destination events.log
```

## Mock-ups

```sh
swift run render-mockups renders research/josh-face-2026-11-05.jpeg
swift run copy-check
```

The renderer draws the shared views on the Mac, in the watch's SF Compact Rounded; `renders/simulator/` has what watchOS itself drew. `copy-check` prints the words for every saved forecast (`Scenarios.swift`: real KNMI forecasts from the run of 16 November 2026 00:35 UTC, and two made-up test forecasts in the shape of Apple's answers, `-scenario ukNextHour` and `-scenario spainHourly`, for Apple's screens without calling WeatherKit). `research/` holds the evidence: the Buienradar user study, the wording survey, visual prior art, and the data sources.

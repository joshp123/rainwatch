<!-- Written by AI on 2026.11.18 by model claude fable 5.2, at Josh's request; updated 2026.11.18 by model claude opus 5.5 for the App Review fixes, and for Location Expired and the way to turn location on. -->

# What RainWatch shows, and when

RainWatch shows one of two things: a forecast, or the reason there is none. One function decides which, for the app and for the watch face: `Situation.after` in `Sources/RainGraph/Situation.swift`. The words for every reason are in `Problem`, in the same file, and the words for a forecast are in `RainCopy`. Nothing else in the app chooses words. `Tests/RainGraphTests` checks the rules below (`swift test`, on the Mac, no simulator).

## What decides it

Three facts, each with a few values.

**The place.** `Place.current` gives one of:

| Place | When |
|---|---|
| A picked place | The wearer chose a town or postcode. It stays until they change it. |
| Where you are | Location is allowed and the watch has a fix under an hour old. |
| Not set | Location was never answered. |
| Expired | Location was allowed, and watchOS will ask again: Allow Once has run out, or Ask Next Time was chosen in Settings. watchOS reports this as never answered, so RainWatch keeps a flag that location was allowed (`Place.wasAllowed`). The last fix is forgotten, never used again. |
| Off | Location is refused or turned off, and no place is picked. |
| Not found | Location is allowed, but there has been no fix for an hour. |

**The forecast for that place.** A fetch ends in one of three ways (`Situation.Fetch`): fetched, unreachable (the server or the network), or refused (Apple has no forecast there). The source is KNMI in its area and Apple Weather outside it; Apple's is a minute forecast for one hour, or hourly where it has no minute forecast.

**Its age**, counted from when the forecast was made (KNMI's radar time, Apple's forecast time), never from when the watch fetched it:

| Age | Shown as |
|---|---|
| Under 20 minutes | The forecast, with what comes next on the second line. |
| 20 to 60 minutes | The forecast, with "Forecast made 23:40" on the second line. |
| 60 minutes or more (120 for Apple's hourly) | No forecast: "No recent forecast", with its time. |

An Apple forecast is deleted from the watch once it reaches that age: Apple's terms let its data be kept only for a while (Attachment 8, 1.6). A KNMI forecast is kept, to say when the last one was made.

## The rules

1. A problem with the place comes first. Without a place there is no forecast on screen, whatever is saved.
2. A forecast is only ever shown for the place it was made for: within 1.5 km.
3. A forecast is never counted down from once it is an hour old.
4. A countdown is always from now. A saved forecast is cut to the present moment before it is shown.
5. A saved forecast stands in for a failed fetch only under rules 2 and 3, and the app then says "Couldn't update".
6. No forecast is never shown as dry.
7. The app and the face name a problem with the same words: the face's first line is the app's title.
8. A fix is trusted for an hour, and not at all once Allow Once has run out. A picked place does not expire.
9. Every location problem says how to fix it: Location Expired asks again, Location Off spells out the way to it in Settings (watchOS lets no app open Settings), and Location Off also offers a place by name. Location Expired has only Continue: Apple wants one button before its question.

## Every state

| State | Face circle | Face, large slot | App |
|---|---|---|---|
| Forecast, no rain in it | Dry, 1+ HRS | Dry for over an hour | The same headline, no graph scale, black page |
| Forecast, dry now, rain coming | IN 36 MIN | Dry for 36 min | Headline, then "Drizzle 00:50–01:20" in blue |
| Forecast, raining, stops within the hour | FOR 10 MIN | Rain stops in 10 min | Headline, then "Dry 00:25–01:20" in grey |
| Forecast, raining for an hour or more | FOR 1+ HRS | Rain until 01:25 | Headline, then "Heaviest around 00:25" |
| Forecast, 20 to 60 minutes old | as above | Headline, then "Forecast made 23:40" (Apple's: " Weather, made 23:40") | The same two lines ("Hourly forecast made 23:40" for Apple's hourly); "Source: KNMI" or Apple's mark under the graph |
| Forecast, last fetch failed | as above | as above | Second line "Couldn't update"; "KNMI forecast made 00:05" under the graph; Try Again |
| Location not set | No PLACE | Location not set / Tap to set up | The first-launch screen: one sentence, Continue |
| Location expired | No PLACE | Location expired / Tap to allow again | Location Expired / "To keep your watch face up to date, choose Allow While Using App." / Continue, which opens the system's question again |
| Location off | No PLACE | Location off / Tap to fix | Location Off / the way to it in Settings (watchOS lets no app open Settings) / Choose a Place |
| Location not found | No PLACE | Location not found / Tap to try again | Location Not Found / Try Again, Choose a Place |
| Forecast unavailable | No DATA | Forecast unavailable / Tap to try again | Forecast Unavailable / Try Again |
| No forecast here | No DATA | No forecast here / Tap to try again | No Forecast Here / Try Again, Choose a Place |
| No recent forecast | No DATA | No recent forecast / Last forecast 23:00 | No Recent Forecast / Last forecast 23:00 / Try Again |

Blue means rain: the line, the arc, and words about rain. The circle's words count to the rain ("IN 36 MIN" until it starts, "FOR 10 MIN" while it lasts), so they are blue whenever rain is forecast. White is the answer (the number, the headline, the dot). Grey is everything else. The white dot is the moment the weather changes: when rain starts, or when it stops. The number counts down to it.

Height means how hard it rains, on one scale in the circle, the large slot and the app's graph (`RainCurve.display`): rain in mm/h, a little compressed, full height at Buienradar's Heavy line (11.3 mm/h). Drizzle is a thin band, light rain a fifth of the height and moderate rain half, so a burst of heavy rain stands clear of the light rain round it.

## What moves it from one state to another

| From | Event | To |
|---|---|---|
| Loading (the app, with no saved forecast under an hour old) | A fix under an hour old is at hand | Forecast for that place, after a fetch; then for the new fix too, if it is over 1.5 km away |
| Location not set | Continue, then Allow While Using App or Allow Once | Forecast (after a fetch) |
| Location not set | Continue, then Don't Allow | Location off |
| Location expired | Continue, then Allow While Using App or Allow Once | Forecast (after a fetch) |
| Location expired | Continue, then Don't Allow | Location off |
| Location off | Location turned on in Settings, then back to the app | Forecast (the app refreshes as it comes to the front) |
| Location off, not found, or no forecast here | Choose a Place, pick one | Forecast for that place |
| A picked place | Change Place, Use My Location | Whatever the location answer gives |
| Forecast | Location turned off in Settings | Location off: in the app when it is next opened, on the face at its next reload |
| Forecast for where you are | An hour with no new fix | Location not found |
| Forecast for where you are | Allow Once runs out | Location expired: in the app when it is next opened, on the face at its next reload |
| Forecast | 20 minutes with no newer forecast | Forecast, 20 to 60 minutes old |
| Forecast, any age | A newer forecast is fetched | Forecast, under 20 minutes old |
| Forecast | The fetch fails; saved forecast is for here and under an hour old | Forecast, last fetch failed |
| Forecast | The fetch fails after moving more than 1.5 km | Forecast unavailable |
| Forecast, last fetch failed | Try Again works | Forecast |
| Forecast | It reaches an hour old | No recent forecast |
| Forecast | The watch moves out of KNMI's area | Forecast from Apple Weather, or No forecast here |

The app decides when it is opened, on Try Again and when a place is picked. The face decides at each reload (watchOS allows one about every 15 to 20 minutes) and lays out the minutes until then in advance, so a forecast turns old, and a fix expires, on time even when a reload is late (`Situation.schedule`).

Opening the app, Try Again and picking a place can each start a refresh while another is running. Only the newest may write to the screen (`refreshes` in `ContentView`).

## States the code could reach that broke these rules

Found by reading every path that writes the screen or the face's timeline, 17 and 18 November 2026. All are fixed on this branch.

| Broken rule | How it was reached | Evidence, on `main` | Fix | Test |
|---|---|---|---|---|
| 4: countdown from now | Open the app; open it again later with no connection. The headline still counted from the first look, so "Dry for 39 min" could be 15 minutes wrong. | `fail()` in `RainApp.swift` kept `load = .ready(forecast…)` untouched; `RainForecast.now` is fixed when the forecast is cut | `Situation.after` cuts the saved forecast to now | `aFailedUpdateCountsDownFromNow` |
| 3: nothing over an hour old | The same path, an hour later: the app kept the old forecast with "Couldn't update" for ever | the same `fail()` | `Situation.after` returns No recent forecast | `anHourOldForecastIsNotCountedDownFrom` |
| 2: only for its own place | Travel, then a fetch fails: the app and the face showed the forecast for the place left behind | `fail()`; `timeline(cached: Snapshot.saved…)` in `RainWidget.swift` took the saved forecast without checking its place | `Situation.after` checks the place | `aSavedForecastForAnotherPlaceIsNotShown`, `aSavedForecastForNearbyStillStandsIn` |
| 1: place first | Location allowed but no fix for an hour: the app kept the forecast with "Couldn't update" while the face said there was no place | `fail(.noLocation)` with a forecast on screen only set `couldNotUpdate` | A place problem always replaces the forecast (`refresh()`) | none: needs Core Location |
| 8: a fix lasts an hour | After Allow Once the face used the last fix for ever (since 18 November it uses none once Allow Once has run out) | `Place.current` returned `saved` at any age when permission was not determined | `Place.trustFor`, and `Situation.schedule` ends the timeline at the hour | `theFaceGivesUpAPlaceAnHourAfterItsFix` |
| 2, by a race | Pick a place while a refresh for your location is still running: whichever finished last won, so the app could show your location's forecast under the picked place | three call sites start `Task { await refresh() }` with nothing to order them | `refreshes` counter: an overtaken refresh writes nothing | none: read from the code, not reproduced; a test needs the simulator |
| 7: same words | The face said "No forecast / Open RainWatch to try again" where the app said "No Connection", and "Location needed" where the app said either of two things | separate strings in `problemText` and `failed()` | one `Problem` for both | `theFaceAndTheAppNameAProblemAlike` |

## What the log showed on Josh's watch

Every change of the app's screen is logged as "screen: A -> B (why)", and every widget timeline as the states it moves through (`Log.swift`; AGENTS.md says how to copy the log off the watch). On 18 November 2026 the log from his watch showed every transition in the table above and two states that are not in it. Both are fixed.

| What the log showed | Why | Fix |
|---|---|---|
| The app on "loading" for two minutes with no refresh running | The first refresh started only when the scene turned active, and after a launch with the screen off it never did | The first refresh starts with the app |
| The widgets asked to reload twice within a second, for a forecast they already had | Coming to the front started a second refresh as the first ended, and every refresh asked for a reload | A refresh that just ended is not repeated, and the widgets are asked to reload only for a forecast newly fetched |

Checked on the watchOS 27.2 simulator, 18 November 2026:

- **The face follows a permission changed in Settings by itself.** After Don't Allow the face said Location off; once location was allowed again, the widget's next reload (10 minutes later) read the new permission itself, cleared `Place.isRefused` and showed the forecast, without the app being opened.
- **Allow Once lasts as long as RainWatch is in use.** With RainWatch on the face it lasted over 35 minutes (every widget reload counts as use) and ended when the watch restarted; the app then showed its question again. watchOS reports an ended Allow Once as never answered, so RainWatch keeps `Place.wasAllowed` to say Location Expired instead of showing the first launch.
- **The way to turn location on.** Settings > Privacy & Security > Location Services lists RainWatch once location has been refused (not during Allow Once), with Never, Ask or When I Share and While Using the App; in Dutch Instellingen > Privacy en beveiliging > Locatievoorzieningen > BuienWatch > Bij gebruik van app. On the simulator, which has no paired iPhone, the three options were greyed out; Privacy & Security says some settings are shared with the iPhone. Not yet checked on a real watch.

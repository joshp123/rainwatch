Written by AI on 2026.11.13 by model gpt-6-luna.

# Radar time on Apple Watch: prior art

## Findings

### Buienradar (RTL / DPG Media, `nl.rtl.buienradar`)

Correction by Claude Opus 5.5, 2026.11.13: the claims this section first made came from "Buienradar Live Nederland" (id1041249132), a different app by Vorinn, not from Buienradar. They are moved to their own section below.

- **Watch app exists, three screens:** "de buienradar met verloop van de buien over het land" (the radar with the showers' course over the country), a rain graph showing when rain falls, and an info screen for the coming hour (temperature, mm of rain, wind, gusts). It has complications that open the last screen viewed. **Stated in text** ([iCulture, 12 July 2022](https://www.iculture.nl/nieuws/buienradar-terug-apple-watch); [iCulture guide, 2024](https://www.iculture.nl/gids/apple-watch-weerapps-complicaties)).
- **Time control:** no source says whether the watch radar plays by itself or steps with the Digital Crown. Josh has the app on his iPhone, so the way to settle it is to open it on his watch.

### Buienradar Live Nederland (Vorinn, not Buienradar)

- **Watch radar:** "Apple Watch-app met de radar over uw gekozen locatie - Draai aan de Digital Crown om beeld voor beeld door de lus te gaan" (turn the Digital Crown to go through the loop frame by frame). **Stated in text** ([Dutch App Store listing](https://apps.apple.com/nl/app/buienradar-live-nederland/id1041249132?platform=watch)).
- **Extent:** radar forecast to 45 minutes ahead; history of 1, 1.5 or 2 hours. On iPhone the loop can be dragged by hand or left to run, "met een tijdstempel op elk beeld" (with a timestamp on every frame). **Stated in text**, same listing.

### Buienalarm

- Its Dutch App Store page confirms a Watch app and describes the iPhone radar as animated, but does not describe Watch radar, Crown time control, or a time range. **Stated in text** ([Dutch App Store listing](https://apps.apple.com/nl/app/buienalarm-weer-regenradar/id598509141?platform=watch)).
- iCulture says its Watch app gives an at-a-glance indication of whether rain is expected. It does not claim a radar map or time scrubbing. **Stated in text** ([iCulture guide](https://www.iculture.nl/gids/beste-nederlandse-apple-watch-apps/)).
- I found no evidence of Watch radar playback, timeline, or a rain graph.

### Other Watch apps

- **RainViewer:** its App Store release notes describe a Watch radar complication with up to three forecast frames labelled “+N min”, plus an hourly forecast list for 12 hours (24 with Premium). This supports a compact forecast-in-time glance, not a Watch map player. **Stated in text** ([App Store, Watch listing](https://apps.apple.com/us/app/rainviewer-live-weather-radar/id980123924?platform=watch)).
- **Rain Alarm:** its App Store listing advertises a Watch app. A Watch screenshot shows a radar map and a location label, but the still image does not establish animation or time scrubbing. **Seen in screenshot** ([App Store](https://apps.apple.com/nl/app/rain-alarm-neerslagradar/id397676100?platform=watch)); local screenshot: [rainalarm-appstore-watch-chicago.png](/Users/josh/code/buienradar-apple-watch/research/prior-art/rainalarm-appstore-watch-chicago.png). I inspected this image. No time control or frame timestamp is visible.
- **CARROT Weather:** its listing says paid tiers include weather maps with next-hour radar, but the materials found do not establish a Watch radar player or its time controls. **Stated in text** ([App Store](https://apps.apple.com/us/app/carrot-weather-alerts-radar/id961390574?platform=watch)).
- **Weathergraph:** existing App Store Watch screenshots show forecast information and watch-face complications, not a radar timeline. **Seen in screenshot**: [weathergraph-appstore-watch-ultra-06.png](/Users/josh/code/buienradar-apple-watch/research/prior-art/weathergraph-appstore-watch-ultra-06.png), inspected. I found no source describing a Watch radar player.
- **MyRadar:** a user comparing apps reported its Watch radar was a still image that refreshed when reloaded. This is a user report, not an official specification. **Stated in text** ([Reddit discussion](https://www.reddit.com/r/AppleWatch/comments/u9gupx/best_way_to_get_animated_weather_radar_on_apple/)).
- **RainViewer’s iPhone player** has past/forecast interval and animation-speed options, but this is phone behaviour and should not be assumed on Watch. **Stated in text** ([App Store listing](https://apps.apple.com/us/app/rainviewer-live-weather-radar/id980123924?platform=watch)).
- **Apple Weather:** the Watch app presents hourly precipitation information, not a precipitation map with a time scrubber in the sources reviewed. Apple’s user guide describes tapping precipitation to see its forecast; it does not describe a radar map. **Stated in text** ([Apple Watch User Guide](https://support.apple.com/guide/watch/check-the-weather-apd9bf3c1c7f/watchos)). Existing Apple Watch screenshots show forecast/conditions, not radar: [apple-weather-watch-appstore-1.png](/Users/josh/code/buienradar-apple-watch/research/prior-art/apple-weather-watch-appstore-1.png), inspected.
- **Rain Radar Live (Yanbu Weather):** the Dutch App Store listing claims an animated Watch radar loop scrubbed with the Digital Crown. It does not specify the time span, frame labels, or accompanying rain graph. **Stated in text** ([App Store, Netherlands](https://apps.apple.com/be/app/rain-radar-live-weather-map/id992351930?platform=watch)).
- **PocketRadar:** its listing says the Watch app has animated radar and “smoother radar playback and interaction”; it does not detail time labels or Crown behaviour. **Stated in text** ([App Store](https://apps.apple.com/us/app/pocketradar-rain-radar-maps/id574399713?platform=watch)).
- **Weer - Regenradar met KNMI:** its current App Store notes say the Watch radar can be tapped to enlarge, zoomed with the Crown, and moved forwards or backwards in time with the Crown. No range or exact timestamp style is specified. **Stated in text** ([Dutch App Store listing](https://apps.apple.com/nl/app/weer-regenradar-met-knmi/id6745883312?platform=watch)).

### Apple’s interaction guidance

- Apple says the Crown can operate standard or custom controls and can help people inspect data. It cites World Clock as an example where turning the Crown advances the time at a selected location. This supports Crown-controlled time inspection as a familiar system pattern. **Stated in text** ([Digital Crown HIG](https://developer.apple.com/design/human-interface-guidelines/digital-crown)).
- Apple’s current guidance also identifies Crown scrolling for lists and vertically paginated tabs. It does not prescribe a radar scrubber design or say a loop should auto-play. **Stated in text** ([Digital Crown HIG](https://developer.apple.com/design/human-interface-guidelines/digital-crown)).
- Older watchOS Time Travel let users turn the Crown on the watch face to see future and past complication data. Apple removed it in watchOS 5. **Stated in text** ([Apple Support: watchOS 5 changes](https://support.apple.com/en-us/HT208944)). It is historical context, not a current in-app control recommendation.

## Design evidence

The strongest direct precedent is Buienradar Live Nederland (Vorinn, not Buienradar): a Crown-driven frame sequence, with a forecast extending 45 minutes and history extending 2 hours. The source does not document playback on Watch or how it labels each frame. Another contemporary app listing, Rain Radar Live, explicitly pairs an animated loop with Crown scrubbing. Apple’s guidance makes the Crown a reasonable input for inspecting time-dependent data.

For Rain, a single snapshot hides the forecast’s useful information. A Crown-stepped sequence should expose the selected moment in text, since the Buienradar listing does not prove the watch UI’s timestamp treatment. A small persistent time label such as “Now”, “In 15 min” or “20 min ago” would make the selected frame legible; this is a design inference, not a claim about Buienradar’s UI. A visible progress track could make loop position clearer, but I found no evidence that a competing Watch app uses one.

## Screenshots saved and inspected

The requested `research/prior-art/` folder already contains relevant screenshots for Rain Alarm, CARROT, Weathergraph and Apple Weather. I inspected the Rain Alarm, CARROT and Apple Weather images listed above, plus the Weathergraph image. I found no Buienradar or Buienalarm Watch screenshot that demonstrates their current time interaction, so I did not add an unverified image. No app was installed or run.

## What I could not find

I could not verify Buienradar’s actual Watch screen, whether its Watch loop auto-plays, its frame interval, exact timestamp or scrubber treatment, or whether it includes the rain graph. I could not find equivalent implementation detail for Buienalarm, CARROT, or most other apps from public text and screenshots. App Store claims and release notes are not hands-on verification. I could not save new screenshots from the listings in this research pass.

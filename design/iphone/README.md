<!-- Written by AI on 2026.11.18 by model claude fable 5.2, at Josh's request. A proposal: Josh has not approved it. -->

# RainWatch for iPhone: the design proposal

Nothing here is the app. It is a proposal Josh can look at in Paper (the page "iPhone · proposal" in the file "RainWatch: design for approval") and use on his own iPhone, as a web page with real KNMI data.

## The idea

The watch answers "when does the rain change?" in a glance. The phone answers the same question in the same words, and has room to show why: **one screen, with the sentence and the two-hour line at the top and the map under them, and the line is the map's timeline.** A thin white line on the graph marks the moment the map shows. It runs along the graph by itself, once, when the app opens, so the shower reaches the yellow dot on the map as the white line reaches the rise in the graph. Then the map goes back to now and waits. A finger anywhere on the graph moves the moment.

On the watch the forecast and the radar had to be two pages. On the phone they are one, so the app has no tabs and no second screen for the forecast.

## What the phone shows

In this order, because this is the order of the questions in REQUIREMENTS.md:

1. The place: the town, with Apple's location arrow when it is where you are. A tap changes the place.
2. The headline, in the watch's words: "Dry for 17 min", "Rain stops in 27 min".
3. What comes next, with clock times: "Rain 22:10–23:05". Blue when it is about rain. Once the forecast is 20 minutes old this line says "Forecast made 21:15" instead, as on the watch.
4. The two hours as the watch's line: height is how hard, on the same scale, with the Light and Heavy lines. The white dot is the moment the headline counts to. Past where the forecast reaches, the baseline is dotted. With no rain there is no scale.
5. Whose forecast it is and when it was made: "KNMI forecast made 21:40".
6. The map, with KNMI's rain drawn as on the watch, your place as the yellow dot, a play button, the moment the map shows ("Now", "in 20 min") and a zoom button. It opens 60 km across when rain is due where you are and 180 km across when it is not (rain that could arrive within two hours is inside that).

Without opening the app: the Lock Screen's three slots (the line above the clock, the wide slot, the circle), a small and a medium widget for the Home Screen, and StandBy, which uses the small one. They say the watch face's words. The Lock Screen has no colour, so there the rain is the only thing drawn above the baseline.

## What it leaves out, and why

- **Temperature, wind, tomorrow, weather warnings.** It is a rain app, and the forecast reaches two hours.
- **Tabs, a settings screen, a list of saved places.** One place at a time, changed from the title, as on the watch.
- **Millimetres and percentages.** As on the watch: words and height.
- **A legend for the map's colours.** The graph beside it already has Light and Heavy; the map is read as "where the rain is".
- **The headline following the finger.** The headline is the answer for now and never changes while the map moves; the map's own label says which moment it shows.
- **Panning the map.** It zooms about your place. The question is always about here.
- **Notifications and Live Activities.** Not in this proposal.
- **The watch's circle in the app.** It says what the headline says; it stays where there is no room for a sentence.

## Outside KNMI's area

Apple Weather has no radar, so there is no map: the screen is the sentence, the line (taller) and Apple's mark. The lower half of the screen is empty. That is the weakest screen in the proposal.

## What was checked, and what it changed

- The screen was used in a browser with today's live forecast and with a saved KNMI run of a heavy shower (dry then rain, raining now, rain in 50 minutes, no rain, a forecast 35 minutes old), in English and Dutch, dark and light, at iPhone size with touch.
- A fresh reader who knew only "an iPhone app used in the Netherlands" was shown stills and asked what each thing meant and what each tap would do. It read the place, headline, second line, graph, map, play button and widgets correctly. What it got wrong or doubted changed the design: the white line resting on "now" read as the graph's own axis (it is now hidden until the map moves); the fake clock in the pictures made "Dry for 17 min" and "Rain 21:55" look inconsistent (the pictures now show the real time); a tick floated past the end of the baseline (the unknown end is now dotted); the Location Off line on the Lock Screen had the rain-drop glyph (now Apple's location glyph with a stroke through it).
- Three other layouts were built and dropped: map first with the forecast in a card; the line alone with the radar on its own page; the watch's circle, large. They are in the prototype's menu and on the Paper page.
- The map 30 km across, the watch's close view, showed each 1 km cell as a block on a phone, where a kilometre is drawn twice as large. So the phone's close view is 60 km, and cells are always blended.

Not checked: a real iPhone in a hand, a person who has never seen it, VoiceOver, larger text sizes, and the widgets in iOS itself (they are drawn here, not built; `iphone-proposal` on the engineering branch shows the watch's widget code running on a Lock Screen).

## Open

- Whether the map should play once when the app opens (proposed), keep playing as the watch's radar does, or wait until asked. All three are in the prototype's menu.
- On a light map, heavier rain is a deeper blue; on a dark map it is brighter, towards white, as on the watch. Both keep red for downpours.
- The blended cells make a shower's edge soft. Near the edge the map can look wet where the line says dry.
- The medium widget is the only one with room for the second line. Whether it earns a place beside the small one is Josh's call.

## Run it

```sh
python3 design/iphone/serve.py 8793      # then open http://<this Mac's Tailscale name>:8793/ on the iPhone
```

The "i" button opens the prototype's own menu: live or saved forecast, language, light or dark, how the map starts, and the dropped layouts. `widgets.html` is the bench the widgets were drawn on.

- `index.html`, `style.css`, `app.js`: the screen. `draw.js`: the line and the circle at any size. `radar.js`: KNMI's cells under a map, painted as `App/Rain/RadarPage.swift` paints them. The forecast, its words and its rules come from `site/rain.js`.
- `serve.py`: serves the page, passes `latest` and `runs/*` through from the live server, serves the saved run in `design/captures/store/run` with its time moved to now, and makes Apple's map for a region with `snap.swift` (MapKit on this Mac). The map pictures are Apple's: they are kept in `/tmp` and not committed.
- `paper/`: `all.sh` turns every screen into HTML for Paper's `write_html`, with the words as editable text and the drawings as one picture per screen, in `/tmp/rainwatch-iphone-paper`. Paper keeps a picture by its file name, so run it with a new `V=` when the pictures change.

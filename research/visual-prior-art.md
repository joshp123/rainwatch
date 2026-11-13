# Visual prior art: circular complication and Smart Stack widget for a rain line

Written by AI on 2026.11.13 by model claude sonnet 5.5 (research sub-agent). Images are in `prior-art/` next to this file.

Labels: **[V]** I looked at the saved image myself. **[T]** taken from text (Apple's alt text, docs, transcript), not from an image I saw. **[I]** my inference. Sizes in points (pt) unless stated. Screenshot measurements are eyeballed, so treat them as roughly right.

## Short answer

1. Apple's circular complications on Josh's face carry at most three things: one glyph or small label, one big value, one arc. Apple's own gauge is a 240° open arc (8 o'clock to 4 o'clock over the top), a stroke about 10 to 13% of the diameter, a round-capped colour gradient, a dot for "now", and min/max or an icon in the bottom gap. [V, plus HIG alt text T]
2. Apple's only "value over time" precedent at this size is the Weather app: a row of about 12 rounded capsule bars, height = intensity, labelled only "Now" and "60m", under a one-line verdict. [V] No third-party app I found draws a real time series inside a circular slot. They all use a single-value gauge in the circle and put the graph in the rectangular slot or Smart Stack. [V, plus T]
3. My first circular mock-up broke Apple's idiom. It had a dome-shaped line crowded onto a ring, text overlapping the ring, and a tiny "RAIN" label of about 5 pt. [V]
4. Four circular concepts below keep "height = intensity, position = time". I would prototype the variable-width gauge (concept 4) and the radial-bar arc (concept 1) first.

## 1. Apple's own circular complications

| Saved image | Source | What it shows and why it works or fails at 45 to 50 pt |
|---|---|---|
| `../josh-face-2026-11-05.jpeg`, `../josh-face-2026-09-28.jpeg` | Josh's own screenshots [V] | Modular Ultra, six circles. Weather temperature gauge (top left): about 240° arc, thick gradient stroke (green, yellow, orange, red), round caps, a small dot at the current value, centre value in a bold rounded face, min/max in tiny orange and red text under the arc ends (21 and 36). Sleep: icon on top, "8H 12M" in two lines with small-cap units. Date: red "THU" over a large "5". Sunrise: orange glyph over a time. World Clock: time over an orange city code. Every circle has one glyph or label, one value, and at most one arc. None has more than three elements. This is the density to match. The unit letters are tiny but only ever trail a number, so they cost nothing. |
| `apple-support-infograph-face.png` | https://support.apple.com/guide/watch/faces-and-features-apde9218b440/watchos (Apple asset `783e4a4f-e95a-4424-aceb-19df58069248`) [V] | Infograph corner gauge: curved bar from green "56" to red "88" with a dot marking now and "83°" in large type. The range numbers sit at the track ends, coloured to match the track. Reads well because the track is a thick, uninterrupted gradient with a single dot. |
| `apple-support-modular-ultra-face.png` | same page, asset `390792d7-a314-46d6-a677-4357ba4b9575` [V] | Modular Ultra with Training bezel. The bottom-right circle is a rainbow ring (a "4" with a small sun glyph in the bottom gap, label "STEADY" outside). The Readiness widget (large) uses a half-circle arc with a dot. Shows how the gap at the bottom is where Apple parks the small glyph. |
| `apple-wwdc23-10309-combo-widget-circular-weather-set.png` | WWDC23 session 10309 at about 6:24, frame from https://developer.apple.com/videos/play/wwdc2023/10309 [V] | Apple's own example of three circular weather complications as a set: "72" with 53 and 79 range, "5" with a sun glyph, "30" with "AQI". All three: number in the middle, thin-ish gradient open arc, label or range in the gap. The transcript says circular complications are "great ... when the complications in it provide rich data, and better yet when all three ... work together as a set". |
| `apple-weather-watch-appstore-1.png` | Apple Weather listing, https://apps.apple.com/us/app/id1069513131 [V] | Apple Weather UV and humidity gauges at the app's scale. Open arc with a faint full track, a dot at the start, the value filling toward the end, glyph in the gap. The unfilled track stays visible, which tells you the maximum without a number. |
| `9to5mac-watchos10-weather-1.jpg` | https://9to5mac.com/2023/09/26/new-apple-watch-weather-app-watchos-10-how-it-works [V] | Same Weather gauges on a real Ultra (UV "1", AQI "40", a compass-style wind dial in the middle). Shows the gauges at true Ultra scale: about 85 of 410 screenshot pixels wide, so the arcs are plainly visible but the glyph in the gap is only just readable. The middle screen is the Apple hourly dial: 12 o'clock positions with a condition icon per hour. That is Apple's own use of a circle as a time axis. |
| `apple-support-weather-app-hourly.png` | https://support.apple.com/guide/watch/weather-apd07ec24f9e/watchos [V] | The hourly dial with 12 hour numbers around a ring and icons in each slot. Readable only because it fills the whole screen. At 50 pt the same idea would be unreadable if every slot carried an icon. |
| `apple-weather-watch-appstore-4.png` | Apple Weather listing [V] | The hourly temperature dial as a filled colour band with numbers on it. Apple draws the time axis clockwise from 12 o'clock for a 12-hour span. |
| `apple-weather-watch-appstore-2.png` | Apple Weather listing [V] | **The key precedent.** "Severe Weather" card with a next-hour rain chart: 12 vertical capsule bars (5 minutes each), rounded ends, cyan-to-blue gradient, height = intensity, hairline vertical dividers behind them, and only two labels: "Now" under the left bar and "60m" under the right bar. No y-axis, no mm. The caption does the words, the bars do the shape. |
| `apple-support-smart-stack-live-activities-widgets.png` | https://support.apple.com/guide/watch/see-widgets-in-the-smart-stack-apdecf142fb9/27/watchos/27 [V] | watchOS 27 Smart Stack: a Live Activity card showing a big coloured headline ("Workout", "06:29") over a translucent card. Shows that Apple widgets lead with a coloured word or number, not a chart. |

HIG circular details [T], from https://developer.apple.com/design/human-interface-guidelines/complications (I could not download the HIG gauge illustrations, they return 404 from the CDN path, so I used the HIG text and alt text):

- Regular circular image size: 50 x 50 pt on 45mm and 49mm. Closed gauge image: 32 x 32 pt. Open gauge image: 13 x 13 pt (the glyph in the gap). Stack (two-line text): 33.5 x 16.5 pt.
- Default text in a SwiftUI circular complication: rounded, medium weight, 14.5 pt on 45mm and 49mm.
- The open gauge "begins at about the 8:00 position and ends at about the 4:00 position". The "range" layout puts the current value in the centre and min and max side by side at about 6:00, coloured to match the gauge ends. The "simple text" layout puts a three-letter label ("AQI") at 6:00.
- Gauge styles: closed for a percentage of a whole, open for an arbitrary range, segmented for rapid change (the Noise complication).
- Tinted mode: system desaturates, then tints text, gauges and images with one colour. "Avoid using color as the only way to communicate important information."
- Line widths: "generally use line widths of two points or greater".

Not found: Apple's own Noise, Heart Rate, Moon, Tides, Sunrise and Weather Precipitation circular complications as images. Apple's pages render them via JavaScript or only at Apple Watch Ultra marketing resolution that I could not reach. I did not guess at their details.

## 2. Third-party circular complications and rain

| Saved image | Source | What it shows and why it works or fails |
|---|---|---|
| `weathergraph-appstore-watch-ultra-01.png` | https://apps.apple.com/us/app/id1501958576 [V] | Modular Ultra with Weathergraph: three circles in the bottom row. UV "5" in a rainbow ring, humidity "57%" in a cyan ring, and **"0MM" with an umbrella glyph in the bottom gap inside a solid blue ring**. The rain complication is a value, not a time series. Reads well: 3 elements, big number, glyph in the gap. Reads badly for Josh's question: "0MM" is a total, so it does not say when. |
| `weathergraph-appstore-watch-ultra-02.png` | same listing [V] | Same face on another day. The top circle is Apple-style: "18°" with "9" and "20" range under the arc ends in matching colours. Shows a third party copying Apple's gauge anatomy exactly. |
| `weathergraph-appstore-watch-ultra-08.png` | same listing [V] | Modular Ultra with a large Weathergraph temperature graph (magenta line). The large slot carries the time series, the circles carry values. |
| `weathergraph-watch-full-01.png` | https://weathergraph.app/presskit/images/watch-full-01-1188x1452.png [V] | Press kit crop: a gauge with a dot "28°", a wind complication, and a wide rain/temperature graph with a dense field of thin coloured vertical lines (one per few minutes) and rain shown as blue capsules along the baseline. At the wide size, thin lines work. Blue capsules on a dark baseline are visible but small (about 2 pt tall). |
| `weathergraph-appstore-watch-ultra-06.png` | same listing [V] | In-app screen: a one-line verdict "Rain until 18:50" in bold blue, then a row of about 40 rounded capsule bars with hairline time ticks. Verdict first, shape second. This is the best "will I need an umbrella" pattern I found among third parties. |
| `weathergraph-appstore-watch-ultra-07.png` | same listing [V] | Smart Stack in Weathergraph: a graph widget with a bold coloured headline "16°C Partly sunny" over a mini temperature and rain graph. |
| `weathergraph-appstore-watch-ultra-00.png` | same listing [V] | App graph: gradient area with a dotted line. Shows how busy a full graph gets (too dense for a circle). |
| `carrot-appstore-phone-watch.png` | https://apps.apple.com/us/app/id961390574 [V] | CARROT face: a circular **precipitation "40%"** with a blue arc filling from the left and a droplet in the gap, a pressure dial, a mini radar tile and a compass. Each circle uses a different, quite elaborate idiom (dial, gauge, radar sweep). Reads busy next to Apple's uniform gauges. The 40% rain chance is the standard single-value answer. |
| `rainalarm-appstore-watch-chicago.png` | https://apps.apple.com/us/app/id397676100 [V] | Rain Alarm watch app: a full-screen radar map with a pill "Chicago, 23°". A map is not glanceable at 50 pt and shows nothing about timing. Included as the counter-example. |

Searched but not found as images (searches returned only text): Buienalarm's and Buienradar's own watch complications (iCulture says Buienradar offers an extra-wide Infograph Modular complication and a small round one that opens the app, https://www.iculture.nl/nieuws/buienradar-terug-apple-watch [T]), Dark Sky's old complications, Mercury, Hello Weather, Forecast Bar's circular tide gauge, Sleep++, CGM sparkline complications. A Home Assistant write-up of a DIY Buienradar corner complication (https://style.oversubstance.net/2021/07/buienalarm-buienradar-apple-watch-complication-using-home-assistant) states that Buienalarm's graph "resizes the Y-axis when heavier rain is forecast" [T]. I downloaded its images and found they were a stock photo and unrelated screenshots, so I deleted them.

Pattern across all of these [I]: nobody draws a time series inside a 50 pt circle. They either show one number (rain chance, mm), or draw the graph in the large slot. That means a real "line in a circle" would be new, and needs more care than copying.

## 3. Smart Stack widgets

| Saved image | Source | What it shows and why it works |
|---|---|---|
| `apple-wwdc23-10309-smartstack-weather-widget-on-watch.png` | WWDC23 10309 at about 2:50 [V] | Apple Weather widget in the stack: blue background, headline "76° H:88° L:57°", then five hourly columns (NOW, 11AM, 12PM, 1PM, 2PM) each with a number over an icon, separated by hairlines. The background colour carries the weather. Text is white and about the same size as the headline row. |
| `apple-wwdc23-10309-smartstack-sleep-heartrate-chart-widgets.png` | WWDC23 10309 at about 2:54 [V] | Sleep (dark blue) and Heart Rate (dark with red dots) widgets stacked. Each: a headline with two tones ("7HRS 26MIN" white, "ASLEEP" cyan), a chart with a faint grid, and two small time captions at the ends. |
| `apple-wwdc23-10309-chart-layout-callout-and-sleep-widget.png` | WWDC23 10309 at about 4:50 [V] | Apple's **chart layout**: a "CALLOUT" headline above a plot, with a row of "CAPT" captions above and below it. The sleep widget fills it: callout, bars, captions "10:56PM" and "6:26AM" at the ends. The chart gets about 60% of the height. |
| `apple-wwdc23-10309-circular-graphic-layout-activity-widget.png` | WWDC23 10309 at about 4:16 [V] | Circular-graphic layout: rings on the left, three coloured text lines on the right ("325/400 CAL" red, "15/30 MIN" green, "3/12 HRS" cyan). Shows the graphic-plus-text pattern: graphic left, words right. |

Apple's design rules for the Smart Stack [T], from the WWDC23 10309 transcript (https://developer.apple.com/videos/play/wwdc2023/10309) and the Widgets HIG (https://developer.apple.com/design/human-interface-guidelines/widgets):

- Six layouts: three-line text, colour-coded text, bar gauge, circular graphic, large text, chart. "If you have content that is primarily expressing data over time, we have a layout made for charts."
- "Only show what is necessary to ensure glanceability ... people should only be spending around ten seconds max engaging with glanceable information on their Watch."
- Use Apple's text styles for sizes, weights and margins. Default background is a dark material with white text, but "choose a color for their widget background that assists in app recognition or conveys informational meaning" (Weather uses a dynamic gradient, Stocks red or green).
- Put an SF Symbol before the headline "so you know the kind of content that's being represented".
- Relevancy: time, location, headphones, wake and bedtime, workouts. The HIG says relevancy "helps the system show your widget when people need it most".
- Smart Stack widget size on Ultra 3 (49mm): 198 x 81.5 pt. Ultra 1 and 2: 191 x 81.5 pt. 45mm: 184 x 80.5 pt. [T, HIG "watchOS dimensions"]
- Rectangular text default: rounded, medium, 19.5 pt on 45mm and 49mm. Minimum text: "11 points or larger". Standard margins 16 pt, tighter 11 pt. [T]
- Rendering: on Apple Watch there is Full-color and Accented. In Accented the system tints primary content white and accented content in the watch face colour. Group components accordingly. "Convey meaning without relying on specific colors." [T]
- A rectangular complication layout may also appear in the Smart Stack. The Heart Rate complication is Apple's example of a graph: "high-contrast white and red for the primary content and a lower-contrast gray for the graph lines and labels". [T, HIG Rectangular]
- Apple's own Precipitation widget appears in the Smart Stack when rain is forecast at a calendar event's location ("the Precipitation widget appears in the Smart Stack"). [T, Apple Support weather page]. I could not get an image of it.

## 4. Why my first circular mock-up failed (from `rain-watch-mockups/renders/families.png`) [V]

- The rain shape is a dome sitting on top of a thin ring, so the "line" has no baseline and no scale.
- "25m" sits on top of the ring at the bottom, so text and graphic overlap.
- The "RAIN" and "DRY" labels are about 5 pt. The HIG floor is 11 pt for text, and Apple's smallest circular text is the 12 pt corner text.
- A flat grey disc sits behind the ring, which makes the face look like the legacy Circular Small template, not Apple's black-background gauge.
- It carries four elements (label, value, ring, shape) in a space where Apple allows three.

## 5. My design rules (mine, not Apple's)

### Circular complication, 50 pt on Ultra 3

1. **Three elements maximum**: one big value, one graphic, one glyph or tiny label. Josh's face never exceeds this. [I]
2. **The value answers the question in words**: "25" for minutes until rain with "min" small, or "Dry" with a tick, not a total in mm. The graphic is the proof, not the answer. This matches the Weather app and Weathergraph's "Rain until 18:50" pattern. [I]
3. **Use Apple's gauge anatomy so it feels native**: 240° open arc from 8 o'clock to 4 o'clock, gap at the bottom, round caps, glyph (droplet) in the gap, stroke about 5 to 6 pt (10 to 13% of 50 pt). [V, I]
4. **Minimum 2 pt** for any stroke or bar (HIG), and for rain use at least a 2 pt dot even for drizzle so light rain is never invisible. [T, I]
5. **Draw 8 bars at most** (15 minutes each over 2 hours). Apple's own next-hour chart uses 12 bars across a card about 70% of the screen wide, which is far more room than a circle has. Eight bars 3 pt wide with 1.5 pt gaps need about 36 pt, which is roughly the widest chord available in the lower half of a 50 pt circle, so that is the density ceiling. [V, I]
6. **No y-axis, no mm labels, no grid.** Apple's next-hour chart has only "Now" and "60m". Put "Now" at the left end by position alone. [V]
7. **Fixed intensity scale, not auto-zoom**, so a drizzle does not look like a downpour. Use Buienradar's real thresholds, with three clear height steps (light, moderate, heavy) and cap the height. [I]
8. **Encode intensity with length or thickness, never with colour alone.** In tinted mode and Night Mode (red on Modular Ultra) everything is one hue, so height, thickness and the text are all that survive. Put the bars in the accent group (tinted with the face colour) and the number in the primary group (white). [T, I]
9. **Keep the text off the graphic**: nothing overlaps the ring, the number sits in the centre inside the arc's inner radius (about 15 pt radius), the glyph in the gap. [V]
10. **Dry state is calm**: a thin 2 pt grey track and the word "Dry", not an empty chart. [I]
11. **Rain-now state**: replace the minutes-until with "Dry in 20" or the heaviest-bar emphasis, same layout. [I]
12. **Test at real size**: Weathergraph's own guide says to judge a layout on the actual watch at the distance you normally hold it, because enlarged screenshots flatter small labels. [T, https://weathergraph.app/guides/apple-watch-weather-complications]

### Rain Smart Stack widget (198 x 81.5 pt on Ultra 3)

1. **Headline first, in a word that answers the question**: "Rain in 25 min", "Dry for 2 h", "Rain until 18:50". Use an SF Symbol (cloud.rain or drop) before it, as Apple does. [T, V]
2. **Use Apple's chart layout**: headline on top, plot beneath filling about 60% of the height, two end captions ("Now" and "+2 h" or the clock time at the right end). Nothing else. [V, T]
3. **Bars, not a thin line, in the widget too**: capsule bars like Apple's own rain chart read at arm's length; a 1 pt hairline does not. Use rounded bars of 3 to 4 pt with 1 to 2 pt gaps, 24 bars for 5-minute steps over 2 hours, or 12 bars of 10 minutes if it looks dense. [V, I]
4. **Hairline dividers only at 30-minute marks**, copying Apple's faint verticals. [V]
5. **Background carries the state**: a dark blue material for rain, plain dark for dry, as Apple does for Weather, Stocks and Sleep. Do not rely on it alone. [T]
6. **Two-tone headline** like Apple's sleep widget ("7HRS 26MIN" white, "ASLEEP" cyan): "Rain" in the accent, "in 25 min" in white. [V]
7. **Relevancy**: raise the widget when rain is forecast within the next two hours (Apple raises its own Precipitation widget on the same signal). [T]

### Four circular concepts that keep "height = intensity, line = time" (all mine, untested)

Common frame: 50 pt circle, black background, no grey disc. "Now" is always at the start of the time axis.

1. **Radial-bar arc.** The 240° open arc (8 to 4 o'clock) is the time axis, left end = now, right end = +2 h. A faint 2 pt track marks the baseline at about 15 pt radius. Eight capsule bars, 3 pt wide, stand on the track and point outward, with length = intensity (2 pt dot to about 9 pt). The big number (minutes until rain, 14.5 pt rounded medium) sits in the centre and a droplet in the bottom gap. Closest to the web's "height = intensity" while keeping Apple's gauge shape. Risk: bars at the left and right ends point sideways, so those two read less well.
2. **Bowl.** A shallow bottom arc hugging the rim is the baseline (left = now, right = +2 h). Eight bars grow upward and inward from it (up to about 12 pt), like Apple's Weather next-hour chart. The number sits in the upper half. This is the Weather widget shrunk into the circle, so the reading is immediate. Risk: it ignores the gauge idiom, and bars at the ends are very short because the chord narrows.
3. **Clock dial.** Full 360°, starting at 12 o'clock and going clockwise, 12 ticks of 10 minutes each (2 hours), tick length = intensity, a dot at 12 for now, the number in the middle. Uses Apple's own hourly-dial idea. Risk: people read position as clock time, and 12 ticks on a 25 pt radius is the density limit.
4. **Variable-width gauge.** The 240° gauge, left end = now, right end = +2 h, drawn as one continuous round-capped arc whose thickness is the intensity: 2 pt (the HIG floor) where dry, up to about 7 pt in a downpour. A dot marks now at the left end, the number in the middle, a droplet in the gap. It looks like Apple's own gauge, so it is the quickest to read, but "height" becomes thickness, a weaker cue for small differences. It never looks empty and works in every tint.

My view [I]: prototype concept 4 first, because it is nearest to what is already on Josh's face and passes the three-element rule easily. Concept 1 second, because it keeps the literal "height" encoding. Concepts 2 and 3 are worth a render each to compare, but I expect the bowl to feel off-idiom and the dial to be misread as a clock.

## 6. Gaps and how I worked

- I did not run any of these on a watch. All numbers (stroke 5 to 6 pt, bar 3 pt) are my estimates from screenshots and the HIG's stated sizes.
- Not found: images of Apple's Noise, Heart Rate, Moon, Tides, Elevation and Precipitation complications; Buienalarm and Buienradar complication images; Dark Sky, Mercury, Hello Weather, Sleep++ and CGM complication images. The corresponding searches returned text only.
- HIG illustrations of the open and closed gauges could not be downloaded. The alt text is the source for their geometry.
- WWDC frames are from the SD video (960 x 540), so details like stroke widths are approximate. I deleted the video and scratch files after extracting frames.
- Searching beyond watchOS 10 for Apple's WWDC24 to WWDC26 Smart Stack material turned up only the Apple support pages for watchOS 26 and 27 (no new layout rules). The 2023 session is still the primary source for layouts.

## Sources

- Apple HIG, Complications: https://developer.apple.com/design/human-interface-guidelines/complications
- Apple HIG, Widgets: https://developer.apple.com/design/human-interface-guidelines/widgets
- WWDC23 10309 "Design widgets for the Smart Stack on Apple Watch": https://developer.apple.com/videos/play/wwdc2023/10309
- Apple Support, faces and features: https://support.apple.com/guide/watch/faces-and-features-apde9218b440/watchos
- Apple Support, weather: https://support.apple.com/guide/watch/weather-apd07ec24f9e/watchos
- Apple Support, Smart Stack (watchOS 27): https://support.apple.com/guide/watch/see-widgets-in-the-smart-stack-apdecf142fb9/27/watchos/27
- App Store listings: Apple Weather (id1069513131), Weathergraph (id1501958576), CARROT (id961390574), Rain Alarm (id397676100)
- Weathergraph guide: https://weathergraph.app/guides/apple-watch-weather-complications
- Forecast Bar complications guide: https://forecastbar.com/manual/watch/complications/
- 9to5Mac, watchOS 10 Weather: https://9to5mac.com/2023/09/26/new-apple-watch-weather-app-watchos-10-how-it-works
- iCulture on Buienradar's watch app: https://www.iculture.nl/nieuws/buienradar-terug-apple-watch

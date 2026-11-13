<!-- Written by AI on 2026.11.13 by model claude opus 5.5. Sources are in research/. -->

# Rain on the watch: requirements

## What Buienradar is to people

People open Buienradar as they are about to leave, to find out whether they will get wet, and they change their plans on the answer.

- A study of 16 Buienradar users found that they open it "as they are about to undertake an activity that involves leaving the house", "overwhelmingly" before cycling. They are "motivated ... by a desire to know if they may 'get wet' ... in hopes that they can adapt their plans", and they look one to three hours ahead. They choose what to wear and whether to take an umbrella or the bike, and they "sometimes also delay their plans". Source: Masson and van Es, "Rain on your radar" (2020), read in full in `research/masson-van-es-2020-rain-on-your-radar.txt`.
- The same study found that many users read the graph line only as "rain" or "no rain". One complained that it assumes people understand millimetres per hour.
- Dark Sky's founder describes the same job: decide whether to wait 15 minutes before going to the car (The Atlantic, 2026).
- Josh: "the key point about buienradar is prediction ... 'will i need an umbrella' or 'is it safe to go out now'".

## What the rain is actually like

On 13 November at 13:30 I sampled Buienradar's nowcast at 94 places in the Netherlands and Europe (`research/live-data/`). 56 had rain within two hours. The most common wet pattern was showers on and off (27 places), then dry with rain starting later (18). Most Dutch rain was drizzle: Buienradar graph heights of 2 to 20%, or 0.1 to 1 mm/h, often in single five-minute blips.

## What a glance must answer, in order

1. Is it dry now, and for how long? Or, if it is raining, when does it stop?
2. What comes next, and when: the next shower or the next dry spell, with clock times.
3. How hard it rains, as words and as the height of the line.
4. The whole two hours, including showers that stop and come back.

## Requirements

1. The circular complication answers question 1 from the watch face without a tap. The arc is Buienradar's graph bent round, on Apple's gauge anatomy (a 240° arc open at the bottom): the blue line says rain, its height says how hard, and a dot marks the next change. The middle reads top to bottom as one phrase about that dot, "IN 30 MIN", as Apple's own Rain complication writes "IN 3M"; when nothing changes in the two hours it reads "FOR 2+ HRS". With no rain there is no line, only "Dry" over "FOR 2+ HRS". The circle is the size of Apple's gauges beside it on Josh's face: the arc reaches 91% of the slot's radius and the number is about 16 points, like the Activity gauge's. The lead word sits inside the track and the unit in the gap at the bottom, where Apple's gauges put their labels. No word touches the line, and no word is shrunk to fit.
2. The arc and the line are Buienradar's own data. Time runs along them, from now to two hours, and height shows intensity on Buienradar's Light, Moderate and Heavy lines.
3. Any rain at all shows as visibly different from dry. A forecast with no rain says so.
4. A dot marks the moment the headline counts down to, so the words and the line agree.
5. The words name what is happening now and how long it lasts. They follow the writing guide: plain phrases with their prepositions ("for 30 min", "in 30 min"), no codes or shorthand ("2H+", "30M"), no advice, no millimetres, no probabilities, British English, and nothing implied beyond the two hours shown.
6. Dry gaps under 10 minutes between two wet stretches count as wet in the words, because nobody can use them. The line still shows them.
7. The rectangular slot and the Smart Stack show the headline and the full line, at least about 22 points high so its height still shows how hard it rains. Under the headline they name the next change with clock times where there is room for both, as in the Modular Ultra slot; in shorter slots and the Smart Stack that line gives way to the graph.
8. The Smart Stack widget surfaces itself when rain is forecast within two hours, so it is on the wrist at the moment of leaving without a face slot.
9. Colour only repeats what height shows, so tinted faces and Ultra Night Mode lose nothing.
10. The data can always be trusted. watchOS reloads a complication on the active face about every 15 to 20 minutes and the Smart Stack less often (WWDC26 watchOS Group Lab; `research/freshness.md`), so nothing on the watch is real time. Rain makes age the promise instead:
    - Each reload fetches once and writes an entry for every minute, so the countdown stays exact between reloads, and asks to be reloaded after 15 minutes.
    - When a forecast is 30 minutes old, a stale entry replaces the countdown: "No forecast since 15:12, Open Rain to update" and "--" in the circle. Entries show at their own dates, so this happens on time even when watchOS skips or delays a reload, and a failed fetch keeps the old fetch time.
    - Opening the app fetches, which costs no widget budget, and reloads every complication.
11. Location: the widget tries its own fix and reuses one under five minutes old, so the widgets on a face share one. If it cannot get a fix it uses the last one the app or a widget saved. Each reload is logged to the app group with where its location came from, to measure on the real watch how often watchOS refreshes and whether the widget gets its own fix. Continuous background location is out until a day's battery test justifies it.
12. Tapping a complication opens the app: the forecast in full, with a button to the radar. The app follows Apple's layout and type: the system's margins and text styles, and Swift Charts for the graph.
13. The radar is about time and precision. It plays Buienradar's frames from half an hour ago to two hours ahead, as Buienradar's own watch app does, over a strip with the rain line for where you are and a marker at the frame shown, so a shower reaching you on the map shows as the line rising under the marker. The crown pauses it and steps five minutes a click; a tap plays again. It opens about 30 km across, as close as the radar's 650 m pixels allow, and zooms out to 120 km to show what is coming.

## Words

| Now | Circular middle | Headline | Second line |
|---|---|---|---|
| No rain in the two hours | Dry, FOR 2+ HRS (no line) | Dry for 2+ hours | (none) |
| Dry, rain later | IN 30 MIN | Dry for 30 min | Light rain 14:00–14:25 |
| Raining, stops, comes back | IN 5 MIN | Rain stops in 5 min | Dry 13:35–14:15 |
| Raining, stops after an hour or more | IN 100 MIN | Rain until 15:10 | Heaviest around 13:55 |
| Raining throughout | FOR 2+ HRS | Rain for 2+ hours | Heaviest around 14:15 |

Every family uses the same headline; inline and corner slots show it alone. Beyond an hour the headline names the clock time ("Rain until 15:10") so it fits one line. VoiceOver reads the headline and the line under it.

The circular carries no RAIN or DRY label: the line already says which. Apple's own Weather Rain complication shows a rain-cloud glyph over "IN 3M" or "NOW" (MacRumors thread, May 2024, screenshots in `research/prior-art-apple-rain/`). A clock time in the middle was tried and rejected: next to the watch's own clock it read as another clock.

The rain rises outwards from the track, so the arc is Buienradar's graph bent round with its baseline inside. Growing inwards would keep the track at the rim like Apple's other gauges, but it turns the graph upside down and pushes heavy rain into the middle.

Intensity words follow Buienradar's lines: Drizzle below Light, then Light rain, Rain and Heavy rain. The wording follows the convention Dark Sky set and Apple Weather and Forecast Bar use ("rain starting in 12 minutes", "rain stopping in 55 minutes"), turned so that the dry case answers "can I go now, and for how long". The survey is in `research/copy-survey.md`.

## Drawing

Apple's own next-hour rain chart, and the prior-art agent, use capsule bars. The line stays, because Josh said in August "the buienradar line is the key thing to preserve" and called bars "too barchart".

The Smart Stack card is blue when rain is forecast and neutral when not, as Apple's Weather, Stocks and Sleep widgets colour theirs by state, with an SF Symbol before the headline (WWDC23 session 10309).

In the complications the line plots the square root of Buienradar's graph height; in the circle the track sits at 64% of the radius and rain rises to 91%, about 7 points. The app's graph plots Buienradar's own height, with its Light and Heavy lines labelled, so it reads like the website. The square root keeps Buienradar's order and scale lines, but lifts drizzle and light rain, which is most Dutch rain, off the baseline of a graph only 20 to 40 points tall. A 26% shower fills half the graph instead of a quarter.

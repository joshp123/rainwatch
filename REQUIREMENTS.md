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

1. The circular complication answers question 1 from the watch face without a tap, the way Apple's Sunrise/Sunset complication names the next event: the clock time of the next change in the middle, and what changes ("RAIN" or "DRY") in the gap below, as Apple's gauges put "AQI" there. It uses Apple's gauge anatomy: a 240° arc open at the bottom, one value, one short word.
2. The arc and the line are Buienradar's own data. Time runs along them, from now to two hours, and height shows intensity on Buienradar's Light, Moderate and Heavy lines.
3. Any rain at all shows as visibly different from dry. A forecast with no rain says so.
4. A dot marks the moment the headline counts down to, so the words and the line agree.
5. The words name what is happening now and how long it lasts. They give no advice, no millimetres and no probabilities, use British English, and imply nothing beyond the two hours shown.
6. Dry gaps under 10 minutes between two wet stretches count as wet in the words, because nobody can use them. The line still shows them.
7. The rectangular slot and the Smart Stack show the headline, the next change with clock times, and the full line.
8. The Smart Stack widget surfaces itself when rain is forecast within two hours, so it is on the wrist at the moment of leaving without a face slot.
9. Colour only repeats what height shows, so tinted faces and Ultra Night Mode lose nothing.
10. One fetch of Buienradar's three-hour graph feeds an entry every five minutes, each showing now to two hours, so the widget stays current between the system's reloads. It works anywhere Buienradar covers: RainNL3Hour in the Netherlands and RainEU3Hour across Europe.

## Words

| Now | Circular (middle, gap) | Headline | Second line |
|---|---|---|---|
| No rain in the two hours | Dry | No rain forecast | (none) |
| Dry, rain later | 14:00, RAIN | Dry for 30 min | Light rain 14:00–14:25 |
| Raining, stops, comes back | 13:35, DRY | Rain stops in 5 min | Dry 13:35–14:15 |
| Raining, stops | 15:10, DRY | Rain stops in 1 h 40 min | Dry from 15:10 |
| Raining throughout | Rain | Rain for 2 hours | Heaviest around 14:15 |

The circular uses a clock time because Apple never puts "in 25 min" in a circular complication: its Sunrise/Sunset, World Clock and Calendar complications all name a time. Sentences, where there is room, use minutes, as Dark Sky and Apple Weather do.

Intensity words follow Buienradar's lines: Drizzle below Light, then Light rain, Rain and Heavy rain. The wording follows the convention Dark Sky set and Apple Weather and Forecast Bar use ("rain starting in 12 minutes", "rain stopping in 55 minutes"), turned so that the dry case answers "can I go now, and for how long". The survey is in `research/copy-survey.md`.

## Drawing

Apple's own next-hour rain chart, and the prior-art agent, use capsule bars. The line stays, because Josh said in August "the buienradar line is the key thing to preserve" and called bars "too barchart".

The Smart Stack card is blue when rain is forecast and neutral when not, as Apple's Weather, Stocks and Sleep widgets colour theirs by state, with an SF Symbol before the headline (WWDC23 session 10309).

The line plots the square root of Buienradar's graph height. That keeps Buienradar's order and scale lines, but lifts drizzle and light rain, which is most Dutch rain, off the baseline of a graph only 20 to 40 points tall. A 26% shower fills half the graph instead of a quarter.

Written by AI on 2026.11.14 by model claude sonnet 5.5.

# KNMI nowcast against Buienradar: is it comparable?

## Answer

**On the one rainy test I could run, KNMI is at least as good as Buienradar in the Netherlands, and a little better.** It is not proven. Treat it as "no sign that Rain gets worse", not as a guarantee.

Over the Netherlands (48 grid places, one forecast issued 13 Nov 2026 12:30 UTC, scored against what KNMI's radar measured over the next two hours):

- **Rain/no-rain at 5-minute steps.** The CSI (hits divided by hits plus misses plus false alarms; 1.0 is perfect) was 0.20 for KNMI, 0.15 for Buienradar and 0.08 for "rain stays as it is now". The two forecasts find the same share of rain (hit rate 34% and 33%). Buienradar raises far more false alarms: 78% of its rain steps were dry, against 66% for KNMI.
- **Start of rain.** Where rain really started, KNMI's start time was a median 0 minutes off and 69% within 10 minutes. Buienradar's was a median 5 minutes early and 47% within 10 minutes.
- **After about 60 minutes neither is useful on this day.** CSI is 0.10 or less for both, and both only move existing rain along. Buienradar's own FAQ says the same about its forecast.

Caveats that matter (section 5): one weather day, mostly light rain; the "truth" is KNMI's own radar, which favours KNMI at short range; no rain gauges used.

## 1. Where Buienradar's forecast comes from

| Question | Answer | Source |
|---|---|---|
| Who owns it | RTL Nederland bought Buienradar on 1 April 2011. RTL joined DPG Media on 1 July 2025 and Buienradar now says it is part of DPG Media. Its meteorologists work for "RTL Weer and Buienradar". | [NRC 2011](https://www.nrc.nl/nieuws/2011/03/31/rtl-nederland-neemt-buienradar-nl-over-a1458714), [Buienradar FAQ](https://www.buienradar.nl/overbuienradar/faq), [Buienradar company details](http://buienradar.nl/overbuienradar/bedrijfsgegevens), [RTL, 26 May 2025](https://www.rtl.nl/over/newsroom/jordi-huirne-vult-meteorologenteam-rtl-weer-en-buienradar-aan) |
| Which radars | The two KNMI radars (Den Helder, Herwijnen), merged with radars from the UK, Belgium and Germany into one image. Buienradar buys the KNMI images and also buys German and British ones. Its sources page lists DWD, Met Office and EUMETSAT (the KNMI logo did not show in the text I could read). | [Buienradar blog](https://www.buienradar.nl/nederland/weerbericht/blog/hoe-werkt-de-buienradar-precies-motregen-regen-radar-uitleg-radio-golven), [Volkskrant, 19 Nov 2021](https://www.volkskrant.nl/wetenschap/het-zou-toch-droog-blijven-hoe-buienradar-werkt-en-hoe-het-beter-kan~bc5d97d6), [Buienradar sources](https://www.buienradar.nl/overbuienradar/bronnen) |
| Who makes the nowcast, and how | Buienradar itself. Its FAQ: the 3-hour forecast takes the latest radar image and moves it along with the direction the showers travel. It "cannot account for showers forming or dissolving", because a model run would take about 5 hours. Its longer products (8 to 48 hours) use KNMI's HARMONIE weather model instead. | [Buienradar FAQ](https://www.buienradar.nl/overbuienradar/faq), [Buienradar blog on the radars](https://www.buienradar.nl/nederland/weerbericht/blog/van-1-tot-48-uur-welke-buienradar-kies-je-c13fcf) |
| How often | Radar images every 5 minutes. Its free-data page says the per-coordinate rain forecast is two hours ahead and updated every 5 minutes. | [Buienradar free data](https://www.buienradar.nl/overbuienradar/gratis-weerdata) |
| Resolution | Not published. The feed rounds coordinates to two decimals (about 1 km) and gives rain in steps of 0.1 mm/h. The Dutch graph the app calls covers 2 h 45 min in 5-minute steps (34 values in the saved files). | `Sources/RainGraph/Buienradar.swift`, saved files |

**KNMI's nowcast** (`radar_forecast` 2.0): an operational KNMI version of pySTEPS, a deterministic forecast, 25 steps from +0 to +120 minutes, 1 km grid, started from KNMI's real-time 5-minute radar and rain-gauge product (RTCOR-5m). That product uses 2 Dutch, 3 Belgian and 3 German radars and is available about 2 minutes after the measurement. The newest forecast file I listed was created 1.5 minutes after its time stamp. Sources: [dataset page](https://dataplatform.knmi.nl/dataset/radar-forecast-2-0), [KNMI news, 11 May 2026](https://www.knmi.nl/over-het-knmi/nieuws/regenbuien-nu-nog-beter-te-volgen).

**Is it the same radar data?** Partly. Both start from KNMI's two radars plus Belgian and German ones. Buienradar also buys British data and does its own compositing and processing, so the images are not the same. My own measurement agrees. At the issue time (step 0) KNMI equals its radar product exactly (largest difference over the whole grid: 0.00 mm/h). Buienradar agreed with it on wet or dry at 97% of the 65 places, with an intensity correlation of 0.83 across the 65 places. It showed rain at two places where KNMI's radar showed none (Brussels and a sea cell north of the Wadden islands) and read 0.4 mm/h where KNMI's radar read 1.3 mm/h at one coastal place (51.95 N, 4.05 E).

Both are the same kind of forecast: today's rain pattern, moved along. Neither can predict showers that have not formed yet.

## 2. What I measured

- **KNMI forecast.** `radar_forecast` 2.0, file `RAD_NL25_RAC_FM_202611131230.h5`. KNMI still serves it. The forecast file listing starts on 14 Aug 2024.
- **Buienradar forecast.** The 64 Dutch grid files in `research/live-data/` (50.9 to 53.35 N, 3.6 to 6.75 E, about 35 km apart; the southern row is in Belgium and the west column is at sea) plus Brussels. All saved at 12:30 UTC. Hamburg is excluded: KNMI's radar product has no observation there (the forecast file shows 0 mm/h there rather than "missing").
- **What fell.** `nl_rdr_data_rtcor_5m` 1.0, files `RAD_NL25_RAC_RT_*`: the radar rainfall corrected with rain-gauge data, per 5 minutes, from 12:30 to 14:30. Step 0 of the forecast and this product are identical, which also confirmed that my place-to-grid-cell mapping is right.
- **Method.** The same 1 km cell for all three sources. Wet means at least 0.05 mm/h (Buienradar's 0.1 mm/h after rounding; KNMI rounded the same way). "Rain stays as it is now" is the naive baseline.
- **Live sample.** None possible. All 64 Dutch places showed no rain on Buienradar at 13:48 and 14:55 UTC on 14 Nov.

## 3. Results

Headline set: the 48 places north of 51.6 N, which are Dutch land and coast (31 of them saw rain). Scores for "rain or no rain" at 5-minute resolution, by how far ahead:

| Lead time | KNMI hit rate / false-alarm share / CSI | Buienradar | Rain stays as now |
|---|---|---|---|
| +5 to +30 min | 0.50 / 0.20 / 0.44 | 0.47 / 0.44 / 0.34 | 0.31 / 0.58 / 0.22 |
| +35 to +60 min | 0.61 / 0.63 / 0.30 | 0.65 / 0.73 / 0.24 | 0.04 / 0.96 / 0.02 |
| +65 to +120 min | 0.17 / 0.82 / 0.10 | 0.16 / 0.89 / 0.07 | 0.07 / 0.90 / 0.04 |
| All | 0.34 / 0.66 / 0.20 | 0.33 / 0.78 / 0.15 | 0.13 / 0.83 / 0.08 |

"Hit rate" is the share of rain steps that were forecast. "False-alarm share" is the share of forecast rain steps that stayed dry. Plain accuracy (right call on wet or dry, mostly dry steps) is 0.86 for KNMI and 0.80 for Buienradar.

- **Same on all 65 places** (including Belgium): CSI 0.19 for KNMI, 0.12 for Buienradar, 0.08 for no change.
- **Is the gap just noise?** Resampling the places 2,000 times, KNMI's CSI is ahead of Buienradar's in 98% of resamples (difference +0.05, 90% interval +0.01 to +0.09). Neighbouring places share the same weather, so this understates the real uncertainty.
- **Looser matching.** Counting a forecast as right if rain fell in any of the 9 cells (about 3 km) around the place: false-alarm share 0.57 for KNMI and 0.78 for Buienradar (65 places). The ranking does not change.
- **15-minute view:** CSI 0.23 for KNMI and 0.18 for Buienradar.

**When rain starts** (places dry at 12:30, with at least two wet 5-minute steps in a row later). Rain really started at 24 places.

| | KNMI | Buienradar |
|---|---|---|
| Predicted a start at those places | 13 of 24 | 17 of 24 |
| Start time error where predicted: median / average size | 0 min / 15 min | 5 min early / 24 min |
| Within 10 minutes | 69% | 47% |
| Predicted a start where none came (of 14 places) | 9 | 13 |

Buienradar finds more of the rain and also invents more. Where both predicted a start (19 places), KNMI was later at 12, equal at 6 and earlier at 1 (median 5 minutes later).

**When rain stops.** Only two places had rain at 12:30 that stopped within 10 minutes (52.3 N, 4.5 E and 52.3 N, 4.95 E). Both sources ended it on time. Too few to say more.

**How hard.** Rain over the 2 hours, added up across the 48 places, is close: observed 4.56 mm, KNMI 4.70 mm, Buienradar 4.83 mm. Buienradar gets there with many more light steps: 184 steps of at least 0.05 mm/h against 125 observed and 125 for KNMI. Steps of at least 0.25 mm/h: 62 observed, 58 KNMI, 69 Buienradar. Steps of at least 1 mm/h: 11 observed, 15 KNMI, 10 Buienradar. Correlation of the 5-minute values with observed: 0.34 for KNMI, 0.17 for Buienradar. In the steps where it really rained (all 65 places, +0 to +120), both read the intensity too low: observed average 0.44 mm/h, KNMI 0.22, Buienradar 0.16.

## 4. Per place

Start is the first of two wet 5-minute steps in a row (minutes after 12:30 UTC; "now" means wet at 12:30). Rain totals are for the next two hours in mm, with the peak in mm/h in brackets. Only places with rain in any source are shown (55 of 65). "Grid" places are my 35 km sample grid, not named towns.

| Place (lat, lon) | Observed start | KNMI start | Buienradar start | Observed 2h rain mm (peak mm/h) | KNMI | Buienradar |
|---|---|---|---|---|---|---|
| Brussels 50.85, 4.35 | – | +95 | now | 0.00 (0.0) | 0.03 (0.1) | 0.16 (0.2) |
| Grid 50.9, 4.05 | – | – | +5 | 0.00 (0.0) | 0.00 (0.0) | 0.82 (1.5) |
| Grid 50.9, 4.5 | +80 | +85 | +55 | 0.02 (0.1) | 0.04 (0.4) | 0.06 (0.2) |
| Grid 50.9, 4.95 | – | +60 | +75 | 0.00 (0.0) | 0.12 (0.7) | 0.04 (0.2) |
| Grid 51.25, 3.6 | – | – | +30 | 0.00 (0.0) | 0.00 (0.0) | 0.03 (0.1) |
| Grid 51.25, 4.05 | – | – | +30 | 0.00 (0.0) | 0.03 (0.2) | 0.15 (0.5) |
| Grid 51.25, 4.5 | – | – | +40 | 0.00 (0.0) | 0.00 (0.0) | 0.05 (0.2) |
| Grid 51.25, 4.95 | – | +115 | +50 | 0.00 (0.0) | 0.07 (0.6) | 0.18 (0.3) |
| Grid 51.25, 5.85 | – | – | +85 | 0.00 (0.0) | 0.01 (0.1) | 0.16 (0.4) |
| Grid 51.25, 6.75 | – | – | – | 0.00 (0.0) | 0.00 (0.0) | 0.01 (0.1) |
| Grid 51.6, 3.6 | +5 | – | – | 0.18 (0.6) | 0.01 (0.1) | 0.00 (0.0) |
| Grid 51.6, 4.05 | now | now | now | 0.38 (1.4) | 0.13 (0.5) | 0.17 (0.5) |
| Grid 51.6, 4.5 | +85 | +90 | +80 | 0.07 (0.6) | 0.21 (1.1) | 0.10 (0.3) |
| Grid 51.6, 4.95 | +30 | – | +70 | 0.13 (0.5) | 0.00 (0.0) | 0.03 (0.2) |
| Grid 51.6, 5.4 | +30 | +35 | +30 | 0.08 (0.6) | 0.48 (2.6) | 0.29 (1.3) |
| Grid 51.6, 5.85 | – | +55 | +50 | 0.00 (0.0) | 0.32 (2.5) | 0.07 (0.5) |
| Grid 51.6, 6.3 | +95 | – | – | 0.07 (0.5) | 0.00 (0.0) | 0.01 (0.1) |
| Grid 51.6, 6.75 | – | – | +115 | 0.00 (0.0) | 0.00 (0.0) | 0.03 (0.2) |
| Grid 51.95, 3.6 | +25 | +65 | +60 | 0.25 (0.6) | 0.23 (0.7) | 0.13 (0.6) |
| Grid 51.95, 4.05 | now | now | now | 0.18 (0.6) | 0.20 (0.7) | 0.12 (0.3) |
| Grid 51.95, 4.95 | – | +95 | – | 0.01 (0.1) | 0.08 (0.6) | 0.02 (0.1) |
| Grid 51.95, 5.4 | – | – | +85 | 0.00 (0.0) | 0.00 (0.0) | 0.03 (0.2) |
| Grid 51.95, 5.85 | +115 | +65 | – | 0.04 (0.4) | 0.03 (0.2) | 0.00 (0.0) |
| Grid 51.95, 6.3 | +40 | +35 | +25 | 0.13 (0.4) | 0.45 (1.3) | 0.54 (2.0) |
| Grid 51.95, 6.75 | – | – | – | 0.02 (0.2) | 0.00 (0.0) | 0.00 (0.0) |
| Grid 52.3, 3.6 | +65 | – | +95 | 0.02 (0.1) | 0.01 (0.1) | 0.02 (0.1) |
| Grid 52.3, 4.05 | +85 | – | – | 0.46 (1.6) | 0.00 (0.0) | 0.00 (0.0) |
| Grid 52.3, 4.5 | now | now | now | 0.06 (0.7) | 0.05 (0.6) | 0.06 (0.6) |
| Grid 52.3, 4.95 | now | now | now | 0.06 (0.6) | 0.04 (0.5) | 0.20 (0.8) |
| Grid 52.3, 5.4 | +70 | – | +35 | 0.09 (0.6) | 0.01 (0.1) | 0.11 (0.5) |
| Grid 52.3, 6.3 | – | – | +105 | 0.00 (0.0) | 0.00 (0.0) | 0.35 (1.7) |
| Grid 52.65, 3.6 | – | – | – | 0.00 (0.0) | 0.01 (0.1) | 0.00 (0.0) |
| Grid 52.65, 4.05 | – | +90 | +85 | 0.00 (0.0) | 0.10 (0.6) | 0.09 (0.7) |
| Grid 52.65, 4.5 | +60 | – | – | 0.06 (0.5) | 0.01 (0.1) | 0.00 (0.0) |
| Grid 52.65, 4.95 | – | +85 | +55 | 0.01 (0.1) | 0.22 (1.3) | 0.28 (0.7) |
| Grid 52.65, 5.4 | +5 | – | +5 | 0.04 (0.4) | 0.02 (0.2) | 0.10 (0.7) |
| Grid 52.65, 5.85 | – | +60 | +55 | 0.00 (0.0) | 0.10 (0.5) | 0.12 (0.4) |
| Grid 52.65, 6.3 | +70 | +50 | +50 | 0.36 (2.0) | 0.51 (3.1) | 0.18 (0.7) |
| Grid 52.65, 6.75 | – | +110 | +70 | 0.00 (0.0) | 0.16 (1.0) | 0.13 (0.3) |
| Grid 53, 3.6 | – | +60 | +60 | 0.00 (0.0) | 0.02 (0.1) | 0.06 (0.2) |
| Grid 53, 4.05 | +65 | +70 | +40 | 0.19 (0.8) | 0.04 (0.1) | 0.08 (0.2) |
| Grid 53, 4.5 | – | – | +85 | 0.00 (0.0) | 0.00 (0.0) | 0.03 (0.1) |
| Grid 53, 4.95 | – | +80 | +55 | 0.00 (0.0) | 0.15 (1.6) | 0.20 (0.9) |
| Grid 53, 5.4 | +105 | – | +10 | 0.09 (0.6) | 0.00 (0.0) | 0.07 (0.5) |
| Grid 53, 5.85 | – | – | +30 | 0.00 (0.0) | 0.03 (0.4) | 0.14 (1.1) |
| Grid 53, 6.3 | – | +45 | +45 | 0.00 (0.0) | 0.04 (0.2) | 0.16 (0.9) |
| Grid 53, 6.75 | +45 | – | – | 0.13 (0.6) | 0.00 (0.0) | 0.00 (0.0) |
| Grid 53.35, 3.6 | +15 | +10 | +5 | 0.13 (0.5) | 0.11 (0.6) | 0.17 (0.6) |
| Grid 53.35, 4.05 | +10 | +10 | +10 | 0.21 (1.4) | 0.25 (1.1) | 0.28 (1.1) |
| Grid 53.35, 4.5 | +85 | – | +75 | 0.05 (0.2) | 0.01 (0.1) | 0.03 (0.2) |
| Grid 53.35, 4.95 | +35 | +35 | +35 | 0.30 (1.8) | 0.19 (0.8) | 0.11 (0.3) |
| Grid 53.35, 5.4 | +65 | +115 | – | 0.19 (0.6) | 0.02 (0.1) | 0.00 (0.0) |
| Grid 53.35, 5.85 | +5 | +5 | now | 0.09 (0.7) | 0.16 (0.6) | 0.05 (0.2) |
| Grid 53.35, 6.3 | +35 | +30 | +30 | 0.48 (1.9) | 0.29 (1.1) | 0.28 (1.1) |
| Grid 53.35, 6.75 | – | – | – | 0.00 (0.0) | 0.01 (0.1) | 0.00 (0.0) |

## 5. How small and how biased this is

- **One day, one issue time, 65 places.** Four places were wet at 12:30. 32 saw rain in the next two hours and 25 had a start (24 in the 48-place headline set). The places are 35 km apart but share one weather system, so the real number of independent cases is a handful.
- **Mostly light rain** (winter-style, 0.1 to 0.5 mm/h). Only 11 place-steps reached 1 mm/h. Summer showers, where an extrapolation forecast does worst, are untested.
- **The "truth" is KNMI's own radar.** The KNMI nowcast starts from that same product, so KNMI looks perfect at +0 by construction and has an edge at short range. Buienradar uses a different radar mix, so where it disagrees with KNMI's radar it is marked wrong, even where it may be right. Rain gauges would be independent. I did not use them, because the places I saved are not at gauge sites.
- **Belgium and sea cells** are in the 65-place set. Dropping them (the 48-place headline) did not change the ranking, but made the gap smaller (CSI +0.05 instead of +0.08).
- **The Buienradar numbers are the graph feed the app calls** (`RainNL3Hour`), saved once. I cannot see whether the same feed gives different values minutes later.
- **Not tested:** other issue times, a second rainy day, a summer shower day, the later gauge-adjusted reanalysis datasets (`nl_rdr_data_recor_5m`, `nl_rdr_data_rfcor_5m`).

## 6. Facts for the backend

- File names: forecast `RAD_NL25_RAC_FM_<YYYYMMDDHHMM>.h5` (25 images, `image_datetime_valid` = issue time + 5 min per step), observed `RAD_NL25_RAC_RT_<YYYYMMDDHHMM>.h5` (3 images; `image1` is the rain in mm per 5 minutes, `image2` is quality; the time stamp is the end of the 5 minutes). The observed file listing starts on 27 Oct 2019.
- The forecast file was 447 KB in rain on 13 Nov, against 224 KB dry on 14 Nov.
- Outside the radar product the forecast shows 0 mm/h, not "no data" (Hamburg). The server should not trust a zero near the edge of the grid.
- **The shared anonymous key returned HTTP 429 ("Rate Limit Exceeded") on every call from 13:45 to 14:37 UTC on a Saturday afternoon**, on all endpoints. It recovered by itself. About 20 of those requests per minute were mine for the first ten minutes, so I may have made it worse; KNMI's FAQ says to wait and lengthen the wait on each 429. The server needs its own registered key, as `research/global-data.md` already says.

<!-- Written by AI on 2026.11.14 by model claude sonnet 5.5, at Josh's request: "figure out what's actually state of the art and don't be fucking lazy". Numbers come from research/verification/season.py and season_analyse.py. -->

# Season test: KNMI plain forecast against KNMI blended forecast

## Verdict

**Show KNMI's plain forecast for the first 30 minutes, then the blend (rain where at least half of the 20 versions agree) from 35 minutes to 2 hours.**

- **First 30 minutes: plain, or a tie.** At 5 minutes plain is clearly better (CSI 0.86 against 0.82). From 10 to 25 minutes the two are level, and the blend edges ahead from 30 minutes. On the 30 days since KNMI changed the blend's file layout (30 Aug 2026), plain is a little better in this band (CSI difference −0.03, interval −0.09 to +0.01), so there is no case for the blend here.
- **35–60 minutes: the blend is slightly better.** CSI +0.022 over plain (interval +0.009 to +0.036), better on 67% of days. On the newest 30 days the gain is +0.013 and the interval includes zero.
- **65–120 minutes: the blend is better.** CSI 0.48 against 0.44, +0.040 (interval +0.024 to +0.055), better on 77% of days. It catches 64% of rain against 59%, and a slightly smaller share of forecast rain that stays dry (35% against 37%). The newest 30 days agree: +0.052 (+0.012 to +0.093).
- **Switching at 30 minutes beats either forecast alone.** CSI over the whole two hours: plain only 0.533, blend only 0.562, plain to 30 minutes then blend 0.560. That is +0.027 over plain only (interval +0.016 to +0.038); on the newest 30 days +0.031 (+0.007 to +0.055).
- **The rain threshold: use half the versions.** 30% catches more rain but gives more false alarms; 70% misses too much. 50% has the best or equal-best CSI in every band.

**How sure we can be.** Sure that the blend is not worse in the second hour: the 13 Nov pattern (blend worse after an hour) did not hold up. Fairly sure it is better there, in showery and widespread rain alike, and in the 10 days with heavy cells. Less sure about the exact switch time (anywhere from 10 to 35 minutes gives the same result), and not sure the blend ever wins the first half hour. The gain is small: about 0.03 CSI over the whole two hours. Plain alone is a fair launch choice. The blend costs a larger download (2 to 40 MB a file against 0.2 to 1.2 MB) and depends on a pilot that KNMI may end.

My own check: the pipeline reproduces the 13 Nov numbers in `radar-sota.md` exactly (plain 0.44 / 0.30 / 0.10, blend 0.51 / 0.40 / 0.05).

## What was done

- **Cases.** 66 issue times on 66 different days, from 16 Apr 2025 to 12 Nov 2026: 3 per month, 4 in June, July and August. The blend archive starts on 8 Apr 2025, not in March. Days were drawn at random within each month from KNMI's observed 5-minute radar archive (`nl_rdr_data_rtcor_5m_tar`, one file per day). A day was kept if some 2-hour window (issue times on the half hour) had at least 5% of its 48 places × 24 lead times wet (0.1 mm/h or more). One random qualifying issue time was taken per day. 32 drawn days had no such window and were dropped. 13 Nov 2026 was excluded, as it was the earlier case.
- **Seasons.** Spring 15, summer 24, autumn 18, winter 9. Winter has the fewest because only three months of it fall in the archive, so its results are the least certain.
- **Showery or widespread.** Widespread: more than 20% of the Dutch radar box wet on average over the 2 hours (18 days). Showery: less (48 days). The cut is arbitrary; the box wet share ran from 3% to 90%, and most days sat at 5–30%. "Heavy cells": a pixel of 50 mm/h or more in the box (10 days, 7 of them in summer).
- **Scoring.** Same as `score_case.py`: 48 places north of 51.6 N, truth is KNMI's observed 5-minute radar at the nearest 1 km cell, wet means 0.1 mm/h or more. Lead times 5 to 120 minutes. "Persistence" is the reference: rain at issue time simply stays.
- **Intervals.** 95%, from resampling whole days 4,000 times. Counts are pooled over places and leads, so days with more rain weigh more.
- **Newest sample.** KNMI changed the blend's file layout between 15 and 30 Aug 2026 (from the radar grid to a 780 × 780 latitude/longitude grid). To check that the season's result holds for the version KNMI serves now, I scored 20 more days from 30 Aug 2026 on, kept apart from the seasonal sample. With the 10 already in it, that is 30 days (28 autumn, 2 summer).
- **Cost.** About 320 KNMI requests in total, well under the hourly limit. All downloaded files were deleted after scoring.

## Things that limit these results

- The windows were chosen for having rain, so CSI describes rainy situations, not every moment.
- Truth and forecast both come from KNMI's own radar, so a gap between the radar and real rain at the places counts against both equally.
- Points at 48 places, not whole maps. The app shows one place, so this fits, but it says nothing about rain area shape.
- One winter and one spring of each kind of rain is a small sample; the seasonal tables below show it as wide intervals.
- I did not test the blend's six-hour range or its probabilities, only the two-hour wet or dry call.

## Results: the 66-day seasonal sample

Each CSI cell reads: value (95% interval). "Rain caught" is the share of observed rain places the forecast flagged; "stayed dry" is the share of forecast rain that did not happen. Lower is better for the second.

Cases: 66. Showery 48, widespread 18 (split: mean wet share of the Dutch radar box over the 2 hours, 20%).
By season: spring 15, summer 24, autumn 18, winter 9.

### All cases (66 days)

| Forecast | 5–30 min: CSI | 35–60 min: CSI | 65–120 min: CSI |
|---|---|---|---|
| KNMI plain | 0.75 (0.70–0.80) | 0.55 (0.47–0.63) | 0.44 (0.35–0.51) |
| Blend, rain if ≥30% of versions | 0.76 (0.70–0.81) | 0.57 (0.48–0.64) | 0.47 (0.39–0.54) |
| Blend, rain if ≥50% of versions | 0.76 (0.71–0.81) | 0.58 (0.49–0.65) | 0.48 (0.39–0.55) |
| Blend, rain if ≥70% of versions | 0.75 (0.69–0.80) | 0.56 (0.47–0.64) | 0.46 (0.37–0.54) |
| Persistence (rain now stays) | 0.52 (0.43–0.60) | 0.35 (0.24–0.44) | 0.26 (0.17–0.35) |

Rain caught / forecast rain that stayed dry:

| Forecast | 5–30 min | 35–60 min | 65–120 min |
|---|---|---|---|
| KNMI plain | 83% (79–87) / 11% (8–15) | 69% (61–75) / 26% (19–33) | 59% (50–66) / 37% (29–46) |
| Blend, rain if ≥30% of versions | 88% (84–91) / 15% (11–19) | 76% (69–82) / 31% (24–39) | 70% (63–77) / 42% (35–51) |
| Blend, rain if ≥50% of versions | 84% (79–88) / 11% (8–15) | 72% (64–78) / 26% (20–33) | 64% (55–71) / 35% (28–44) |
| Blend, rain if ≥70% of versions | 80% (74–85) / 8% (6–11) | 66% (57–73) / 21% (16–28) | 56% (47–64) / 28% (21–36) |
| Persistence (rain now stays) | 66% (57–73) / 29% (22–37) | 49% (37–59) / 46% (36–59) | 39% (27–50) / 56% (46–68) |

CSI difference from KNMI plain (positive means better than plain), with share of days where it was better:

| Forecast | 5–30 min | 35–60 min | 65–120 min |
|---|---|---|---|
| Blend, rain if ≥30% of versions | +0.005 (-0.010 to +0.022); better on 55% of days | +0.015 (-0.000 to +0.031); better on 70% of days | +0.031 (+0.013 to +0.050); better on 80% of days |
| Blend, rain if ≥50% of versions | +0.008 (-0.006 to +0.021); better on 62% of days | +0.022 (+0.009 to +0.036); better on 67% of days | +0.040 (+0.024 to +0.055); better on 77% of days |
| Blend, rain if ≥70% of versions | -0.008 (-0.027 to +0.007); better on 44% of days | +0.007 (-0.014 to +0.025); better on 58% of days | +0.027 (+0.006 to +0.045); better on 61% of days |
| Persistence (rain now stays) | -0.236 (-0.290 to -0.188); better on 6% of days | -0.209 (-0.252 to -0.170); better on 6% of days | -0.173 (-0.220 to -0.131); better on 12% of days |

### Showery (48 days)

| Forecast | 5–30 min: CSI | 35–60 min: CSI | 65–120 min: CSI |
|---|---|---|---|
| KNMI plain | 0.66 (0.61–0.71) | 0.41 (0.35–0.46) | 0.30 (0.24–0.36) |
| Blend, rain if ≥30% of versions | 0.66 (0.61–0.71) | 0.42 (0.36–0.48) | 0.33 (0.28–0.39) |
| Blend, rain if ≥50% of versions | 0.67 (0.62–0.72) | 0.43 (0.37–0.49) | 0.33 (0.27–0.40) |
| Blend, rain if ≥70% of versions | 0.64 (0.59–0.70) | 0.41 (0.35–0.48) | 0.32 (0.25–0.39) |
| Persistence (rain now stays) | 0.38 (0.32–0.45) | 0.17 (0.13–0.22) | 0.11 (0.08–0.15) |

Rain caught / forecast rain that stayed dry:

| Forecast | 5–30 min | 35–60 min | 65–120 min |
|---|---|---|---|
| KNMI plain | 76% (71–80) / 17% (13–21) | 55% (47–62) / 39% (33–45) | 45% (36–53) / 53% (46–61) |
| Blend, rain if ≥30% of versions | 82% (77–86) / 23% (18–27) | 64% (56–71) / 45% (39–51) | 60% (51–67) / 57% (51–64) |
| Blend, rain if ≥50% of versions | 77% (71–82) / 17% (13–20) | 59% (51–66) / 38% (32–45) | 50% (41–59) / 50% (42–58) |
| Blend, rain if ≥70% of versions | 71% (65–77) / 13% (10–17) | 52% (44–60) / 33% (27–39) | 42% (32–51) / 42% (35–51) |
| Persistence (rain now stays) | 54% (46–62) / 44% (37–50) | 29% (21–37) / 69% (63–76) | 19% (13–27) / 79% (72–85) |

CSI difference from KNMI plain (positive means better than plain), with share of days where it was better:

| Forecast | 5–30 min | 35–60 min | 65–120 min |
|---|---|---|---|
| Blend, rain if ≥30% of versions | +0.003 (-0.021 to +0.030); better on 54% of days | +0.013 (-0.005 to +0.033); better on 65% of days | +0.036 (+0.016 to +0.061); better on 75% of days |
| Blend, rain if ≥50% of versions | +0.013 (-0.008 to +0.033); better on 65% of days | +0.024 (+0.009 to +0.041); better on 62% of days | +0.038 (+0.018 to +0.059); better on 73% of days |
| Blend, rain if ≥70% of versions | -0.013 (-0.038 to +0.012); better on 44% of days | +0.007 (-0.012 to +0.027); better on 56% of days | +0.024 (-0.003 to +0.048); better on 56% of days |
| Persistence (rain now stays) | -0.276 (-0.328 to -0.223); better on 4% of days | -0.232 (-0.287 to -0.179); better on 8% of days | -0.184 (-0.255 to -0.122); better on 15% of days |

### Widespread (18 days)

| Forecast | 5–30 min: CSI | 35–60 min: CSI | 65–120 min: CSI |
|---|---|---|---|
| KNMI plain | 0.83 (0.77–0.88) | 0.68 (0.57–0.77) | 0.56 (0.45–0.67) |
| Blend, rain if ≥30% of versions | 0.84 (0.79–0.89) | 0.71 (0.61–0.79) | 0.60 (0.50–0.70) |
| Blend, rain if ≥50% of versions | 0.83 (0.78–0.88) | 0.70 (0.60–0.78) | 0.60 (0.50–0.70) |
| Blend, rain if ≥70% of versions | 0.82 (0.76–0.88) | 0.68 (0.57–0.77) | 0.58 (0.47–0.68) |
| Persistence (rain now stays) | 0.64 (0.50–0.75) | 0.51 (0.36–0.63) | 0.41 (0.28–0.52) |

Rain caught / forecast rain that stayed dry:

| Forecast | 5–30 min | 35–60 min | 65–120 min |
|---|---|---|---|
| KNMI plain | 89% (83–93) / 7% (4–10) | 78% (70–85) / 17% (10–26) | 69% (59–78) / 25% (15–36) |
| Blend, rain if ≥30% of versions | 92% (88–95) / 9% (6–13) | 85% (79–90) / 20% (12–28) | 78% (70–85) / 28% (18–38) |
| Blend, rain if ≥50% of versions | 89% (85–93) / 7% (5–11) | 82% (74–88) / 17% (10–26) | 74% (64–81) / 23% (15–33) |
| Blend, rain if ≥70% of versions | 86% (80–91) / 5% (3–8) | 76% (67–83) / 14% (8–21) | 67% (56–76) / 19% (11–28) |
| Persistence (rain now stays) | 74% (62–84) / 18% (11–27) | 64% (48–75) / 29% (19–43) | 54% (39–68) / 38% (29–51) |

CSI difference from KNMI plain (positive means better than plain), with share of days where it was better:

| Forecast | 5–30 min | 35–60 min | 65–120 min |
|---|---|---|---|
| Blend, rain if ≥30% of versions | +0.011 (-0.008 to +0.032); better on 56% of days | +0.028 (+0.011 to +0.049); better on 83% of days | +0.040 (+0.020 to +0.063); better on 94% of days |
| Blend, rain if ≥50% of versions | +0.003 (-0.015 to +0.020); better on 56% of days | +0.021 (+0.002 to +0.041); better on 78% of days | +0.040 (+0.019 to +0.061); better on 89% of days |
| Blend, rain if ≥70% of versions | -0.007 (-0.033 to +0.014); better on 44% of days | +0.003 (-0.033 to +0.033); better on 61% of days | +0.019 (-0.015 to +0.044); better on 72% of days |
| Persistence (rain now stays) | -0.192 (-0.282 to -0.120); better on 11% of days | -0.170 (-0.236 to -0.120); better on 0% of days | -0.156 (-0.223 to -0.098); better on 6% of days |

### Heavy cells (peak 50 mm/h or more) (10 days)

| Forecast | 5–30 min: CSI | 35–60 min: CSI | 65–120 min: CSI |
|---|---|---|---|
| KNMI plain | 0.69 (0.63–0.74) | 0.41 (0.30–0.54) | 0.37 (0.24–0.49) |
| Blend, rain if ≥30% of versions | 0.74 (0.66–0.79) | 0.48 (0.37–0.59) | 0.40 (0.28–0.51) |
| Blend, rain if ≥50% of versions | 0.73 (0.67–0.78) | 0.47 (0.36–0.59) | 0.41 (0.28–0.53) |
| Blend, rain if ≥70% of versions | 0.71 (0.64–0.76) | 0.45 (0.33–0.57) | 0.40 (0.26–0.53) |
| Persistence (rain now stays) | 0.35 (0.25–0.45) | 0.17 (0.09–0.24) | 0.12 (0.05–0.19) |

Rain caught / forecast rain that stayed dry:

| Forecast | 5–30 min | 35–60 min | 65–120 min |
|---|---|---|---|
| KNMI plain | 78% (71–84) / 14% (10–20) | 53% (41–65) / 36% (23–49) | 51% (36–64) / 43% (30–60) |
| Blend, rain if ≥30% of versions | 86% (80–90) / 16% (10–24) | 68% (56–78) / 37% (28–47) | 64% (50–76) / 49% (36–63) |
| Blend, rain if ≥50% of versions | 82% (76–87) / 14% (9–20) | 62% (49–73) / 34% (24–45) | 58% (44–71) / 42% (30–59) |
| Blend, rain if ≥70% of versions | 78% (71–83) / 11% (7–17) | 55% (42–68) / 30% (19–41) | 52% (36–66) / 35% (23–53) |
| Persistence (rain now stays) | 48% (35–61) / 43% (33–56) | 26% (14–37) / 68% (57–82) | 19% (7–31) / 74% (61–89) |

CSI difference from KNMI plain (positive means better than plain), with share of days where it was better:

| Forecast | 5–30 min | 35–60 min | 65–120 min |
|---|---|---|---|
| Blend, rain if ≥30% of versions | +0.047 (+0.004 to +0.085); better on 70% of days | +0.074 (+0.027 to +0.116); better on 100% of days | +0.032 (+0.010 to +0.055); better on 90% of days |
| Blend, rain if ≥50% of versions | +0.039 (+0.009 to +0.065); better on 80% of days | +0.059 (+0.019 to +0.091); better on 90% of days | +0.042 (+0.022 to +0.064); better on 90% of days |
| Blend, rain if ≥70% of versions | +0.020 (-0.015 to +0.050); better on 60% of days | +0.037 (-0.011 to +0.074); better on 50% of days | +0.036 (+0.014 to +0.054); better on 70% of days |
| Persistence (rain now stays) | -0.337 (-0.401 to -0.267); better on 0% of days | -0.242 (-0.377 to -0.131); better on 0% of days | -0.243 (-0.406 to -0.107); better on 0% of days |

### Summer (Jun–Aug) (24 days)

| Forecast | 5–30 min: CSI | 35–60 min: CSI | 65–120 min: CSI |
|---|---|---|---|
| KNMI plain | 0.70 (0.65–0.73) | 0.41 (0.34–0.46) | 0.32 (0.25–0.40) |
| Blend, rain if ≥30% of versions | 0.73 (0.68–0.76) | 0.45 (0.40–0.50) | 0.34 (0.27–0.42) |
| Blend, rain if ≥50% of versions | 0.72 (0.66–0.76) | 0.44 (0.39–0.49) | 0.35 (0.27–0.44) |
| Blend, rain if ≥70% of versions | 0.69 (0.62–0.74) | 0.43 (0.37–0.48) | 0.34 (0.25–0.43) |
| Persistence (rain now stays) | 0.36 (0.29–0.45) | 0.17 (0.12–0.23) | 0.12 (0.08–0.17) |

Rain caught / forecast rain that stayed dry:

| Forecast | 5–30 min | 35–60 min | 65–120 min |
|---|---|---|---|
| KNMI plain | 77% (71–82) / 12% (9–15) | 53% (44–61) / 36% (30–42) | 46% (35–55) / 48% (38–58) |
| Blend, rain if ≥30% of versions | 82% (77–87) / 14% (11–18) | 63% (55–70) / 38% (33–44) | 57% (47–66) / 53% (44–63) |
| Blend, rain if ≥50% of versions | 78% (72–83) / 11% (8–14) | 57% (50–64) / 34% (29–39) | 51% (40–62) / 46% (37–56) |
| Blend, rain if ≥70% of versions | 73% (66–79) / 8% (6–11) | 52% (45–59) / 29% (23–35) | 44% (33–55) / 39% (30–50) |
| Persistence (rain now stays) | 48% (39–58) / 40% (31–48) | 26% (18–35) / 67% (57–75) | 19% (12–26) / 73% (64–82) |

CSI difference from KNMI plain (positive means better than plain), with share of days where it was better:

| Forecast | 5–30 min | 35–60 min | 65–120 min |
|---|---|---|---|
| Blend, rain if ≥30% of versions | +0.029 (-0.003 to +0.060); better on 54% of days | +0.046 (+0.010 to +0.084); better on 75% of days | +0.024 (+0.008 to +0.040); better on 79% of days |
| Blend, rain if ≥50% of versions | +0.019 (-0.010 to +0.047); better on 58% of days | +0.035 (+0.010 to +0.061); better on 75% of days | +0.033 (+0.016 to +0.049); better on 75% of days |
| Blend, rain if ≥70% of versions | -0.008 (-0.045 to +0.024); better on 46% of days | +0.021 (-0.005 to +0.046); better on 62% of days | +0.021 (-0.006 to +0.046); better on 54% of days |
| Persistence (rain now stays) | -0.332 (-0.410 to -0.240); better on 12% of days | -0.237 (-0.323 to -0.147); better on 8% of days | -0.197 (-0.298 to -0.114); better on 8% of days |

### Autumn (Sep–Nov) (18 days)

| Forecast | 5–30 min: CSI | 35–60 min: CSI | 65–120 min: CSI |
|---|---|---|---|
| KNMI plain | 0.73 (0.63–0.78) | 0.52 (0.37–0.60) | 0.39 (0.25–0.49) |
| Blend, rain if ≥30% of versions | 0.72 (0.61–0.79) | 0.52 (0.37–0.62) | 0.47 (0.32–0.57) |
| Blend, rain if ≥50% of versions | 0.73 (0.62–0.79) | 0.54 (0.39–0.63) | 0.46 (0.30–0.56) |
| Blend, rain if ≥70% of versions | 0.70 (0.59–0.77) | 0.51 (0.35–0.60) | 0.41 (0.25–0.51) |
| Persistence (rain now stays) | 0.46 (0.32–0.55) | 0.31 (0.15–0.42) | 0.23 (0.11–0.33) |

Rain caught / forecast rain that stayed dry:

| Forecast | 5–30 min | 35–60 min | 65–120 min |
|---|---|---|---|
| KNMI plain | 80% (73–85) / 12% (7–19) | 64% (49–72) / 27% (19–42) | 51% (35–63) / 37% (27–56) |
| Blend, rain if ≥30% of versions | 86% (79–90) / 19% (12–30) | 72% (57–79) / 34% (24–50) | 69% (55–78) / 41% (32–57) |
| Blend, rain if ≥50% of versions | 82% (73–87) / 14% (9–23) | 67% (53–75) / 27% (17–42) | 59% (42–69) / 33% (25–49) |
| Blend, rain if ≥70% of versions | 76% (66–82) / 10% (6–18) | 59% (43–68) / 22% (13–37) | 48% (30–60) / 27% (18–44) |
| Persistence (rain now stays) | 60% (46–68) / 33% (24–50) | 44% (24–54) / 47% (33–72) | 34% (18–45) / 57% (43–77) |

CSI difference from KNMI plain (positive means better than plain), with share of days where it was better:

| Forecast | 5–30 min | 35–60 min | 65–120 min |
|---|---|---|---|
| Blend, rain if ≥30% of versions | -0.008 (-0.050 to +0.027); better on 50% of days | +0.006 (-0.021 to +0.032); better on 61% of days | +0.073 (+0.036 to +0.108); better on 78% of days |
| Blend, rain if ≥50% of versions | -0.001 (-0.041 to +0.028); better on 61% of days | +0.025 (-0.011 to +0.052); better on 61% of days | +0.062 (+0.017 to +0.094); better on 78% of days |
| Blend, rain if ≥70% of versions | -0.023 (-0.075 to +0.013); better on 44% of days | -0.010 (-0.068 to +0.028); better on 56% of days | +0.017 (-0.055 to +0.061); better on 56% of days |
| Persistence (rain now stays) | -0.266 (-0.345 to -0.207); better on 0% of days | -0.203 (-0.270 to -0.146); better on 6% of days | -0.161 (-0.267 to -0.065); better on 22% of days |

### Winter (Dec–Feb) (9 days)

| Forecast | 5–30 min: CSI | 35–60 min: CSI | 65–120 min: CSI |
|---|---|---|---|
| KNMI plain | 0.84 (0.66–0.93) | 0.68 (0.45–0.85) | 0.57 (0.34–0.76) |
| Blend, rain if ≥30% of versions | 0.83 (0.66–0.93) | 0.70 (0.47–0.85) | 0.57 (0.37–0.76) |
| Blend, rain if ≥50% of versions | 0.83 (0.66–0.93) | 0.71 (0.48–0.86) | 0.61 (0.38–0.79) |
| Blend, rain if ≥70% of versions | 0.82 (0.62–0.92) | 0.71 (0.47–0.86) | 0.62 (0.35–0.80) |
| Persistence (rain now stays) | 0.68 (0.45–0.85) | 0.51 (0.25–0.73) | 0.42 (0.17–0.62) |

Rain caught / forecast rain that stayed dry:

| Forecast | 5–30 min | 35–60 min | 65–120 min |
|---|---|---|---|
| KNMI plain | 92% (81–97) / 9% (3–22) | 81% (62–91) / 19% (7–40) | 75% (51–87) / 30% (13–52) |
| Blend, rain if ≥30% of versions | 92% (79–97) / 11% (4–22) | 87% (70–94) / 22% (8–43) | 84% (68–91) / 35% (17–57) |
| Blend, rain if ≥50% of versions | 90% (74–97) / 8% (3–18) | 84% (65–92) / 18% (6–38) | 78% (57–89) / 27% (11–49) |
| Blend, rain if ≥70% of versions | 87% (67–95) / 6% (2–15) | 81% (58–91) / 14% (4–31) | 73% (46–86) / 20% (7–43) |
| Persistence (rain now stays) | 81% (62–92) / 18% (7–38) | 67% (40–83) / 32% (13–61) | 60% (29–77) / 42% (24–72) |

CSI difference from KNMI plain (positive means better than plain), with share of days where it was better:

| Forecast | 5–30 min | 35–60 min | 65–120 min |
|---|---|---|---|
| Blend, rain if ≥30% of versions | -0.009 (-0.041 to +0.015); better on 33% of days | +0.014 (-0.002 to +0.046); better on 78% of days | +0.005 (-0.016 to +0.037); better on 100% of days |
| Blend, rain if ≥50% of versions | -0.004 (-0.035 to +0.018); better on 56% of days | +0.024 (+0.004 to +0.056); better on 67% of days | +0.041 (+0.015 to +0.074); better on 100% of days |
| Blend, rain if ≥70% of versions | -0.019 (-0.058 to -0.000); better on 22% of days | +0.032 (+0.007 to +0.059); better on 67% of days | +0.049 (-0.001 to +0.098); better on 89% of days |
| Persistence (rain now stays) | -0.155 (-0.292 to -0.061); better on 0% of days | -0.170 (-0.270 to -0.097); better on 0% of days | -0.153 (-0.200 to -0.105); better on 11% of days |

### Spring (Mar–May) (15 days)

| Forecast | 5–30 min: CSI | 35–60 min: CSI | 65–120 min: CSI |
|---|---|---|---|
| KNMI plain | 0.77 (0.65–0.84) | 0.64 (0.48–0.75) | 0.50 (0.34–0.64) |
| Blend, rain if ≥30% of versions | 0.78 (0.67–0.85) | 0.64 (0.47–0.76) | 0.52 (0.37–0.65) |
| Blend, rain if ≥50% of versions | 0.79 (0.68–0.85) | 0.65 (0.48–0.76) | 0.53 (0.37–0.66) |
| Blend, rain if ≥70% of versions | 0.78 (0.68–0.84) | 0.63 (0.46–0.74) | 0.53 (0.37–0.65) |
| Persistence (rain now stays) | 0.60 (0.41–0.72) | 0.43 (0.21–0.57) | 0.32 (0.13–0.48) |

Rain caught / forecast rain that stayed dry:

| Forecast | 5–30 min | 35–60 min | 65–120 min |
|---|---|---|---|
| KNMI plain | 85% (75–91) / 11% (7–18) | 78% (65–86) / 22% (13–36) | 67% (52–78) / 34% (20–51) |
| Blend, rain if ≥30% of versions | 90% (82–94) / 14% (9–23) | 85% (73–92) / 28% (17–44) | 76% (62–85) / 38% (23–55) |
| Blend, rain if ≥50% of versions | 87% (79–92) / 11% (7–17) | 81% (67–89) / 24% (14–39) | 71% (55–81) / 33% (20–49) |
| Blend, rain if ≥70% of versions | 85% (75–90) / 9% (5–14) | 75% (58–84) / 19% (12–32) | 65% (47–77) / 25% (15–39) |
| Persistence (rain now stays) | 76% (58–86) / 27% (17–43) | 62% (35–77) / 42% (29–66) | 51% (22–71) / 53% (38–77) |

CSI difference from KNMI plain (positive means better than plain), with share of days where it was better:

| Forecast | 5–30 min | 35–60 min | 65–120 min |
|---|---|---|---|
| Blend, rain if ≥30% of versions | +0.009 (-0.014 to +0.044); better on 73% of days | -0.000 (-0.023 to +0.022); better on 67% of days | +0.017 (-0.014 to +0.051); better on 73% of days |
| Blend, rain if ≥50% of versions | +0.014 (-0.003 to +0.043); better on 73% of days | +0.007 (-0.011 to +0.025); better on 60% of days | +0.028 (-0.002 to +0.058); better on 67% of days |
| Blend, rain if ≥70% of versions | +0.011 (-0.011 to +0.045); better on 53% of days | -0.006 (-0.045 to +0.029); better on 47% of days | +0.030 (+0.001 to +0.056); better on 60% of days |
| Persistence (rain now stays) | -0.175 (-0.274 to -0.103); better on 7% of days | -0.211 (-0.311 to -0.142); better on 7% of days | -0.180 (-0.272 to -0.105); better on 7% of days |

### CSI by lead time, all cases (95% interval for the blend minus plain difference)

| Lead (min) | KNMI plain | Blend ≥30% | Blend ≥50% | Blend ≥70% | Persistence | Blend ≥50% minus plain | Blend ≥30% minus plain |
|---|---|---|---|---|---|---|---|
| 5 | 0.864 | 0.832 | 0.821 | 0.803 | 0.734 | -0.043 (-0.073 to -0.018) | -0.033 (-0.063 to -0.008) |
| 10 | 0.808 | 0.825 | 0.828 | 0.811 | 0.582 | +0.020 (-0.006 to +0.048) | +0.017 (-0.010 to +0.046) |
| 15 | 0.771 | 0.761 | 0.760 | 0.761 | 0.507 | -0.010 (-0.044 to +0.020) | -0.010 (-0.045 to +0.024) |
| 20 | 0.731 | 0.746 | 0.754 | 0.747 | 0.475 | +0.024 (-0.001 to +0.051) | +0.016 (-0.015 to +0.050) |
| 25 | 0.703 | 0.712 | 0.723 | 0.702 | 0.450 | +0.020 (-0.007 to +0.048) | +0.010 (-0.018 to +0.039) |
| 30 | 0.668 | 0.696 | 0.696 | 0.662 | 0.407 | +0.028 (+0.004 to +0.052) | +0.028 (+0.002 to +0.055) |
| 35 | 0.608 | 0.635 | 0.620 | 0.600 | 0.383 | +0.012 (-0.009 to +0.034) | +0.027 (+0.004 to +0.054) |
| 40 | 0.584 | 0.593 | 0.601 | 0.586 | 0.363 | +0.017 (-0.005 to +0.040) | +0.009 (-0.013 to +0.032) |
| 45 | 0.558 | 0.578 | 0.582 | 0.574 | 0.346 | +0.024 (-0.001 to +0.050) | +0.020 (-0.002 to +0.044) |
| 50 | 0.545 | 0.569 | 0.575 | 0.551 | 0.341 | +0.030 (+0.005 to +0.055) | +0.024 (+0.000 to +0.049) |
| 55 | 0.509 | 0.531 | 0.553 | 0.534 | 0.320 | +0.045 (+0.018 to +0.069) | +0.022 (-0.003 to +0.049) |
| 60 | 0.526 | 0.516 | 0.533 | 0.528 | 0.321 | +0.007 (-0.020 to +0.034) | -0.009 (-0.039 to +0.021) |
| 65 | 0.485 | 0.488 | 0.505 | 0.510 | 0.299 | +0.020 (-0.006 to +0.048) | +0.003 (-0.017 to +0.025) |
| 70 | 0.466 | 0.485 | 0.492 | 0.484 | 0.284 | +0.026 (-0.000 to +0.052) | +0.019 (-0.008 to +0.047) |
| 75 | 0.465 | 0.496 | 0.500 | 0.477 | 0.294 | +0.035 (+0.007 to +0.063) | +0.030 (+0.003 to +0.061) |
| 80 | 0.469 | 0.493 | 0.500 | 0.484 | 0.288 | +0.031 (-0.001 to +0.060) | +0.023 (-0.004 to +0.053) |
| 85 | 0.483 | 0.494 | 0.522 | 0.502 | 0.285 | +0.039 (+0.011 to +0.067) | +0.011 (-0.013 to +0.037) |
| 90 | 0.444 | 0.478 | 0.499 | 0.489 | 0.280 | +0.054 (+0.024 to +0.085) | +0.033 (+0.004 to +0.069) |
| 95 | 0.430 | 0.476 | 0.483 | 0.474 | 0.262 | +0.052 (+0.026 to +0.079) | +0.046 (+0.014 to +0.080) |
| 100 | 0.417 | 0.455 | 0.460 | 0.454 | 0.243 | +0.043 (+0.016 to +0.068) | +0.038 (+0.006 to +0.069) |
| 105 | 0.406 | 0.450 | 0.460 | 0.437 | 0.247 | +0.055 (+0.025 to +0.086) | +0.044 (+0.011 to +0.078) |
| 110 | 0.407 | 0.434 | 0.446 | 0.429 | 0.236 | +0.039 (+0.014 to +0.067) | +0.027 (+0.002 to +0.053) |
| 115 | 0.392 | 0.449 | 0.444 | 0.422 | 0.227 | +0.053 (+0.029 to +0.075) | +0.057 (+0.031 to +0.086) |
| 120 | 0.377 | 0.409 | 0.406 | 0.398 | 0.218 | +0.030 (+0.004 to +0.054) | +0.032 (+0.003 to +0.060) |

### One forecast for the whole two hours, or a switch? CSI over all 5–120 min leads, all cases

| Show | CSI | Difference from plain only |
|---|---|---|
| plain only | 0.533 | +0.000 (+0.000 to +0.000) |
| plain to 30 min, then Blend, rain if ≥30% of versions | 0.548 | +0.015 (+0.003 to +0.028) |
| plain to 15 min, then Blend, rain if ≥30% of versions | 0.550 | +0.018 (+0.005 to +0.031) |
| plain to 5 min, then Blend, rain if ≥30% of versions | 0.551 | +0.019 (+0.005 to +0.033) |
| Blend, rain if ≥30% of versions only | 0.551 | +0.018 (+0.005 to +0.032) |
| plain only | 0.533 | +0.000 (+0.000 to +0.000) |
| plain to 30 min, then Blend, rain if ≥50% of versions | 0.560 | +0.027 (+0.017 to +0.037) |
| plain to 15 min, then Blend, rain if ≥50% of versions | 0.563 | +0.030 (+0.019 to +0.041) |
| plain to 5 min, then Blend, rain if ≥50% of versions | 0.563 | +0.030 (+0.018 to +0.041) |
| Blend, rain if ≥50% of versions only | 0.562 | +0.029 (+0.017 to +0.040) |

### Rain amount error (mm/h at the 48 places; mean bias, mean absolute error), all cases

| Forecast | 5–30 min | 35–60 min | 65–120 min |
|---|---|---|---|
| KNMI plain | bias -0.013, error 0.065 | bias -0.016, error 0.110 | bias -0.025, error 0.154 |
| Blend, mean of versions | bias -0.008, error 0.067 | bias -0.005, error 0.105 | bias -0.006, error 0.148 |
| Blend, median of versions | bias -0.020, error 0.064 | bias -0.025, error 0.098 | bias -0.042, error 0.130 |

Observed mean 0.146 mm/h; share of place-lead cells wet 17.1% observed, 15.9% plain, 16.6% blend ≥50%.

## Results: the newest blend file layout (issued 30 Aug 2026 or later)

These 30 days include the 20 extra days. The seasonal sample above holds only 10 of them.

### All cases from 30 Aug 2026 (30 days)

| Forecast | 5–30 min: CSI | 35–60 min: CSI | 65–120 min: CSI |
|---|---|---|---|
| KNMI plain | 0.77 (0.68–0.84) | 0.58 (0.42–0.71) | 0.45 (0.29–0.58) |
| Blend, rain if ≥30% of versions | 0.73 (0.61–0.82) | 0.56 (0.40–0.68) | 0.50 (0.36–0.61) |
| Blend, rain if ≥50% of versions | 0.73 (0.60–0.82) | 0.60 (0.43–0.72) | 0.51 (0.34–0.62) |
| Blend, rain if ≥70% of versions | 0.69 (0.53–0.80) | 0.56 (0.36–0.70) | 0.45 (0.24–0.59) |
| Persistence (rain now stays) | 0.56 (0.43–0.68) | 0.41 (0.24–0.55) | 0.37 (0.21–0.52) |

Rain caught / forecast rain that stayed dry:

| Forecast | 5–30 min | 35–60 min | 65–120 min |
|---|---|---|---|
| KNMI plain | 83% (76–88) / 9% (6–15) | 73% (58–82) / 25% (16–40) | 58% (40–69) / 32% (21–49) |
| Blend, rain if ≥30% of versions | 86% (75–93) / 17% (11–25) | 79% (64–88) / 34% (24–48) | 75% (63–83) / 41% (30–55) |
| Blend, rain if ≥50% of versions | 81% (68–89) / 11% (7–17) | 73% (56–84) / 23% (15–36) | 64% (46–75) / 29% (19–43) |
| Blend, rain if ≥70% of versions | 72% (57–83) / 6% (4–11) | 62% (40–76) / 13% (8–24) | 49% (26–64) / 15% (9–28) |
| Persistence (rain now stays) | 72% (60–81) / 28% (19–41) | 60% (41–73) / 44% (29–64) | 54% (34–69) / 46% (31–66) |

CSI difference from KNMI plain (positive means better than plain), with share of days where it was better:

| Forecast | 5–30 min | 35–60 min | 65–120 min |
|---|---|---|---|
| Blend, rain if ≥30% of versions | -0.034 (-0.080 to +0.002); better on 47% of days | -0.024 (-0.045 to -0.001); better on 47% of days | +0.041 (+0.001 to +0.096); better on 60% of days |
| Blend, rain if ≥50% of versions | -0.031 (-0.087 to +0.007); better on 47% of days | +0.013 (-0.012 to +0.034); better on 63% of days | +0.052 (+0.012 to +0.093); better on 67% of days |
| Blend, rain if ≥70% of versions | -0.075 (-0.151 to -0.026); better on 20% of days | -0.022 (-0.089 to +0.016); better on 40% of days | -0.007 (-0.075 to +0.039); better on 23% of days |
| Persistence (rain now stays) | -0.204 (-0.270 to -0.147); better on 7% of days | -0.177 (-0.223 to -0.134); better on 10% of days | -0.085 (-0.140 to -0.032); better on 23% of days |

### Showery (20 days)

| Forecast | 5–30 min: CSI | 35–60 min: CSI | 65–120 min: CSI |
|---|---|---|---|
| KNMI plain | 0.66 (0.60–0.71) | 0.37 (0.30–0.44) | 0.21 (0.16–0.27) |
| Blend, rain if ≥30% of versions | 0.61 (0.54–0.68) | 0.36 (0.30–0.42) | 0.27 (0.22–0.32) |
| Blend, rain if ≥50% of versions | 0.62 (0.53–0.70) | 0.39 (0.31–0.46) | 0.26 (0.19–0.32) |
| Blend, rain if ≥70% of versions | 0.55 (0.46–0.64) | 0.32 (0.23–0.40) | 0.18 (0.12–0.24) |
| Persistence (rain now stays) | 0.36 (0.28–0.43) | 0.17 (0.11–0.22) | 0.14 (0.10–0.17) |

Rain caught / forecast rain that stayed dry:

| Forecast | 5–30 min | 35–60 min | 65–120 min |
|---|---|---|---|
| KNMI plain | 74% (69–78) / 15% (11–19) | 51% (40–61) / 43% (37–49) | 30% (23–38) / 59% (51–67) |
| Blend, rain if ≥30% of versions | 84% (75–90) / 31% (25–38) | 65% (51–76) / 55% (50–61) | 55% (44–64) / 65% (59–70) |
| Blend, rain if ≥50% of versions | 75% (65–83) / 22% (16–29) | 56% (43–67) / 43% (37–50) | 38% (26–48) / 54% (47–61) |
| Blend, rain if ≥70% of versions | 61% (50–69) / 14% (9–22) | 38% (26–48) / 33% (25–41) | 21% (13–28) / 40% (32–49) |
| Persistence (rain now stays) | 53% (43–62) / 48% (40–56) | 30% (20–40) / 73% (66–80) | 26% (17–35) / 78% (72–83) |

CSI difference from KNMI plain (positive means better than plain), with share of days where it was better:

| Forecast | 5–30 min | 35–60 min | 65–120 min |
|---|---|---|---|
| Blend, rain if ≥30% of versions | -0.045 (-0.090 to -0.003); better on 45% of days | -0.007 (-0.042 to +0.023); better on 45% of days | +0.061 (+0.020 to +0.107); better on 50% of days |
| Blend, rain if ≥50% of versions | -0.035 (-0.094 to +0.013); better on 45% of days | +0.024 (-0.008 to +0.052); better on 65% of days | +0.049 (+0.012 to +0.084); better on 70% of days |
| Blend, rain if ≥70% of versions | -0.102 (-0.176 to -0.048); better on 20% of days | -0.050 (-0.107 to -0.000); better on 40% of days | -0.028 (-0.074 to +0.018); better on 25% of days |
| Persistence (rain now stays) | -0.297 (-0.364 to -0.238); better on 0% of days | -0.199 (-0.268 to -0.136); better on 5% of days | -0.075 (-0.121 to -0.035); better on 20% of days |

### Widespread (10 days)

| Forecast | 5–30 min: CSI | 35–60 min: CSI | 65–120 min: CSI |
|---|---|---|---|
| KNMI plain | 0.83 (0.72–0.91) | 0.72 (0.53–0.85) | 0.59 (0.41–0.72) |
| Blend, rain if ≥30% of versions | 0.82 (0.65–0.91) | 0.72 (0.52–0.84) | 0.66 (0.50–0.77) |
| Blend, rain if ≥50% of versions | 0.81 (0.62–0.91) | 0.73 (0.53–0.85) | 0.65 (0.47–0.77) |
| Blend, rain if ≥70% of versions | 0.77 (0.56–0.89) | 0.71 (0.44–0.85) | 0.58 (0.32–0.72) |
| Persistence (rain now stays) | 0.70 (0.55–0.83) | 0.58 (0.37–0.76) | 0.53 (0.32–0.71) |

Rain caught / forecast rain that stayed dry:

| Forecast | 5–30 min | 35–60 min | 65–120 min |
|---|---|---|---|
| KNMI plain | 88% (81–93) / 7% (3–14) | 84% (71–92) / 17% (7–34) | 71% (54–81) / 22% (11–39) |
| Blend, rain if ≥30% of versions | 87% (69–96) / 7% (4–11) | 86% (69–95) / 19% (10–33) | 85% (75–91) / 26% (14–41) |
| Blend, rain if ≥50% of versions | 84% (65–94) / 5% (2–8) | 82% (61–93) / 13% (6–22) | 76% (58–86) / 18% (10–29) |
| Blend, rain if ≥70% of versions | 79% (57–91) / 3% (1–4) | 74% (46–88) / 6% (2–10) | 62% (34–77) / 10% (4–16) |
| Persistence (rain now stays) | 82% (71–90) / 17% (8–30) | 75% (58–86) / 28% (13–49) | 67% (46–82) / 28% (14–50) |

CSI difference from KNMI plain (positive means better than plain), with share of days where it was better:

| Forecast | 5–30 min | 35–60 min | 65–120 min |
|---|---|---|---|
| Blend, rain if ≥30% of versions | -0.013 (-0.089 to +0.034); better on 50% of days | -0.000 (-0.026 to +0.021); better on 50% of days | +0.066 (+0.020 to +0.142); better on 80% of days |
| Blend, rain if ≥50% of versions | -0.023 (-0.111 to +0.025); better on 50% of days | +0.017 (-0.019 to +0.036); better on 60% of days | +0.059 (+0.002 to +0.118); better on 60% of days |
| Blend, rain if ≥70% of versions | -0.058 (-0.176 to +0.001); better on 20% of days | -0.010 (-0.109 to +0.034); better on 40% of days | -0.011 (-0.107 to +0.045); better on 20% of days |
| Persistence (rain now stays) | -0.128 (-0.204 to -0.061); better on 20% of days | -0.134 (-0.186 to -0.081); better on 20% of days | -0.059 (-0.145 to +0.018); better on 30% of days |

### CSI by lead time, all cases (95% interval for the blend minus plain difference)

| Lead (min) | KNMI plain | Blend ≥30% | Blend ≥50% | Blend ≥70% | Persistence | Blend ≥50% minus plain | Blend ≥30% minus plain |
|---|---|---|---|---|---|---|---|
| 5 | 0.863 | 0.805 | 0.812 | 0.761 | 0.762 | -0.051 (-0.135 to +0.005) | -0.059 (-0.134 to -0.006) |
| 10 | 0.828 | 0.783 | 0.774 | 0.752 | 0.624 | -0.054 (-0.149 to +0.015) | -0.045 (-0.130 to +0.023) |
| 15 | 0.779 | 0.725 | 0.736 | 0.701 | 0.567 | -0.043 (-0.130 to +0.022) | -0.054 (-0.140 to +0.013) |
| 20 | 0.742 | 0.708 | 0.727 | 0.676 | 0.526 | -0.015 (-0.062 to +0.028) | -0.034 (-0.088 to +0.014) |
| 25 | 0.713 | 0.718 | 0.709 | 0.653 | 0.489 | -0.004 (-0.047 to +0.031) | +0.004 (-0.035 to +0.040) |
| 30 | 0.680 | 0.664 | 0.656 | 0.603 | 0.437 | -0.024 (-0.072 to +0.015) | -0.015 (-0.061 to +0.029) |
| 35 | 0.587 | 0.633 | 0.634 | 0.576 | 0.419 | +0.047 (+0.009 to +0.090) | +0.046 (+0.012 to +0.088) |
| 40 | 0.586 | 0.561 | 0.582 | 0.557 | 0.412 | -0.003 (-0.050 to +0.034) | -0.025 (-0.057 to +0.008) |
| 45 | 0.629 | 0.580 | 0.620 | 0.581 | 0.416 | -0.009 (-0.049 to +0.025) | -0.049 (-0.085 to -0.015) |
| 50 | 0.591 | 0.560 | 0.606 | 0.550 | 0.400 | +0.015 (-0.024 to +0.049) | -0.031 (-0.068 to +0.006) |
| 55 | 0.569 | 0.527 | 0.594 | 0.565 | 0.393 | +0.026 (-0.018 to +0.061) | -0.042 (-0.087 to +0.003) |
| 60 | 0.548 | 0.509 | 0.552 | 0.547 | 0.407 | +0.004 (-0.043 to +0.044) | -0.039 (-0.087 to +0.004) |
| 65 | 0.547 | 0.525 | 0.562 | 0.528 | 0.406 | +0.015 (-0.036 to +0.061) | -0.022 (-0.070 to +0.027) |
| 70 | 0.499 | 0.518 | 0.532 | 0.490 | 0.393 | +0.033 (-0.004 to +0.065) | +0.019 (-0.022 to +0.071) |
| 75 | 0.504 | 0.535 | 0.555 | 0.482 | 0.394 | +0.051 (+0.006 to +0.093) | +0.032 (-0.019 to +0.086) |
| 80 | 0.490 | 0.548 | 0.555 | 0.476 | 0.373 | +0.065 (+0.003 to +0.118) | +0.058 (+0.006 to +0.119) |
| 85 | 0.477 | 0.498 | 0.522 | 0.482 | 0.363 | +0.046 (-0.006 to +0.092) | +0.021 (-0.025 to +0.072) |
| 90 | 0.468 | 0.522 | 0.532 | 0.470 | 0.361 | +0.064 (+0.024 to +0.099) | +0.055 (+0.011 to +0.106) |
| 95 | 0.467 | 0.510 | 0.505 | 0.489 | 0.365 | +0.038 (-0.012 to +0.076) | +0.042 (+0.003 to +0.085) |
| 100 | 0.420 | 0.486 | 0.489 | 0.439 | 0.352 | +0.068 (+0.004 to +0.121) | +0.066 (+0.017 to +0.133) |
| 105 | 0.408 | 0.487 | 0.510 | 0.431 | 0.370 | +0.102 (+0.026 to +0.177) | +0.079 (+0.018 to +0.162) |
| 110 | 0.415 | 0.378 | 0.392 | 0.308 | 0.356 | -0.023 (-0.239 to +0.147) | -0.038 (-0.229 to +0.120) |
| 115 | 0.404 | 0.504 | 0.493 | 0.426 | 0.357 | +0.089 (+0.005 to +0.166) | +0.100 (+0.021 to +0.190) |
| 120 | 0.375 | 0.448 | 0.447 | 0.371 | 0.350 | +0.072 (-0.059 to +0.167) | +0.074 (-0.041 to +0.166) |

### One forecast for the whole two hours, or a switch? CSI over all 5–120 min leads, all cases

| Show | CSI | Difference from plain only |
|---|---|---|
| plain only | 0.557 | +0.000 (+0.000 to +0.000) |
| plain to 30 min, then Blend, rain if ≥30% of versions | 0.565 | +0.008 (-0.017 to +0.042) |
| plain to 15 min, then Blend, rain if ≥30% of versions | 0.565 | +0.008 (-0.018 to +0.043) |
| plain to 5 min, then Blend, rain if ≥30% of versions | 0.563 | +0.006 (-0.020 to +0.041) |
| Blend, rain if ≥30% of versions only | 0.562 | +0.005 (-0.022 to +0.040) |
| plain only | 0.557 | +0.000 (+0.000 to +0.000) |
| plain to 30 min, then Blend, rain if ≥50% of versions | 0.588 | +0.031 (+0.007 to +0.055) |
| plain to 15 min, then Blend, rain if ≥50% of versions | 0.587 | +0.030 (+0.004 to +0.056) |
| plain to 5 min, then Blend, rain if ≥50% of versions | 0.584 | +0.026 (-0.001 to +0.053) |
| Blend, rain if ≥50% of versions only | 0.582 | +0.025 (-0.005 to +0.052) |

### Rain amount error (mm/h at the 48 places; mean bias, mean absolute error), all cases

| Forecast | 5–30 min | 35–60 min | 65–120 min |
|---|---|---|---|
| KNMI plain | bias -0.026, error 0.098 | bias -0.013, error 0.152 | bias -0.058, error 0.211 |
| Blend, mean of versions | bias -0.016, error 0.124 | bias +0.005, error 0.157 | bias -0.027, error 0.195 |
| Blend, median of versions | bias -0.056, error 0.114 | bias -0.063, error 0.131 | bias -0.107, error 0.162 |

Observed mean 0.222 mm/h; share of place-lead cells wet 21.3% observed, 19.1% plain, 19.4% blend ≥50%.

## Cases in the seasonal sample

Times are UTC. "Wet cells" counts places × lead times that were wet, out of 1,152.

| Day | Issue (UTC) | Class | Wet cells of 1152 | Dutch box wet share | Peak mm/h in box |
|---|---|---|---|---|---|
| 20250416 | 19:30 | widespread | 331 | 0.31 | 10 |
| 20250418 | 09:30 | showery | 70 | 0.07 | 1 |
| 20250420 | 23:30 | widespread | 324 | 0.28 | 18 |
| 20250504 | 22:00 | showery | 58 | 0.03 | 4 |
| 20250525 | 13:00 | showery | 131 | 0.11 | 39 |
| 20250529 | 09:00 | widespread | 586 | 0.51 | 4 |
| 20250608 | 12:00 | widespread | 316 | 0.28 | 60 |
| 20250609 | 01:30 | widespread | 260 | 0.22 | 17 |
| 20250610 | 12:00 | showery | 68 | 0.07 | 18 |
| 20250624 | 11:30 | showery | 72 | 0.07 | 3 |
| 20250704 | 00:00 | showery | 127 | 0.10 | 3 |
| 20250719 | 18:30 | widespread | 233 | 0.22 | 59 |
| 20250720 | 19:30 | showery | 65 | 0.06 | 93 |
| 20250726 | 18:00 | showery | 138 | 0.10 | 10 |
| 20250804 | 14:00 | widespread | 315 | 0.27 | 5 |
| 20250807 | 14:00 | showery | 64 | 0.05 | 4 |
| 20250811 | 05:30 | showery | 88 | 0.06 | 33 |
| 20250822 | 19:00 | showery | 90 | 0.08 | 15 |
| 20250914 | 04:30 | showery | 80 | 0.07 | 61 |
| 20250919 | 01:30 | showery | 124 | 0.10 | 5 |
| 20250926 | 23:30 | showery | 109 | 0.12 | 9 |
| 20251017 | 08:30 | showery | 65 | 0.05 | 15 |
| 20251019 | 22:30 | widespread | 714 | 0.60 | 7 |
| 20251031 | 16:30 | showery | 202 | 0.17 | 6 |
| 20251108 | 03:30 | showery | 62 | 0.06 | 8 |
| 20251118 | 02:00 | widespread | 617 | 0.50 | 27 |
| 20251123 | 10:30 | widespread | 322 | 0.26 | 8 |
| 20251205 | 05:00 | widespread | 253 | 0.23 | 11 |
| 20251207 | 16:30 | widespread | 1039 | 0.90 | 13 |
| 20251218 | 22:30 | showery | 142 | 0.11 | 1 |
| 20260105 | 17:30 | showery | 206 | 0.18 | 70 |
| 20260114 | 04:00 | showery | 132 | 0.12 | 9 |
| 20260115 | 15:30 | widespread | 283 | 0.26 | 6 |
| 20260203 | 01:30 | showery | 78 | 0.07 | 8 |
| 20260218 | 23:00 | showery | 177 | 0.15 | 5 |
| 20260220 | 06:00 | showery | 95 | 0.08 | 2 |
| 20260313 | 09:00 | widespread | 820 | 0.72 | 26 |
| 20260325 | 20:30 | widespread | 248 | 0.22 | 24 |
| 20260329 | 13:30 | showery | 141 | 0.13 | 3 |
| 20260402 | 04:30 | showery | 192 | 0.16 | 1 |
| 20260413 | 11:00 | showery | 70 | 0.06 | 1 |
| 20260418 | 08:30 | showery | 136 | 0.11 | 10 |
| 20260510 | 04:00 | showery | 136 | 0.14 | 6 |
| 20260516 | 22:30 | widespread | 262 | 0.22 | 14 |
| 20260529 | 14:00 | widespread | 245 | 0.21 | 192 |
| 20260603 | 13:00 | showery | 243 | 0.20 | 98 |
| 20260612 | 15:30 | showery | 81 | 0.07 | 54 |
| 20260618 | 16:00 | showery | 108 | 0.09 | 11 |
| 20260622 | 00:30 | showery | 66 | 0.06 | 6 |
| 20260715 | 06:00 | showery | 87 | 0.09 | 48 |
| 20260721 | 05:00 | showery | 67 | 0.06 | 4 |
| 20260726 | 05:30 | showery | 107 | 0.08 | 41 |
| 20260727 | 10:30 | showery | 112 | 0.10 | 58 |
| 20260804 | 16:00 | showery | 162 | 0.13 | 111 |
| 20260806 | 06:00 | showery | 92 | 0.07 | 22 |
| 20260815 | 09:00 | showery | 136 | 0.15 | 35 |
| 20260830 | 12:00 | showery | 136 | 0.12 | 24 |
| 20260903 | 03:00 | showery | 128 | 0.11 | 27 |
| 20260923 | 18:30 | showery | 81 | 0.07 | 28 |
| 20260930 | 15:00 | widespread | 342 | 0.29 | 11 |
| 20261013 | 13:00 | showery | 190 | 0.16 | 27 |
| 20261017 | 17:00 | showery | 96 | 0.09 | 26 |
| 20261021 | 15:00 | showery | 131 | 0.11 | 5 |
| 20261102 | 17:30 | showery | 135 | 0.10 | 14 |
| 20261107 | 20:30 | showery | 82 | 0.06 | 11 |
| 20261112 | 18:00 | showery | 123 | 0.09 | 23 |

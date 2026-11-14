Written by AI on 2026.11.14 by model claude opus 5.5.

# Europe: what beats WeatherKit, and what WeatherKit costs

## Answer

**Radar beats WeatherKit everywhere in Europe except, possibly, the UK and Ireland.** Outside those two countries WeatherKit has no minute forecast, only hourly. An hourly forecast cannot say "rain in 20 minutes", and on the rainy cases scored here, in seven countries, a national radar nowcast was far better than the best hourly model forecast for the first half hour and still better up to an hour. In the second hour the two were level, with the model a little ahead in some places.

**WeatherKit is not paid per user.** Josh's developer account gets 500,000 calls a month free, shared by all his apps. Beyond that Apple refuses calls until he buys a monthly plan, from $49.99 for 1 million calls. At 44 to 70 widget refreshes a day, one call each, the free calls serve **234 to 373 users who all use WeatherKit**. We may not fetch once and share the result between users through our server.

**What to do:**
1. Add **DWD** (Germany and its neighbours) and **MET Norway** (Norway, Sweden, Finland) to our server, next to KNMI. Both are free and open, need no sign-up, and were scored here. That takes most of northern and central Europe off WeatherKit.
2. **France:** use Météo-France's PIAF nowcast. It needs a free account in Josh's name, so it could not be scored yet.
3. **UK and Ireland:** WeatherKit's minute forecast at launch. Whether a radar source beats it there can only be found by recording WeatherKit for a few weeks (section 4).
4. **Spain, Italy, everywhere else:** WeatherKit hourly at launch. OPERA, Europe's radar composite, is still under investigation (`research/opera-check.md`).
5. **WeatherKit on the watch:** at most one call per refresh, both datasets in one request, and the hourly forecast at most once an hour where there is no minute forecast. Never through our server.

## 1. Per country

"Step / horizon / delay" is the time between forecast steps, how far ahead it goes, and how long after the radar time the forecast is published. Delays marked "measured" are from today's file listings (median of the last day).

| Country | Best free 2-hour source | Licence, use in an app | Step / horizon / delay | Grid | WeatherKit there | Scored here | Recommendation |
|---|---|---|---|---|---|---|---|
| Netherlands | KNMI radar forecast and blend | CC BY 4.0, "Source: KNMI" | 5 min / 2 h / 1.5 min | 1 km | hourly only | 86 cases, 78 days | KNMI (as planned) |
| Belgium, Luxembourg | KNMI: its picture uses the three Belgian radars | as above | as above | 1 km | hourly only | no (Dutch places only) | KNMI |
| Germany | DWD RV composite | GeoNutzV: free, commercial use allowed, credit "Deutscher Wetterdienst" | 5 min / 2 h / **3 min measured** | 1 km | hourly only | 16 cases, one night | **DWD** |
| Austria | GeoSphere INCA nowcast; DWD RV also covers most of Austria | CC BY 4.0, no key | INCA 15 min / 3 h / 5 to 10 min | 1 km | hourly only | DWD: 24 cases. INCA: no archive | DWD now; INCA after a recorded comparison |
| Switzerland | DWD RV in the north. MeteoSwiss gives its own nowcast (INCA-CH) only on request | DWD as above | DWD as above | 1 km | hourly only | DWD: 18 cases | DWD where it covers, else WeatherKit hourly |
| Denmark | MET Norway (Swedish radars) and DWD (south of 55.9° N). DMI publishes radar but no nowcast | CC BY 4.0 | see Norway and Germany | 1 km | hourly only | 2 and 6 cases, too few | MET Norway, then DWD |
| Norway, Sweden, Finland | MET Norway radar nowcast: a 1 km Nordic grid on its THREDDS server, and a point API | CC BY 4.0 and NLOD, credit "MET Norway" | 5 min / **1 h 55** / **5.8 min measured** | 1 km | hourly only | 28, 38 and 86 cases | **MET Norway** |
| France | Météo-France PIAF: radar nowcast merged with the AROME model | Météo-France's public data are under Licence Ouverte 2.0 (Etalab), commercial use allowed; PIAF's own listing names no licence, so check at sign-up. Free account and key, 100 requests a minute | 5 min / 3 h 15 / about 10 min | 0.01° (about 1 km) | hourly only | no: needs an account, keeps 3 to 5 days | **PIAF**, after Josh opens the account and we record it |
| UK | No open nowcast. Met Office radar on AWS: rain rate, kept 2 years | CC BY-SA 4.0: what we derive must carry the same licence | radar every 15 min, "within 20 minutes" (5.5 min measured on 14 Nov) | 1 km | **minute by minute, 1 h** | no: WeatherKit keeps no archive | WeatherKit minute; record to decide |
| Ireland | No open nowcast. Met Éireann radar composites, the last 3 hours without sign-up | CC BY 4.0, five credit lines | radar only | 1 km | **minute by minute, 1 h** | no | WeatherKit minute; record to decide |
| Spain | AEMET radar images only (PNG, every 10 to 30 min), key needs a free sign-up | CC BY 4.0 | no nowcast | images | hourly only | no | WeatherKit hourly |
| Italy | Radar-DPC rain-rate mosaic, open API, no key | CC BY-SA 4.0 | radar every 5 min, no nowcast | 1 km | hourly only | no | WeatherKit hourly; our own extrapolation later |

Corrections to `research/global-data.md`, which was written this morning:
- MET Norway's nowcast is not "point only". The full 1 km grid is on `thredds.met.no/thredds/catalog/radarnowcasting/`, one 93 MB file every 5 minutes, kept for 48 hours. Its horizon is 1 h 55, not 2 h.
- France has a better product than AROME-PI: **PIAF**, 5-minute steps from 5 to 195 minutes, a new run every 5 minutes, about 10 minutes late.
- The Met Office's AWS radar is now a 2-year rolling archive, which makes UK scoring possible.
- api.met.no's terms (revised 5 November 2026) require "a human in authority" to read and accept them when AI tools write the code. If the server uses that API, Josh must accept them; the THREDDS files used here are a separate service.
- DMI no longer needs a sign-up (since 2 December 2025), but has no nowcast.

## 2. The measurements

### Method

The same method as the season test (`research/verification/season.md`): at each place and 5-minute step, the forecast says wet or dry (wet is 0.1 mm/h or more), and the truth is the service's own observed radar at that time. CSI is hits over hits plus misses plus false alarms; 1 is perfect.

Four forecasts are compared on the same cases:
- **Radar nowcast:** the national service's own forecast.
- **Rain stays as it is:** the rain at the start of the forecast simply stays.
- **Perfect hourly forecast:** knows each clock hour's real average rain and calls the whole hour wet if it is 0.1 mm/h or more. No real forecast can do this; it is about the best that any hourly forecast, WeatherKit's included, could score on a 5-minute line.
- **Real hourly models:** archived hourly forecasts from Open-Meteo, from each model's latest run, as a stand-in for WeatherKit's hourly data. The models are ICON-D2 (DWD), KNMI's and MET Norway's own, and ECMWF. Each is shown at its best rain threshold (0.1, 0.2 or 0.5 mm in the hour), chosen afterwards, which favours the models.

Cases: the Netherlands uses the 86 rainy cases of the season test (April 2025 to November 2026). DWD and MET Norway keep only 48 hours, so their cases are the rainy issue times on the half hour from 12 to 14 November: places on a 10 km lattice, a case counting when at least 5% of its place-steps were wet. The model comparison uses 150 of the lattice places in each country.

### Results

CSI. "Best hourly model" is the model and threshold with the best score over the whole two hours.

| Country (cases) | Forecast | 5 to 30 min | 35 to 60 min | 65 to 120 min |
|---|---|---|---|---|
| Netherlands (86) | KNMI plain forecast | **0.77** | **0.58** | 0.46 |
| | Best hourly model (ICON-D2) | 0.42 | 0.44 | **0.47** |
| | Perfect hourly forecast | 0.63 | 0.61 | 0.64 |
| Germany (16) | DWD nowcast | **0.85** | **0.72** | 0.61 |
| | Best hourly model (ICON-D2) | 0.70 | 0.70 | **0.70** |
| | Perfect hourly forecast | 0.82 | 0.77 | 0.77 |
| Austria (24) | DWD nowcast | **0.87** | **0.77** | 0.68 |
| | Best hourly model (ICON-D2) | 0.73 | 0.72 | **0.70** |
| Switzerland (18) | DWD nowcast | **0.80** | **0.65** | **0.54** |
| | Best hourly model (ECMWF) | 0.56 | 0.54 | 0.51 |
| Norway (28) | MET Norway nowcast | **0.55** | **0.30** | 0.17 |
| | Best hourly model (ECMWF) | 0.26 | 0.26 | **0.27** |
| Sweden (38) | MET Norway nowcast | **0.61** | **0.41** | **0.28** |
| | Best hourly model (MET Norway) | 0.26 | 0.26 | 0.25 |
| Finland (86) | MET Norway nowcast | **0.76** | **0.60** | 0.49 |
| | Best hourly model (MET Norway) | 0.51 | 0.51 | **0.51** |

The rows for DWD and MET Norway are on the 150 sampled places; on the whole lattice the nowcast scores are within 0.04 of these. Full output, with "rain stays as it is", every model and every threshold: `research/verification/europe_check.md`.

**Netherlands, with uncertainty** (78 days, resampled 4,000 times): KNMI minus the best model is +0.34 (+0.28 to +0.40) for 5 to 30 minutes, +0.14 (+0.10 to +0.18) for 35 to 60, and −0.01 (−0.04 to +0.03) for 65 to 120. So KNMI's plain forecast is clearly better for the first hour and level in the second. The season test's blend scores 0.48 in the second hour, so the line BuienWatch will show is at least level with the model there too.

What this shows:
- **First hour: radar wins everywhere, by a lot.** Up to 30 minutes ahead, every nowcast beat the best model by 0.14 to 0.35. In the Netherlands, Germany and Norway it beat even the impossible perfect hourly forecast.
- **Second hour: a draw.** The model was ahead in Germany (0.70 against 0.61) and Norway; level in the Netherlands, Austria and Finland; behind in Switzerland and Sweden.
- **MET Norway's nowcast is weak after 30 minutes in Norway** (0.30, then 0.17), worse than "rain stays as it is" in the second hour. Mountains block the radar and showers form and die fast. It still beats every hourly model in the first hour.

How far to trust it:
- Only the Netherlands has a season of cases. Germany, Austria and Switzerland are one night of widespread rain (12 to 13 November); the Nordics are two days of showers. These say the pattern holds in other countries; they do not give its size to two decimals.
- Truth is each service's own radar, which favours its own nowcast: radar errors such as clutter count against the models only. KNMI's truth is corrected with rain gauges; DWD's and MET Norway's are not.
- The models stand in for WeatherKit's hourly data. Apple does not say what its forecast is built from; it lists DWD, ECMWF, the Met Office and others as data sources. If Apple's hourly forecast were as good as the perfect hourly forecast, it would still lose the first 30 minutes in the Netherlands and Germany.

## 3. What WeatherKit costs, and why

From Apple's WeatherKit page (read today) and the Apple Developer Program License Agreement on Apple's site today, which is what Josh accepted on 14 November.

**Who pays.** Nobody, until the account uses 500,000 calls in a month. The 500,000 are "per Apple Developer Program membership", shared by every app on the account, and count calls from development, TestFlight and the store alike (Apple staff on the forums). Above that, Apple refuses further calls until the month ends (developers report an `OVER_QUOTA` error); Apple's pages describe no automatic billing. Only the Account Holder (Josh) can buy more, in the Account tab of the Apple Developer app, as a monthly subscription that renews until cancelled (Attachment 9). Billing is by Apple Distribution International in Ireland, in US dollars or local currency. A plan replaces the free 500,000; it does not add to it.

| Calls a month | Price a month |
|---|---|
| 500,000 | included |
| 1 million | $49.99 |
| 2 million | $99.99 |
| 5 million | $249.99 |
| 10 million | $499.99 |

Upgrading starts a new billing period at once and resets the count to 0; downgrading takes effect at the next billing date. Unused calls do not roll over.

**What counts as one call.** Apple does not say. Its pages count "API calls" and publish no rule for a request that asks for several datasets. A watch request for both the minute and the hourly forecast is one HTTPS request to Apple, so it is probably one call, but it may be counted as two. The figures below give both. Recording (section 4) would settle it, by comparing the calls we make with the count Apple shows.

**Calls per user.** One call per widget refresh. A month is 30.4 days.

| Refreshes a day | Calls a user a month | Users in 500,000, one call each | Users, if each dataset counts |
|---|---|---|---|
| 44 (Josh's watch log) | 1,338 | 373 | 186 |
| 57 | 1,734 | 288 | 144 |
| 70 | 2,129 | 234 | 117 |

Where WeatherKit has only hourly data, nothing changes between refreshes within the hour, so the watch can keep the hourly forecast until it expires and call at most once an hour: 730 calls a month at 24 an hour-long day, 487 if the watch sleeps 8 hours. That is **684 to 1,027 users** in 500,000.

**May our server fetch once and share it between users? No.** Attachment 8:
- 1.5: no use "that enables or permits bulk downloads or feeds" of Apple Weather Data, and no use of it "as part of any secondary or derived database".
- 1.6: Apple Weather Data "may not be cached, pre-fetched, or stored" except "on a temporary and limited basis solely to improve the performance of the WeatherKit APIs with Your Application".
- 1.2: no sublicensing of the data in its original form.

A server that fetches a forecast for one square and hands it to everyone in that square is a feed and a shared store, kept to save calls, not for performance. Apple may limit, suspend or revoke WeatherKit for the whole account if it believes the terms are broken (3.2). Caching on the watch until the data's expiry time is within 1.6. 1.2 does allow "value-added" products, data transformed so the original cannot be recovered, shown with "Weather" and a note that it was modified; that still does not allow a shared server cache.

Other terms that apply to RainWatch:
- Show the Apple Weather mark and the legal link on every screen with its data.
- The app may not be "designed or marketed for emergency or life-saving purposes" (1.3).
- The app's licence for its users needs the notice in 2.2, starting "YOUR USE OF THIS REAL TIME WEATHER GUIDANCE APPLICATION OR WEBSITE IS AT YOUR SOLE RISK".
- RainWatch is free, so 1.2's ban on charging for Apple's data does not bite.

**The design that stays inside 500,000, and how far it goes.**
1. Europe outside the UK and Ireland on our server (KNMI, DWD, MET Norway, later PIAF): no WeatherKit calls at all.
2. UK and Ireland: one request per refresh for the minute and hourly forecasts together. **About 290 users** at 57 refreshes a day; about 145 if Apple counts each dataset.
3. Everywhere else: the hourly forecast at most once an hour. **About 700 to 1,000 users.**
4. When Apple refuses a call, the app shows "no forecast", never a dry line.

The two groups share the 500,000. If they fill it, 1,000 UK users would need about 1.7 million calls a month: the $99.99 plan.

## 4. Recording WeatherKit, to decide the UK and Ireland

WeatherKit keeps no archive, so it can only be scored by recording it going forward. The test that decides the UK and Ireland:
- **What:** WeatherKit's minute and hourly forecast at 25 places, every 15 minutes, for four to six weeks: 15 in Great Britain, 5 in Ireland, 5 in Kent. Kent is inside KNMI's grid, so there KNMI and WeatherKit can be compared directly, against the same truth.
- **Truth:** the Met Office's 1 km radar on AWS, kept for two years, so it need not be recorded. Its grid reaches Ireland; if the Irish radars turn out not to be in it, record Met Éireann's radar, which is open for only the last 3 hours. KNMI's observed radar in Kent.
- **Scoring:** the same as section 2, in the first and second hour, on the rainy cases.
- **Calls:** 25 × 96 a day × 30.4 = 73,000 a month, or 146,000 if each dataset counts. Before launch the account has no other use, so this fits easily, and comparing our count with Apple's settles how calls are counted.
- **Respecting 1.6:** keep each WeatherKit forecast only until its two hours have passed, score it, keep the counts (hits, misses, false alarms per lead time) and delete the forecast. That keeps the storage "temporary and limited".
- **Where:** a timer on mini-server-1, next to the Buienradar recorder.

**What it needs from Josh's account:** a WeatherKit REST key (a .p8 file and its key ID), a Services ID for it, and the team ID, stored in `nix-secrets`. I did not create them. AGENTS.md requires that this be done from the command line; Apple's App Store Connect API does not manage these keys, so first check whether `asc web` can, and ask Josh if not.

The same recorder can also record Météo-France PIAF and GeoSphere INCA, which keep only a few days, once their decisions are made.

## 5. The decisions for Josh

1. **Add DWD and MET Norway to the server before launch, or after?** Recommended: before. They are open, need no account, and replace WeatherKit's hourly forecast with a 5-minute line across Germany, Austria, northern Switzerland, Denmark, Norway, Sweden and Finland. The cost is a second and third job on the server, a merged coverage map, and MET Norway's 93 MB file every 5 minutes (about 27 GB a day to download), which needs checking in `server/DESIGN.md`.
2. **A free Météo-France account in your name, for PIAF?** Recommended: yes, then record it for two weeks and score it before France gets it.
3. **A WeatherKit REST key, to record the UK and Ireland?** Recommended: yes, before launch (section 4).

## Sources

- Apple: [WeatherKit](https://developer.apple.com/weatherkit/), [Developer Program License Agreement](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/) (Attachment 8 in full, Attachment 9), [Weather feature availability](https://support.apple.com/en-us/105038) (June 2026: next-hour precipitation in Australia, Ireland, Japan, the UK and the US), Apple Developer Forums threads [793813](https://developer.apple.com/forums/thread/793813) and [816507](https://developer.apple.com/forums/thread/816507).
- DWD: [RV composite](https://dwd-geoportal.de/products/RADAR_RV), [RADVOR and the end of RQ/RE](https://www.dwd.de/DE/leistungen/radvor/radvor.html), files at `opendata.dwd.de/weather/radar/composite/rv/`.
- MET Norway: [THREDDS](https://thredds.met.no/thredds/catalog/radarnowcasting/catalog.html), [api.met.no terms](https://api.met.no/doc/TermsOfService), [licence](https://api.met.no/doc/License).
- GeoSphere Austria: [INCA nowcast](https://data.hub.geosphere.at/dataset/nowcast-v1-15min-1km). MeteoSwiss: [nowcast on request](https://opendatadocs.meteoswiss.ch/e-forecast-data/e1-short-term-forecast-data).
- Météo-France: [PIAF](https://www.data.gouv.fr/dataservices/api-modele-arome-prevision-immediate-agregee-fusionnee), [model data](https://confluence-meteofrance.atlassian.net/wiki/spaces/OpenDataMeteoFrance/pages/621019138/Mod%C3%A8les+et+donn%C3%A9es+de+pr%C3%A9vision).
- Met Office: [UK radar on AWS](https://registry.opendata.aws/met-office-uk-radar-observations). Met Éireann: [radar](https://data.gov.ie/en_GB/dataset/radar). DMI: [terms](https://www.dmi.dk/friedata/dokumentation/terms-of-use). AEMET: [radar data](https://datos.gob.es/es/catalogo/e05068001-datos-de-radares). Radar-DPC: [docs](https://dpc-radar.readthedocs.io/it/latest).
- Hourly models: [Open-Meteo historical forecast API](https://open-meteo.com/en/docs/historical-forecast-api), free for non-commercial use, used only for this test.
- Script: `research/verification/europe_check.py`; output: `research/verification/europe_check.md`.

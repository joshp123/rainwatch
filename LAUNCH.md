<!-- Written by AI on 2026.11.14 by model claude opus 5.5, at Josh's request. The one list of what stands between BuienWatch and the App Store. -->

# Launching RainWatch (BuienWatch in Dutch) on the App Store

Josh's goal: "we know exactly what we want to use to sell or market the app, and how to get it smoothly approved". It must "just work" outside the Netherlands, at the best quality the open data allows, with the Netherlands best of all.

The evidence is in `research/`. Every App Store step and its command is in `launch-runbook.md`. Realistic time to "Ready for Sale": four to six weeks, most of it waiting on Apple's reviews.

## 1. Decisions

Decided by Josh on 14 November:
- **Name:** RainWatch in English, BuienWatch in Dutch. On the watch the name under the icon follows the wearer's language (`App/Shared/InfoPlist.xcstrings`). On the App Store, Apple refused the bare "RainWatch" for the English listing ("already being used"), although the other app is listed as "RainWatch – Cute Cloud Weather"; it accepted "RainWatch: Rain Forecast", which the record carries for now. The Dutch listing is BuienWatch.
- **Price:** free, with no ads or in-app purchases. The account is declared "not a trader" in the EU (done 14 November), so no address shows. No postbox for now.
- **Countries:** worldwide, with the quality stated honestly for each area (section 3). Outside KNMI's area the app launches on Apple's WeatherKit (Josh, 14 November: "Let's launch with WeatherKit, but keep on in parallel figuring out a better way to do it"); `research/europe-sources.md` is the search for that better way.
- **Languages:** the listing's main language is English (U.K.), with Dutch. The Dutch store indexes both.

Open:
- **The English store name.** Bare "RainWatch" is taken. "RainWatch: Rain Forecast" and "RainWatch – Rain Forecast" were both accepted; any other "RainWatch …" name up to 30 characters can be tried with one command.
- **The support email address** that the privacy policy and the support page show to the public (item 15).

## 2. The list

Who does it: Claude (or another agent), unless it says Josh. "Josh" means only what must be him: his body, his judgement on words published in his name, or people he knows.

**A. Accounts**

| # | Task | Who | Status |
|---|---|---|---|
| 1 | Apple's Program License Agreement | Claude | Done 14 Nov, in the Developer app |
| 2 | KNMI account and API key, stored in `nix-secrets` | Terra | Done 14 Nov; tested. 1,000 requests an hour, no expiry |
| 3 | App Store Connect app record, bundle `nl.jjp.rain`, English (U.K.) | Claude | Done 14 Nov (app 6834856580): English name "RainWatch: Rain Forecast" (bare "RainWatch" refused as taken), Dutch listing "BuienWatch", all with `asc` |
| 4 | Trader status: "not a trader" | Claude | Done 14 Nov, from the shell; read back as DECLARED_NOT_TRADER |
| 5 | App Store Connect API key, so the `asc` command line can manage the listing | Claude | Done 14 Nov: "BuienWatch listing", App Manager role, in `nix-secrets` |

**B. The app**

| # | Task | Who | Status |
|---|---|---|---|
| 6 | App icon, an Icon Composer file at `App/Rain/AppIcon.icon` | Claude, from Fable's review | Done; checked in the watch's app grid |
| 7 | Server: once per KNMI run, the forecast becomes a pack of 32 km squares and a contents list on AWS (`server/DESIGN.md`) | Claude | Live: `https://rain.jjpcodes.com/latest` answers with a run under ten minutes old (checked 18 Nov) |
| 8 | The app reads the server: its own 32 km square for the line (one range request in rain, none when dry), the squares under the map for the radar page | Claude | Done 16 Nov; reads the live server since it went up. On Josh's watch on 18 Nov `latest` took 0.5 to 1.7 s and a square 0.4 s (the event log, `README.md`) |
| 9 | Credit and error messages name the real source ("Source: KNMI"); today they say Buienradar | Claude | Done 16 Nov: "Source: KNMI" on the forecast page and the radar, Apple's mark and legal link for its data; no Buienradar code or words left in the app. 18 Nov, after Sol's review of build 3: the legal link opens an About page in the app with Apple's legal text and a note that its data was changed; the same page has the privacy policy and KNMI's CC BY 4.0 credit with its data's links |
| 10 | Outside KNMI's area: WeatherKit on the watch. Minute by minute for an hour in the UK, Ireland, the US, Australia and Japan, hourly elsewhere. Apple's Weather mark and legal link shown, hourly data fetched at most once an hour | Claude | Done. The "App Services" switch, the capability `WEATHER_KIT`, was turned on from the shell on 18 Nov (`AGENTS.md`); the live test for London and Madrid passes |
| 11 | Europe outside KNMI's area: OPERA's open radar composite and our own forecast, 2 hours in 5-minute steps (`research/radar-sota.md`) | Claude | On hold. On one day of light showers OPERA saw 5% of the rain KNMI saw over the Netherlands and Belgium, and its rain-rate product almost none (`research/opera-check.md`). Needs a check in heavier rain, against a second national radar, before we promise anything. WeatherKit covers Europe at launch |
| 12 | Choose a Place, for anyone who refuses location (Apple Guideline 5.1.1(iv)) | Claude | Done, with a UI test of the reviewer's route. 18 Nov: each result shows its Apple map and a picked place keeps only what was typed, as Apple's Maps terms require (DESIGN.md rule 12) |
| 13 | iPhone wrapper, the only form App Store Connect accepts | Claude | Done; signs, and is accepted for App Store export |
| 14 | Dutch translation of every word in the app and of the location prompt | Claude writes, Josh reads | Done 18 Nov: `Sources/RainGraph/Localizable.xcstrings` and `App/Shared/InfoPlist.xcstrings`, checked on the simulator in Dutch in every state. `store/dutch.md` lists every string for Josh to read |
| 15 | Privacy policy and support page on Josh's website, linked from the app (Guideline 5.1.1(i)) | Claude writes; Josh approves the text before it is published | Done 18 Nov: both pages are live at `https://jjpcodes.com/rainwatch/privacy` and `/support`, in English and Dutch. Privacy is three lines ("collects nothing"); support is two, with GitHub Issues for problems and no email address |
| 16 | Version 1.0.0, build 1 | Claude | Done: 1.0.0, build 9, uploaded 18 Nov: the rewritten copy, Permission Expired and Location Off each with their steps, About only as a quiet link at the end of the forecast page |
| 17 | Real-watch pass: every forecast state, Always On, Night Mode, VoiceOver, larger text, offline, and a day's refresh log | Claude, with Josh wearing it | To do |
| 18 | Josh moves his complication from the old Rain app to BuienWatch; then the old app is removed | Josh, then Claude | BuienWatch is installed next to Rain |
| 19a | Record Buienradar's forecasts at the 64 Dutch grid points for a month, to compare them with KNMI's over many rainy days: Buienradar keeps no archive, so it could only be scored on the one day its forecasts were saved (13 November) | Claude | Recording since 14 Nov 18:46 on mini-server-1, every 15 minutes (`/var/lib/buienradar-recorder`) |
| 19 | Score KNMI's plain forecast against its blended one over a season | Claude | Done: plain for the first 30 minutes, blend after, better on 77% of days in the second hour (`research/verification/season.md`). Switched off on the server on 17 Nov: the blend file is 210 to 265 MB a run in heavy rain. Plain alone scores 0.533 against 0.560 over two hours. KNMI's 17 MB probabilities file is the way back, not yet scored |

**C. The store page**

| # | Task | Who | Status |
|---|---|---|---|
| 20 | Subtitle, keywords, promotional text and description, in English and Dutch, by the rules in Josh's saved App Store posts (Paul Solt, designerants) and Apple's: no other app's name, no "real-time", "accurate", "best" or "minute by minute", every promise of two hours or radar tied to KNMI's area, no keyword repeated in the name, subtitle or other language | Claude; Josh reads before it goes live | Rewritten again 18 Nov in `store/metadata/` (Dutch subtitle "Buien op je wijzerplaat"); the App Store Connect draft still has the earlier text until Josh approves the words in Paper |
| 21 | Five screenshots at 422 × 514 per language: a two-line headline of eight words or fewer, the real app in Apple's Ultra 3 frame, the face first and then four app screens (Guideline 2.3.3), no app name in the artwork | Claude | Retaken 18 Nov from build 8 with new captions, in `store/screenshots/`; not yet on the draft, which still has build 5's set |
| 22 | App Privacy answers: Data Not Collected (Apple excludes what Apple collects, and requests the server does not keep) | Claude | Done 18 Nov: applied from `store/privacy.json` and published with `asc web privacy`; read back as Data Not Collected, published |
| 23 | Category (Weather), age rating, copyright | Claude | Done 18 Nov: Weather, every age-rating answer "none", copyright "2026 Josh Palmer", manual release |
| 23a | Custom licence agreement: Apple's standard one, word for word, with WeatherKit's notice added (Agreement, Attachment 8, 1.2 and 2.2) | Claude | Done 18 Nov with `asc eula create`, for all 175 territories; the text is `store/eula.txt`. A territory Apple adds later gets the standard one until the agreement is updated |
| 24 | Notes for the reviewer: watch-only, Choose a Place, the data sources; a 60-second demo video | Claude | Notes written (`store/metadata/review-information.json`) and set on the draft with Josh's contact details, which are not in this repo. The 60-second demo video is still to do |

**D. Testing and release**

| # | Task | Who | Status |
|---|---|---|---|
| 25 | Upload builds; internal TestFlight on Josh's watch | Claude | Build 1.0.0 (9) uploaded 18 Nov and in the internal group "Internal". Josh installs it from TestFlight on his iPhone |
| 26 | External TestFlight: 5 to 10 Dutch testers for two weeks | Josh picks the testers and approves the invitation; Claude runs it | After 25 |
| 27 | Nominate for featuring when external testing starts, three weeks or more before release | Claude | With 26 |
| 28 | Submit for review. Allow two weeks. After a rejection over the listing, resubmit the same build | Claude | After 26 |
| 29 | Manual release when approved, then a fresh install from the store on Josh's watch | Claude | After 28 |

**E. After launch**

| # | Task | Who |
|---|---|---|
| 30 | One launch post on X and Dutch communities such as Tweakers and r/thenetherlands | Josh approves each text and where it goes |
| 31 | Reply to written reviews in the first month; check App Analytics after 30 days and change the first screenshot if needed | Claude drafts replies; Josh approves |

No paid ads. kr0der's ads did not pay; Paul Solt's best result came from Apple featuring a plain, good utility (`research/launch-playbook.md`).

## 3. Where the forecast comes from

Detail and sources: `research/radar-sota.md`.

- **KNMI's picture already has the neighbours' radars:** two Dutch, three Belgian and three German, cleaned and adjusted to rain gauges. It reaches about 300 km west of the Dutch coast, so British radars would change nothing within two hours. Buienradar adds them for its larger map and its longer-range radars.
- **The method matters more than the radars.** KNMI's operational forecast, like Buienradar's, moves today's rain along and can't see showers form or die. The state of the art blends that with a weather model; Belgium's RMI runs this operationally, and KNMI publishes its own blend free, as a pilot.
- **Measured over 66 rainy days,** KNMI's plain forecast is best for the first 30 minutes and its blend from there to 2 hours, so BuienWatch shows them in that order. On the one day Buienradar could be compared (13 November), both of KNMI's forecasts beat it.
- **Outside KNMI's area,** Europe's radar composite (OPERA) has been open since May 2026, but on the one day checked it missed most light showers that KNMI saw over the Netherlands and Belgium (`research/opera-check.md`). It is not good enough to forecast from until a heavier-rain check says otherwise (item 11).

### Coverage

| Area | Source | Rain line | Radar page |
|---|---|---|---|
| Netherlands, Belgium, Luxembourg, western Germany | KNMI, through BuienWatch's server | 2 h, 5-minute steps, 1 km | Real frames, 2 h ahead |
| UK, Ireland, US, Australia, Japan | Apple WeatherKit, on the watch | 1 h, minute by minute | None at first |
| Everywhere else | Apple WeatherKit hourly forecast | Hourly, labelled "Hourly only" | None |
| Rest of Europe (first update) | OPERA's radar composite, our own forecast on the server | 2 h, 5-minute steps | Real frames |

WeatherKit is free up to 500,000 calls a month. Apple never bills for more on its own: further calls are refused until the account holder subscribes to a bigger plan. Apple's terms require its Weather mark and legal link on screen, and forbid caching its data on a server.

Rejected after checking:
- RainViewer: no forecast since January 2026, and personal use only.
- The Bureau of Meteorology: needs a paid licence.
- Rainbow.ai: paid, and its global coverage is "coming soon".

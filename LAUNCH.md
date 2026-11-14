<!-- Written by AI on 2026.11.14 by model claude opus 5.5, at Josh's request. The one list of what stands between BuienWatch and the App Store. -->

# Launching BuienWatch on the App Store

Josh's goal: "we know exactly what we want to use to sell or market the app, and how to get it smoothly approved". It must "just work" outside the Netherlands, at the best quality the open data allows, with the Netherlands best of all.

The evidence is in `research/`. Every App Store step and its command is in `launch-runbook.md`. Realistic time to "Ready for Sale": four to six weeks, most of it waiting on Apple's reviews.

## 1. Decisions

Decided by Josh on 14 November:
- **Name:** BuienWatch.
- **Price:** free, with no ads or in-app purchases. It is declared "not a trader" in the EU, so no address shows. No postbox for now.
- **Countries:** worldwide, with the quality stated honestly for each area (section 3).
- **Languages:** the listing's main language is English (U.K.), with Dutch. The Dutch store indexes both.

Open:
- **The English name.** App Store names are set per language, not per country, so the English listing could be called something else. "RainWatch" is in use by another Apple Watch weather app, "RainWatch – Cute Cloud Weather". Only App Store Connect's own check can say whether it accepts the bare "RainWatch" (item 3).
- **The server.** `server/PROPOSAL.md` costs about US$0.15 a month at launch and sets out what any cheaper option would break. It waits for Josh's go.

## 2. The list

Who does it: Claude (or another agent), unless it says Josh. "Josh" means only what must be him: his body, his judgement on words published in his name, or people he knows.

**A. Accounts**

| # | Task | Who | Status |
|---|---|---|---|
| 1 | Apple's Program License Agreement | Claude | Done 14 Nov, in the Developer app |
| 2 | KNMI account and API key, stored in `nix-secrets` | Terra | Done 14 Nov; tested. 1,000 requests an hour, no expiry |
| 3 | App Store Connect app record, bundle `nl.jjp.rain`, English (U.K.) | Claude | Created 14 Nov (app 6834856580), but under Xcode's placeholder name "RainContainer": rename it to BuienWatch, add Dutch, and test "RainWatch" for English (U.S.), in one App Store Connect session with Josh's Touch ID |
| 4 | Trader status: "not a trader" | Claude, in App Store Connect | After 3 |
| 5 | App Store Connect API key, so the `asc` command line can manage the listing | Claude | After 3 |

**B. The app**

| # | Task | Who | Status |
|---|---|---|---|
| 6 | App icon, an Icon Composer file at `App/Rain/AppIcon.icon` | Claude, from Fable's review | Done; checked in the watch's app grid |
| 7 | Server: every 5 minutes, KNMI's forecast becomes two files on AWS (`server/PROPOSAL.md`) | Claude | Waits for Josh's go and item 2 |
| 8 | The app reads the server: 25 bytes for its line, one file for the radar page | Claude | After 7 |
| 9 | Credit and error messages name the real source ("Source: KNMI"); today they say Buienradar | Claude | With 8 |
| 10 | Outside KNMI's area: WeatherKit on the watch. Minute by minute for an hour in the UK, Ireland, the US, Australia and Japan, hourly elsewhere. Apple's Weather mark and legal link shown, hourly data fetched at most once an hour | Claude | To do. Needed for "worldwide" |
| 11 | Europe outside KNMI's area: OPERA's open radar composite and our own pySTEPS forecast, 2 hours in 5-minute steps (`research/radar-sota.md`) | Claude | First update after launch; check OPERA's delay, which countries share, and the computing cost first. WeatherKit covers Europe at launch |
| 12 | Choose a Place, for anyone who refuses location (Apple Guideline 5.1.1(iv)) | Claude | Done, with a UI test of the reviewer's route |
| 13 | iPhone wrapper, the only form App Store Connect accepts | Claude | Done; signs, and is accepted for App Store export |
| 14 | Dutch translation of every word in the app and of the location prompt | Claude writes, Josh reads | To do |
| 15 | Privacy policy and support page on Josh's website, linked from the app (Guideline 5.1.1(i)) | Claude writes; Josh approves the text before it is published | To do |
| 16 | Version 1.0.0, build 1 | Claude | With the first upload |
| 17 | Real-watch pass: every forecast state, Always On, Night Mode, VoiceOver, larger text, offline, and a day's refresh log | Claude, with Josh wearing it | To do |
| 18 | Josh moves his complication from the old Rain app to BuienWatch; then the old app is removed | Josh, then Claude | BuienWatch is installed next to Rain |
| 19a | Record Buienradar's forecasts at the 48 places for a month, to compare them with KNMI's over many rainy days: Buienradar keeps no archive, so it could only be scored on the one day its forecasts were saved (13 November) | Claude | Proposed: a small scheduled job on the Mac mini |
| 19 | Score KNMI's plain forecast against its blended one over a season | Claude | Done: plain for the first 30 minutes, blend after, better on 77% of days in the second hour (`research/verification/season.md`). Built into the server, with the plain forecast as fallback |

**C. The store page**

| # | Task | Who | Status |
|---|---|---|---|
| 20 | Subtitle, keywords and description, in English and Dutch. "buien" and "regen" go in the Dutch keywords. No "Buienradar", "real-time", "accurate" or "best" | Claude; Josh reads before it goes live | Drafts in `research/launch-runbook.md` (C5) |
| 21 | Five screenshots at 422 × 514, from the real watch, in English and Dutch, each with a headline of eight words or fewer ("Will I get wet?") | Claude | To do |
| 22 | App Privacy answers: coarse location, for app functionality, not linked to the person, no tracking | Claude | After 3 |
| 23 | Category (Weather), age rating, copyright | Claude | After 3 |
| 24 | Notes for the reviewer: watch-only, Choose a Place, the data sources; a 60-second demo video | Claude | Before 27 |

**D. Testing and release**

| # | Task | Who | Status |
|---|---|---|---|
| 25 | Upload builds; internal TestFlight on Josh's watch | Claude | Build 1.0.0 (1) uploaded 14 Nov through Xcode. The data server and WeatherKit come before external testing |
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
- **Outside KNMI's area,** Europe's radar composite (OPERA) has been open since May 2026; running the same method on it would give a 2-hour forecast across Europe (item 11).

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

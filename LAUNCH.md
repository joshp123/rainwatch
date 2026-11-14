<!-- Written by AI on 2026.11.14 by model claude opus 5.5, at Josh's request. -->

# Launching Rain on the App Store

Josh's goal: "we know exactly what we want to use to sell or market the app, and how to get it smoothly approved". He wants it to "just work" outside the Netherlands, at the highest quality the open data allows, with the Netherlands best of all.

The evidence is in `research/`: `global-data.md` (which data, where), `launch-runbook.md` (every App Store step with its command), `launch-playbook.md` (what Paul Solt and kr0der do) and `app-review-readiness.md` (Apple's rules and the law). Realistic time to "Ready for Sale": four to six weeks, mostly waiting on Apple.

## 1. Decisions only Josh can make

1. **A KNMI key.** KNMI's two-hour radar nowcast (1 km, five-minute steps, CC BY 4.0, free for commercial use) replaces Buienradar, whose terms need permission for any mobile app. KNMI forbids putting a key in an app, so the key lives on Rain's backend. Josh registers a free account at dataplatform.knmi.nl and requests a key (one account per person, his name). The shared anonymous key works for testing and hit its rate limit today.
2. **Where the backend runs, and its cost.** Every five minutes a job reads KNMI's nowcast (and later Germany's, the Nordics' and Austria's), cuts it into tiles about 100 km square, and publishes them as static files; the watch downloads its tile. The prototype (`server/knmi_probe.py`) does the cut in 0.07 seconds. Options:
   - Recommendation: AWS, where Josh's website already runs and whose infrastructure code exists (`~/code/opentofu-infra`): a scheduled Lambda with numpy and h5py, S3 and CloudFront. Estimated $0 to $5 a month at 10,000 users (about 6 million requests), mostly S3 writes (`research/trader-and-hosting.md`; tile count and run time not yet measured).
   - ChatGPT Sites doesn't fit: it hosts web pages and apps, not background jobs ("background services ... aren't supported"), and from 1 January 2027 6 million requests would use about 960 hosting credits against 125 on Plus or 375 on Pro.
   - Cloudflare is the fallback, from $5 a month.
3. **Price.** Recommendation: a one-off €2.99 ($2.99, £2.99), with no subscription, in-app purchase or ads; about €2.10 net per sale under the Small Business Program. Rivals with watch features charge €17 to €25 a year; the Dutch rain apps are free with ads (`research/name-and-price.md`). A paid app needs the Paid Apps Agreement, tax and bank details.
4. **EU trader status.** A paid app makes Josh a trader; Apple then shows an address, phone and email on Rain's EU store page. Recommendation: stay an individual and give a rented postbox address (PriPost, about €100 in the first year); Apple accepts a P.O. box with a receipt or bill as proof. A BV costs €1,300 to €1,800 to found and €1,300 or more a year, and the store would still show the BV's address. A free app with no income could be declared "not a trader" (`research/trader-and-hosting.md`).
5. **The name.** Josh suggested RainWatch or BuienWatch. RainWatch is taken in the NL, UK and US stores by another Apple Watch weather app. BuienWatch is free but echoes Buienradar and Buienalarm, whose owners could object, and means nothing outside the Netherlands. Recommendation: "Rain Ahead", free in all three stores, with "buien" and "regen" in the Dutch subtitle and keywords. Still to check: the BOIP, EUIPO and UK trademark registers (they need a real browser), and App Store Connect's own name check.
6. **Countries at launch.** Decided by Josh: worldwide, with the quality stated honestly per area (section 2). The listing's primary language is English (U.K.), with Dutch; the Netherlands store indexes both.

## 2. The data: works everywhere, best in the Netherlands

| Area | Source | Rain line | Radar |
|---|---|---|---|
| Netherlands, Belgium, Luxembourg, western Germany, Kent | KNMI radar nowcast, via Rain's backend | 2 h, 5 min, 1 km | Real frames, 2 h ahead |
| Rest of Germany | DWD radar nowcast (free, credit DWD), via the backend | 2 h, 5 min | Real frames |
| Norway, Sweden, Finland, Denmark | MET Norway nowcast (CC BY 4.0) | 2 h, 5 min, where radar covers | Observed only, until tested |
| Austria | GeoSphere INCA nowcast (CC BY 4.0) | 3 h, 15 min | Real frames |
| UK, Ireland, US, Australia, Japan | Apple WeatherKit next-hour forecast, on the watch | 1 h, minute by minute | None at first |
| Everywhere else | Apple WeatherKit hourly forecast | Hourly, labelled "Hourly only" | None |

Later, in order of users: the backend extrapolates open radar where there is no national nowcast (the US, the UK, then Europe from the EUMETNET OPERA composite).

What gets worse outside the Netherlands, said plainly in the app: a shorter horizon, coarser steps, or hourly only. WeatherKit is free up to 500,000 calls a month on Josh's membership; past that Apple charges from $49.99 a month. Its terms require the Apple Weather mark and legal link on screen, and forbid caching it on a server. Rejected after checking: RainViewer (no forecast since January 2026, personal use only), Open-Meteo (free tier non-commercial), the Bureau of Meteorology (paid licence), Rainbow.ai (paid; its global coverage is "coming soon").

Still to prove before launch: a rainy-day comparison of KNMI against Buienradar at 20 or more places, to know KNMI is as good.

## 3. Product: what must change to ship

| Task | Who | Status |
|---|---|---|
| Complications, Smart Stack, app and radar, every state tested by `RainUITests` | Claude | Done |
| Fable's design reviews: circle words always about rain, peaks that show (one square-root scale, a deeper band), a smooth line over a fill, a dot that stands apart on tinted faces, the app opening on the saved forecast, stale after an hour | Claude | Done; the circle checked on the real watch |
| Privacy manifest, encryption declaration, a location text that says what happens | Claude | Done |
| Backend: KNMI tiles, then DWD, MET Norway, GeoSphere; the app reads one format from it | Claude | Needs decisions 1 and 2 |
| WeatherKit on the watch for everywhere else, with Apple's mark and legal link | Claude | To do |
| Source credit and error text that switch with the source ("Source: KNMI"; the error screens name Buienradar today) | Claude | To do |
| **Place picker** for when location is off or outside the data: a submission blocker (Guideline 5.1.1(iv) requires manual entry when location is declined) | Claude | Done; the reviewer's path is a UI test |
| **iPhone container target** so App Store Connect accepts the build; bundle IDs are now `nl.jjp.rain` (container), `nl.jjp.rain.watchkitapp` and `.widget` | Claude | Done, archive checked unsigned; signing waits for Josh to accept Apple's new Program License Agreement. Josh re-adds the complication once after the first install |
| Real-watch pass of every state (the `-scenario` route in AGENTS.md), Always On, Night Mode, VoiceOver, larger text, offline, a day's refresh log | Claude, Josh wearing it | To do |
| App icon (one layered 1088 × 1088 image) | Claude drafts, Josh chooses | To do |
| Dutch translation of the app | Claude, a Dutch read by Josh | To do |
| Privacy policy and support page on Josh's site, linked in the app | Claude drafts, Josh publishes | To do |

## 4. The store page: what sells it

- **Words.** Subtitle "Rain in the next 2 hours" / "Regen de komende 2 uur"; keywords and description drafted in `research/launch-runbook.md` (C5). No "Buienradar", "real-time", "accurate" or "best" anywhere.
- **Screenshots.** Up to five at 422 × 514, from the real watch, each with one headline of eight words or fewer about the moment ("Will I get wet?", then the circle on a face, the Smart Stack card, the forecast, the radar). No bezel: at 422 × 514 a frame shrinks the watch. Built by a small renderer in this repo, in English and Dutch. Apple Watch has no preview video.
- **Ratings.** Apple Watch has no in-app review prompt (the API is unavailable on watchOS). Ratings come from a "write a review" link on the support page and in the launch post.
- **Featuring.** Nominate in App Store Connect when external TestFlight starts, three weeks or more before release; Rain uses what Apple promotes on watchOS (complications, the Smart Stack, the Digital Crown).

## 5. App Store Connect: the steps

Step by step, with commands, in `research/launch-runbook.md`. In short:

1. **Day 0, Josh:** confirm agreements; request App Store Connect API access (Apple reviews it case by case); set trader status; if paid, tax and bank.
2. **Build:** add the container, archive and upload with `xcodebuild` (the `asc` CLI cannot upload watch-only apps); everything after the upload through `asc`, as kr0der does.
3. **Record and page:** Josh creates the app record in the browser (it needs his two-factor sign-in); then categories, age rating, App Privacy, metadata and screenshots through `asc`.
4. **TestFlight:** internal at once, then 5 to 10 Dutch testers for two weeks, with two or three calls watching them use it (Paul Solt's practice).
5. **Submit:** Josh presses Submit for the first review. Review notes explain watch-only use, the place picker and the data sources, with a 60-second demo video (kr0der's practice). Plan two weeks for review; after a metadata rejection, resubmit the same build (Paul Solt lost eight days accepting "use the latest build").
6. **Release:** manual release (phased release is only for updates), then a fresh install from the store on Josh's watch.

## 6. After launch

- One launch post on X and a Dutch page; Dutch communities such as Tweakers and r/thenetherlands. Every post waits for Josh to approve its text and where it goes.
- No paid ads: kr0der's ads and content farms did not pay; Paul Solt's big result came from Apple featuring a plain, good utility.
- Reply to written reviews in the first month; check conversion in App Analytics after 30 days and adjust the first screenshot.

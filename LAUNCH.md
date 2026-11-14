<!-- Written by AI on 2026.11.14 by model claude opus 5.5, at Josh's request. -->

# Launching Rain on the App Store

Josh's goal: "we know exactly what we want to use to sell or market the app, and how to get it smoothly approved". This is the plan to get there: what only Josh can decide, then every task in order, who does it and where it stands. The evidence is in `research/app-review-readiness.md` (approval and law), `research/launch-playbook.md` (what Paul Solt and kr0der do, from the posts Josh saved) and Fable's design review (summarised under Product).

## 1. Decisions only Josh can make

These come first because the rest depends on them.

1. **The data.** Buienradar's terms, verified on its page: its free data is for non-commercial use with credit, and "het gebruik voor mobiele toepassingen of commerciële doeleinden vereist toestemming van Buienradar" (use in mobile apps or for commercial purposes needs Buienradar's permission). That covers a free app too, and the radar key Rain uses was copied from Buienradar's website. Options:
   - **Ask Buienradar for written permission** (info@buienradar.nl; the brand belongs to RTL and DPG Media). It keeps today's data and quality. The answer may be no, slow, or free-only.
   - **Move to KNMI open data** (CC BY 4.0, free with a registered key): five-minute radar and a two-hour radar nowcast. It needs work: download and decode KNMI's files, read the forecast at your location and draw the radar, probably on a small server rather than the watch. Quality, latency and running cost are unknown until a prototype measures them.
   - Recommendation: send the request now, and in parallel build a one-day KNMI prototype that answers whether it can run on the watch or needs a server, and how its forecast compares with Buienradar's at the same places. A "no" then costs days, not the launch.
2. **Price.** Free, or a one-off price. The playbook's evidence is against subscriptions for a utility like this (kr0der's subscription apps lost money); its recommendation is a one-off €2 to €4. If Buienradar allows free use only, that decides it. Paid apps need Apple's Paid Apps Agreement, tax and bank details, and should join the Small Business Program (Apple's cut 15% instead of 30%).
3. **EU trader status.** Under the Digital Services Act, Apple shows a trader's address, phone and email on the app's EU store page. A paid app points to trader status. Josh decides his status, and whether to use a business address.
4. **The name.** "Rain" is generic: its availability is only known when App Store Connect accepts it, and it needs a trademark search (EUIPO, BOIP). "Buienradar" cannot be in the name, subtitle, keywords or screenshots without permission.
5. **Market and language.** The Netherlands first, with Dutch and English listings, or wider. Buienradar's graph covers the Netherlands and nearby countries; KNMI's radar covers the Netherlands.
6. **Outside the coverage area or without location.** Today Rain shows "No Forecast Here" or "Location Needed". An App Review tester, probably in the US, would see only that. Recommendation: let the wearer choose a place (search or a short list), use it when location is off or out of range, and give the tester a demo route in the review notes.

## 2. Product: make it shippable

| Task | Who | Status |
|---|---|---|
| Complications, Smart Stack, app, radar, every state rendered by `RainUITests` | Claude | Done |
| Design pass from Fable's review: circle words always about rain ("IN" until it arrives, "FOR" while it lasts), real peak heights in the circle, stale after an hour not 30 minutes, app opens on the saved forecast, local time zone and clock format, words-only corner and inline, Smart Stack priority | Claude | Done, not yet on the real watch (it was out of range) |
| Data source: Buienradar with its required credit, or KNMI (decision 1) | Claude | Blocked on decision 1 |
| Place picker and fallback for no location or outside coverage (decision 6) | Claude | Blocked on decision 6 |
| Real-watch pass of every complication state (the debug `-scenario` route in AGENTS.md), plus Always On, Night Mode, tinted faces, VoiceOver, larger text, offline, denied location | Claude, Josh wearing it | To do |
| A day's refresh log from the watch, to set the stale limit from measured gaps | Josh wears it with Rain on the face; Claude reads the log | To do |
| Radar rain contrast checked on the real watch (pale blue on the dark map was weak in the simulator) | Claude | To do |
| App icon (watchOS: one layered 1088 × 1088 px square, masked to a circle) | Claude drafts, Josh chooses | To do |
| Dutch localisation of the app (decision 5) | Claude | To do |
| Privacy policy page, hosted on Josh's site, linked from the app | Claude drafts, Josh publishes | To do |
| Privacy manifest (`PrivacyInfo.xcprivacy`: the app group's `UserDefaults` is a required-reason API) and `ITSAppUsesNonExemptEncryption = NO` (HTTPS only) | Claude | To do |
| Location purpose string that says what happens to the location | Claude | To do |
| Version 1.0, release build, archive | Claude | To do |

## 3. The store page: what sells it

From the playbook (Paul Solt's screenshot method, written up from designer Theodora / @DesignerAnts) and Apple's specifications.

| Task | Who | Status |
|---|---|---|
| Title, subtitle ("says the job", for example "Rain in the next 2 hours"), keywords, description and promotional text, in English and Dutch, with no unsupported "real-time" or accuracy claims | Claude drafts, Josh approves | To do |
| Up to five Apple Watch screenshots at 422 × 514 (Ultra 3), from the real watch, each with one headline of eight words or fewer about the moment, not the feature: "Will I get wet?", then the circle on a face, the Smart Stack card, the forecast, the radar | Claude | To do |
| No preview video: Apple's specification lists none for Apple Watch. A short radar clip goes on Josh's site and social posts instead | Claude | To do |
| Support URL and privacy policy URL | Josh's site | To do |
| Review notes: watch-only, where location is asked, how to reach the radar, the data source and its permission, the demo route; plus a demo video of the app (kr0der's practice) | Claude | To do |

## 4. App Store Connect: approval

Everything here acts on Josh's Apple account and is visible to Apple, so each step waits for his go-ahead. His membership is active (the team holds a Developer ID certificate); Xcode creates the App Store certificate on first upload.

| Task | Who | Status |
|---|---|---|
| Create the app record (App Store Connect's iOS flow, then watchOS), with bundle IDs `nl.jjp.rain` and `nl.jjp.rain.widget` | Claude with Josh's go-ahead | To do |
| Paid Apps Agreement, tax and bank details, Small Business Program (if paid) | Josh | Decision 2 |
| Trader status (decision 3), age rating questionnaire, content rights (needs decision 1 settled), App Privacy answers, price and countries | Claude prepares, Josh confirms | To do |
| Upload a build to TestFlight; wear it for two weeks, including a rainy commute; two or three calls with Dutch cyclists watching them use it (Paul Solt's practice) | Claude uploads, Josh tests | To do |
| Submit for review | Josh's go-ahead | To do |
| Optional: drive App Store Connect from the terminal with the `asc` CLI (rorkai/App-Store-Connect-CLI), which kr0der uses, with an App Store Connect API key from Josh's keyring | Claude | If wanted |

## 5. Launch and after

The playbook's evidence points away from paid marketing for a small utility (kr0der's ads and content farms did not pay; Paul Solt's big result came from Apple featuring a plain, good utility).

- Nominate Rain for featuring in App Store Connect once the page and a stable build are ready; it uses what Apple promotes on watchOS: complications, the Smart Stack and the Digital Crown.
- One launch post on X and a Dutch page; Dutch communities such as Tweakers and r/thenetherlands. Every post waits for Josh to approve its text and where it goes.
- Ask for ratings only with Apple's own prompt (`requestReview`), after several useful forecasts, never from a custom prompt (Guideline 5.6.1); add a "Rate Rain" link.
- Turn on review notifications and reply to written reviews in the first month.

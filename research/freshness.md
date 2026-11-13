# Rain: how to keep the watch data current (freshness research)

Written by AI on 2026.11.13 by model Claude Sonnet 5.5, for the Rain build. Sources were read in full where marked "read". No money spent, no sign-ins.

Legend: **[V]** verified in a primary source (Apple docs, WWDC transcript, Apple staff forum answer). **[R]** reported by developers, not confirmed by Apple. **[I]** my inference, not stated by any source.

## Bottom line

1. Apple does not publish a hard number for watchOS widget reloads. The best primary statement (WWDC26 watchOS Group Lab, Nov 2026 transcript) is: a widget on the watch face can expect a reload about **every 15 to 20 minutes**, Smart Stack widgets get **fewer, depending on how often the wearer looks at them**, and a **reload policy date is the "more deterministic" route** to a refresh. [V]
2. Nothing on watchOS gives minute-by-minute refresh. Weather apps cope the same way: they ship a timeline that advances by itself and accept a 15-30 minute real refresh. [V for Apple, R for apps]
3. For a **watch-only app**, the only reliable levers are: the timeline reload policy, a reload when the app is in the foreground (budget-free), and an optional background refresh task (about 4 per hour, only while the complication is on the active face). Push needs a server. [V]
4. Background location is the weak spot. **Significant-change monitoring, visit monitoring and `CLMonitor` do not exist on watchOS.** Widget location (`NSWidgetWantsLocation`) is not documented for watchOS and has failed for developers there. [V that docs omit watchOS, R that it fails]
5. Make staleness visible in the UI. No Apple guidance says how, but the building blocks are documented (self-updating relative date text, a final "stale" timeline entry). See section 7.

## 1. Widget reload budget on watchOS

### What Apple states

- Budget is dynamic, applies to a 24-hour window tuned to the wearer's habits, per widget kind/instance. Factors: how often and when the widget is visible, last reload time, whether the containing app is active. "For a widget the user frequently views, a daily budget typically includes from 40 to 70 refreshes", roughly every 15 to 60 minutes. A few days of "learning" give extra reloads at first. [V, `Keeping a widget up to date`, read]
- Budget-free reloads: containing app in the foreground; active audio or navigation session; Now Playing; the widget performs an App Intent (button/toggle); the widget animates; locale or Dynamic Type changes. [V, same page]
- Timeline entries "should be at least about 5 minutes apart"; WidgetKit may coalesce reloads across widgets. [V, same page]
- WWDC21 session 10048: 40 to 70 "background updates per day... roughly every 15 to 30 minutes"; "reloads are not an every second operation"; WidgetKit "may withhold updates when the user isn't using the device for extended periods like when the user's sleeping"; a significant location change gives a budget-free update on next view for widgets that use location. [V, transcript read]
- WWDC26 session 277 (WidgetKit foundations): "Frequent reloads while your app is in the foreground might be throttled. A final call to reload when your app enters the background is usually a good idea." "Provide multiple timeline entries whenever possible." Turn on WidgetKit developer mode to lift budgets while testing. [V, transcript read]
- **WWDC26 watchOS Group Lab (session 8014), the only watch-specific statement I found** [V, transcript read; speaker unlabelled, likely a WidgetKit engineer]:
  - "I don't think we have much new guidance for watchOS 27."
  - "You can expect your widget to update every 15 to 20 minutes if it's being actively used."
  - "Things on the watch face are getting viewed all day. So they're at the top tier of the budget, and they will be viewed favorably by the scheduler and be more guaranteed to get updates."
  - Smart Stack: "not going to be quite in that 15 to 20 minute bucket, because it depends on how often the user actually goes to look at your widget... If the user looks at it once a day, you might get a refresh once a day."
  - Timeline reload policy: "a very powerful and slightly more deterministic way... We might hold a stale timeline for a little bit, but there's stronger guarantees that we'll give you refresh after that."
  - The question about "about 50 updates per day" was neither confirmed nor denied; the 50 figure comes from the old ClockKit era (see section 2).

### Complication versus Smart Stack versus inactive face

- Active face complication: top tier, about 15 to 20 minutes. [V, Group Lab]
- Smart Stack: viewing-driven, fewer. [V, Group Lab]
- Complications on faces that are not the active face: **no primary source found**. The ClockKit-era background budget is only given for "the active watch face" (below). [I] that complications on non-active faces get nothing special; do not plan around them.
- Rain will be in all three places (circular, rectangular, Smart Stack widget). Each widget kind/instance has its own budget. [V] So more kinds mean more budget in total but also more fetches (battery).

### Reload mechanics

- `TimelineReloadPolicy` `.atEnd`, `.after(date)`, `.never`. `.after` is honoured as the next preferred reload time; Apple warns it "tries to respect the date you specify". [V]
- `WidgetCenter.reloadTimelines(ofKind:)` / `reloadAllTimelines()` is a request. Apple staff: "The system will decide on its own when or if it will accept your reload request." Check Console.app for budget messages. [V, forum 735352, Apple Frameworks Engineer]
- Called while the watch app is foreground, the reload is not counted; called from the background it is counted. [V, forum 788713, Apple DTS, also the docs]
- Called during an active `HKWorkoutSession` it is budget-free. [V, forum 819899, Apple DTS accepted answer] Not relevant for Rain (do not start a workout for this).
- DTS on a request for real-time updates in the Smart Stack: "WidgetKit isn't designed to support real-time refresh, and so you might re-consider your app design." [V, forum 807219]
- Known bugs to expect on a real watch:
  - watchOS 11.5: `reloadAllTimelines()` from a background task did nothing unless **WidgetKit developer mode** was on, which suggests the budget was the blocker; timeline policy reloads still worked. [R, forum 788014; Apple asked for a Feedback ID, no resolution shown]
  - watchOS 11.1: `reloadAllTimelines()` from a `WKRefreshBackgroundTask` stopped updating complications. [R, forum 769864, Apple asked for a bug report, no resolution shown]
  - Older WatchKit-lifecycle apps had broken reloads; a pure SwiftUI app worked. [R, forum 735352]
  - **Consequence for testing:** with developer mode on, budgets are lifted and results are not representative. Test with it off, on the real watch.

### New in watchOS 26 and 27

- watchOS 26: `RelevanceConfiguration` widgets (system gives runtime when relevance conditions such as place or time are met). WidgetKit push updates on watchOS (section 3). [V, WWDC25 278]
- watchOS 27: "much new guidance" none; Watch Connectivity can now trigger widget updates ("it works now", Group Lab), not relevant to a watch-only app. [V that it was said; no API details found]
- I found no change to the budget numbers in 26 or 27. [V by absence in the Group Lab answer]

## 2. Background app refresh on a watch-only app

- `WKApplication.shared().scheduleBackgroundRefresh(withPreferredDate:userInfo:scheduledCompletion:)` (or SwiftUI `.backgroundTask(.appRefresh)`). [V, docs read]
- Needs a complication on the active face to get background time at all: "For the system to allocate background execution time to your app, your app must have a complication on the active watch face." [V, `Using background tasks`]
- Budget: "approximately four tasks per hour for each app with a complication on the active watch face. All the complications on the current watch face share this budget." [V, `WKApplicationRefreshBackgroundTask` doc]. Apple DTS repeats this (HealthKit background delivery shares it) in forum 781261. [V]
- Preferred date is a lower bound only: "guarantees to not trigger the task earlier than the preferred fire date. However, it may delay the task... or it isn't even triggered." One outstanding task at a time; scheduling another cancels the first. [V, docs and forum 788713]
- Time: "a few seconds". The older WWDC20 notes give the numbers: **4 seconds of active CPU time, 15 seconds total**; no URLSession data tasks in a refresh task (they fail), so start a background URLSession. [V for the doc wording "few seconds", R/V-from-WWDC20-notes for the numbers; the notes page is a third-party transcript of WWDC20 10049, a ClockKit-era talk, still the only numbers published]
- Exceeding the time gives `EXC_CRASH (SIGKILL)`. [V]
- Throttled when battery low, during workouts, off wrist. [V for "battery low, workouts", R for "off wrist"]
- Low Power Mode: "Complications update less frequently" and "Background app refresh happens less frequently". [V, Apple Support page 108320, read]
- Does a widget reload from a background task work? Yes by design, but it counts against the widget budget, and has been buggy on watchOS 11.x (section 1). [V that it counts; R for the bugs]
- Background `URLSession`: allowed, can be deferred "based on available resources" and delivery "may be deferred". Smaller transfers are better. Wakes the app with `WKURLSessionRefreshBackgroundTask`. [V, `Making background requests`] ClockKit-era budget was also 4 per hour. [V, WWDC20 notes]
- Apple's own fallback advice: "don't expect the system to trigger every background task. Design a fallback mechanism... even if your app never receives any background tasks, it can still update its state whenever the user launches it in the foreground." [V]
- Takeaway: for Rain, a refresh task adds nothing the widget's own `getTimeline` fetch does not, except running app code (for example refreshing the location). [I]

## 3. WidgetKit push updates (watchOS 26+)

- `WidgetPushHandler` is available from watchOS 26.0. [V, API availability]
- Needs a server that holds the widget push token (from `pushTokenDidChange`) and sends an APNs request: `apns-push-type: widgets`, topic `<bundle id>.push-type.widgets`, body `{"aps":{"content-changed":true}}`. It reloads all your push-enabled widgets, like `reloadAllTimelines()`. No broadcast channels. [V]
- Budgeted and "delivered opportunistically": "an additional update mechanism that doesn't replace timeline updates"; Apple suggests throttling pushes on the server. No number published. [V, docs and WWDC25 278]
- Apple staff: the budget is separate from silent (background) push budgets, and "WidgetKit push notifications are separate than timeline updates". Whether widget pushes share the timeline reload budget is **not answered** in the thread. [V, forum 787892, ambiguous]
- Reliability: one developer reports iOS 26 pushes returning HTTP 200 while `getTimeline` is never called; no Apple answer. [R, forum 839182, iOS not watchOS]
- WidgetKit developer mode ignores push and reload budgets during testing. [V, WWDC25 278]
- A server is mandatory (APNs cannot be triggered from the device). For Rain, the server would have to know each device's location to know when rain data changes for it, which is more machinery than the benefit. [I]
- Verdict: not worth it for a personal watch-only app unless a pure timeline design proves too stale on the real watch. [I]

## 4. Location in the background on watchOS

### Availability on watchOS (from API availability tables) [V]

| API | watchOS |
|---|---|
| `CLLocationManager.requestLocation()` | yes, 2.0 |
| `startUpdatingLocation()`, `allowsBackgroundLocationUpdates` | yes, 3.0 / 4.0 |
| `CLLocationUpdate.liveUpdates()` | yes, 10.0 |
| `CLBackgroundActivitySession` | yes, 10.0 |
| `CLServiceSession` | yes, 11.0 |
| `startMonitoringSignificantLocationChanges()` | **no** (iOS, iPadOS, Mac Catalyst, macOS only) |
| `startMonitoringVisits()` | **no** (iOS side only) |
| `CLMonitor` | **no** (iOS 17, iPadOS, Mac Catalyst, macOS) |
| `allowDeferredLocationUpdates` | **no** |
| `NSWidgetWantsLocation`, `CLLocationManager.isAuthorizedForWidgetUpdates` | **not listed for watchOS** (iOS, iPadOS, macOS, visionOS) |

Note the key is `NSWidgetWantsLocation`, not "UsesLocation".

### What the rules say

- When In Use: a suspended app gets no location updates. To receive updates in the background you need a `CLBackgroundActivitySession` (or an active Live Activity / workout), started **while the app is in the foreground**. Core Location "does not take measures to keep apps running continuously when it has nothing to deliver". [V, `Handling location updates in the background`, WWDC24 10212]
- The background activity session shows the blue location indicator and keeps the app running; Apple: "Consider carefully whether your app really needs background location updates. Most apps need location data only while someone actively uses the app." [V]
- Always: "Always authorization will only be effective when you hold" a `CLServiceSession(authorization: .always)`, which "you can only start holding... when your app is in the foreground". Always without a session yields nothing in the background. [V, WWDC24 10212] So on current OS versions Always is not a silent background pass.
- `watchOS` background modes: Apple lists "location updates" as a continuous background session on watchOS, same model as above. [V, `Background execution`]
- Approximate location "is updated only every 15 to 20 minutes" (`.accuracyLimited`). [V, WWDC24 10212]
- `requestLocation()` from a background refresh task on a When In Use app: not documented, likely denied while not "in use". [I; the forum shows "Delaying authorization request placed while insufficiently in-use" logs, R, forum 736785]

### Can the widget extension get a fix itself?

- iOS docs: add `NSWidgetWantsLocation` to the extension's Info.plist; the system asks to extend the app's When In Use permission to the widget; the widget is "in use" for a short period after being visible, and gets location only if refreshed in that period; otherwise indicate location is unavailable. WidgetKit also gives a free reload after a significant location change. [V for iOS, `Accessing location information in widgets`, read]
- **None of these pages or symbols list watchOS.** The WidgetKit "significant location change reload" cannot rely on the watchOS side since significant-change monitoring is not on watchOS. [V that docs omit; I for the conclusion]
- Developer evidence: a watchOS complication developer set the plist keys and the app had location permission. No permission prompt appeared for the widget, and `CLLocationManager` timed out inside the widget. Apple's own World Clock widget gets a prompt. No replies. [R, forum 818868, Mar 2026]
- Another open-source watch app (Slackwater) keeps location out of the complication: "The complication extension never asks for location: the watch app writes the nearest-station keys when it gets a fix", and lists widget location as something to confirm. [R, GitHub issue]
- Weathergraph says its complications "use your current GPS location" and asks for the Always permission, but its FAQ says on iPhone: "If it's set to anything other than Always, please select Always" (iPhone wording). [V that they say this; unclear how it works on the watch]
- Several location authorization bugs on watchOS 10 (no prompt after reinstall, corrupted state after Xcode runs, fixed by Reset Location & Privacy). [R, forum 736785] Expect to hit this on a freshly built watch app.
- Verdict: treat widget live location as an optimistic bonus that must be tested on the watch, and keep the saved fix as the real source. The app's current design (try `liveUpdates()`, fall back to the saved fix) matches this. [I]

### Cost

- Apple publishes no figures. Apple does say radios and GPS "use significant energy" and to batch and avoid location. [V, archived Energy Efficiency Guide, general only]
- Likely ranking, cheapest first: saved fix refreshed whenever the app is open < `requestLocation()` at low accuracy when the app is opened < background activity session with a low-accuracy configuration < continuous precise tracking. [I, measure on device]

## 5. How other weather apps do it

- **Weathergraph** (read faq and "Apple Watch weather complications" guide, Sep 2026): "An Apple Watch complication is not a live webpage"; watchOS "decides when third-party widgets and complications receive execution time"; a complication "can advance through already-downloaded forecast hours" without a new fetch. Low Power Mode "disables background updates for all third-party apps". Widgets that are stale show an **Update button** (FAQ heading "Widgets aren't updating automatically (and display Update button)"). Guide says: "Do not plan a weather-sensitive activity from a complication that visibly says its forecast is old." Checks the forecast "source and timestamp in the app". [V]
- **Forecast Bar**: "watchOS budgets background updates for every app on your wrist"; no complication can refresh every minute; the app "schedules smart background refreshes", keeps a shared cache, builds timelines that "advance hour by hour between refreshes"; watch fetches its own data without the iPhone. Says nothing about stale display. [V, page read]
- **CARROT**: no primary source found. [not found]
- **Apple Weather**: no primary source found about its mechanism. Apple Support says apps with a complication on the current face keep refreshing even with Background App Refresh off. [V, support guide via search snippet only; not fully read]
- **Weather Gods** developer (AppleVis comment, page blocked, search snippet only): the watch "takes over, updating about every hour or until the phone detects a new location"; requesting updates every few minutes makes the watch back off. [R, snippet only, unverified]
- **Data age patterns**: I found no Apple guidance requiring a visible timestamp. The established patterns are (a) an "Update" button, (b) showing the forecast timestamp in the app, (c) forward-looking timelines so content advances without fetches. Complications that look current while old are a recurring complaint. [R/I]

## 6. Battery

- WidgetKit docs: "Reloading widgets consumes system resources and causes battery drain due to additional networking and processing... limit the frequency and number of updates you request to what's necessary." [V]
- Apple's old watch energy guide: batch network work; use background `URLSession`; watch radios power up and "use significant energy". [V]
- Low Power Mode reduces both complication and background refresh frequency, and (on watchOS) turns off Always On display. [V]
- Per-update cost numbers: none published. A Rain fetch is one small request. The cost driver on the watch is likely the radio wake when the iPhone is not connected, not the request size. [I]
- WWDC26 lab: widget runtime on watchOS "other than a slower, smaller core count... is actually the same as what you get on iOS". [V]

## 7. My recommendation (mine, not from a source)

Goal from Josh: always current enough to trust, without hurting battery, and the same for location.

### A. Accept the real ceiling and design for it

Plan for a real refresh every **15 to 20 minutes on the active face, less in the Smart Stack**. The data is 5-minute radar steps, so a 15-minute-old fetch is still useful. Never claim minute-level freshness; make **age** the contract. [I]

### B. Data fetch

1. Fetch in `getTimeline` (as now). Buienradar's feed covers about 3 hours, so one fetch can fill the whole timeline.
2. Change the policy from "after the last entry (~45 min)" to **`.after(fetchTime + 10 to 15 min)`** so the system has a nearer, more deterministic reload date (Apple: reload policy is "slightly more deterministic"). Still write entries for about 45 to 60 minutes so a skipped reload leaves correct content that advances by itself. [I from V sources]
3. Reload when the app is in the **foreground** (budget-free), and again as it goes to the background. [V]
4. Keep the one-minute entries only if they render correctly on the watch. Apple says entries should be "at least about 5 minutes apart". Prefer entries only where the displayed value changes; use `Text(date, style: .timer)` or `.relative` for the "IN 6 MIN" countdown so it ticks without entries. Test minute entries on the real watch. [V for guidance, I for the approach]
5. Skip a separate background refresh task at first. It shares the 4 per hour budget, needs the complication on the active face, can only run seconds of code, and its widget reload counts against the same widget budget. Add it later only if the real-device test shows gaps longer than about 30 minutes on the active face. If added: re-schedule the next one first thing in the handler, use a background `URLSession`, finish quickly, call `reloadTimelines`. [I]
6. Skip push. It needs a server and its budget is unpublished. [I]
7. Add a small refresh `Button(intent:)` (watchOS 10+ widgets are interactive) in the Smart Stack widget. An App Intent from the widget is budget-free. Confirm it works on the watch. [V for the budget exemption on "widgets", I for watchOS]

### C. Making staleness visible (core of the trust goal)

1. Stamp every entry with `fetchedAt` and the location used and its age.
2. Show age compactly: `Text(fetchedAt, style: .relative)` ("12 min") or a clock time ("14:05"). Apple documents that this style "updates live" without the extension running (`Displaying dynamic dates in widgets`). On the always-on display the system uses a lower update cadence, so prefer a fixed clock time there. [V for the mechanism, I for the choice]
3. Add a **terminal stale entry** at `fetchedAt + ~25 to 30 min` (and another at about 60 minutes). It renders without any extension run: dim the gauge, replace the headline with "Old data", show "14:05". Because entries render at their dates, a failed or skipped reload cannot leave a fresh-looking "IN 6 MIN" on screen. This is the key protection against the failure Josh dislikes in stock widgets. [I]
4. Fresh state shows no age text (or a very quiet one); stale states grow louder. Do not rely only on colour (tinted mode desaturates; HIG says avoid colour as the only signal). [V for the HIG point]
5. If the fetch fails in `getTimeline`, return the previous data with its original `fetchedAt` (so the age keeps growing), never a re-stamped copy. [I]
6. If location is older than a threshold (suggest 30 min) show a location-age marker alongside the data age. [I]
7. Make the data age derive from the fetch time, not the entry time. Forum reports show developers misreading redraws as reloads (a visible timestamp that did not change). [R]

### D. Location

1. The saved fix in the App Group is the source of truth. Store `(lat, lon, accuracy, timestamp)`.
2. Update it at every foreground launch with a low-accuracy `requestLocation()` (km level is enough for rain), and whenever the Smart Stack/app is opened. This is cheap and covers the common case: the wearer opens the app now and then.
3. In the widget: keep trying `CLLocationUpdate.liveUpdates()` only as a bonus. First prove on the real watch that it works at all: the docs for `NSWidgetWantsLocation` do not list watchOS, and a developer reports no prompt and timeouts. If it does not work, remove it rather than carry dead code. [I]
4. Do **not** adopt a continuous background `CLBackgroundActivitySession` by default: it keeps the app running with the blue indicator, there is no significant-change or visit alternative on watchOS, and Apple says most apps should not. Run a **one-day battery experiment** first (a low-accuracy session, with `distanceFilter` of a few km) and compare the battery graph before deciding. Only adopt it if Josh's own routine shows a stale-location problem worth the cost. [I]
5. Accept the physical limit: with no background fix, the location is only as new as the last time the app was open. That is why C.6 matters.
6. Handle watchOS authorization bugs on first install: if no prompt appears, "Reset Location & Privacy" on the iPhone and reinstall. [R]

### E. Test plan on the real watch (Ultra 3)

- WidgetKit developer mode **off** for the freshness test (on, budgets are lifted, per Apple).
- Put the complication on the active face and a second one on a different face; add the Smart Stack widget. Log `fetchedAt` for every `getTimeline` call to an App Group file and compare gaps. Target for the active face is 15 to 20 minutes; the Smart Stack will be longer.
- Test Low Power Mode (expect slower refresh), watch off wrist overnight, and an app-never-opened day.
- Check that the stale entry appears on time when you put the watch in airplane mode.

## Sources

Apple documentation (read via the developer.apple.com data endpoints, 2026 copy):
- Keeping a widget up to date: https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date
- Updating widgets with WidgetKit push notifications: https://developer.apple.com/documentation/widgetkit/updating-widgets-with-widgetkit-push-notifications
- Accessing location information in widgets: https://developer.apple.com/documentation/widgetkit/accessing-location-information-in-widgets
- Making network requests in a widget extension: https://developer.apple.com/documentation/widgetkit/making-network-requests-in-a-widget-extension
- Displaying dynamic dates in widgets: https://developer.apple.com/documentation/widgetkit/displaying-dynamic-dates
- Using background tasks (watchOS): https://developer.apple.com/documentation/watchkit/using-background-tasks
- WKApplicationRefreshBackgroundTask: https://developer.apple.com/documentation/watchkit/wkapplicationrefreshbackgroundtask
- scheduleBackgroundRefresh: https://developer.apple.com/documentation/watchkit/wkapplication/schedulebackgroundrefresh(withpreferreddate:userinfo:scheduledcompletion:)
- Keeping your watchOS content up to date / Making background requests: https://developer.apple.com/documentation/watchos-apps/keeping-your-watchos-app-s-content-up-to-date
- Handling location updates in the background: https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background
- CLBackgroundActivitySession, CLServiceSession, CLMonitor, CLLocationUpdate, NSWidgetWantsLocation, isAuthorizedForWidgetUpdates and the significant-change/visits pages (availability tables)
- HIG Complications: https://developer.apple.com/design/human-interface-guidelines/complications
- Low Power Mode on Apple Watch: https://support.apple.com/en-jo/108320
- Archived Energy Efficiency Guide, Apple Watch: https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/AppleWatchExtensionBestPractices.html

WWDC transcripts: 2021 10048 (widget budgets), 2022 10050 (checked, nothing on budgets), 2023 10029 (checked, no budget content), 2024 10212 (Core Location sessions), 2025 278 (What's new in widgets), 2026 277 (WidgetKit foundations), 2026 8014 (watchOS Group Lab). WWDC20 10049 via https://wwdcnotes.com/documentation/wwdc20-10049-keep-your-complications-up-to-date/ (third-party notes of an Apple talk).

Apple Developer Forums: 807219, 788713, 735352, 761642, 769864, 788014, 819899, 759389, 781261, 787892, 839182, 818868, 736785.

Weather apps: https://weathergraph.app/faq, https://weathergraph.app/guides/apple-watch-weather-complications, https://forecastbar.com/apple-watch-weather-complications/. Slackwater issue: https://github.com/openwatersio/slackwater-ios/issues/566. Drobinin: https://drobinin.com/consulting/apple-watch/building-an-apple-watch-app-worth-keeping/ (developer blog, read).

## Not found / unverified

- Any published number for watchOS 26 or 27 widget reloads beyond "about 15 to 20 minutes".
- Budget behaviour of complications on non-active faces.
- Whether widget push shares the timeline reload budget.
- Whether `NSWidgetWantsLocation` works on watchOS.
- CARROT and Apple Weather update mechanisms.
- Battery numbers for any option.
- The WWDC26 Watch Connectivity widget-update API name (irrelevant for a watch-only app).

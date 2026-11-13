# Short-term rain copy survey

Research date: 13 November 2026. Scope: public, no-cost web research. “Verbatim” quotes below are copied from the cited source; translated quotes are labelled. Product surfaces are identified where the source establishes them. This survey cannot inspect Josh’s installed apps or region-specific watch UI, so absence of public wording is not evidence that a product has none.

## Findings by product

### Buienradar (Dutch; primary)
- Official app FAQ: [Buienradar app FAQ](https://www.buienradar.nl/overbuienradar/faq-app). It describes radar refreshes: “De radarmetingen worden elke 5 minuten doorgegeven.” This is help copy, not a short-term status sentence.
- The characteristic Dutch nowcast wording “Na 12:05 lichte neerslag verwacht” (“Light precipitation expected after 12:05”) appears in a research document’s transcription of a Buienradar display, not on a current official product page: [Data Visualization in Society](https://dspace.library.uu.nl/bitstream/handle/1874/414542/Data_Visualization_in_Society.pdf?sequence=1). Another live public forecast transcription gives “Lichte regen verwacht rond 10:10 (over ongeveer 34 minuten)” (“Light rain expected around 10:10 [in about 34 minutes]”): [TechSpeeltuin](https://techspeeltuin.nl/weer), secondary site.
- Captured pattern: event first (“after/around [clock time]”), severity (“light”), and optionally relative time. No verified public current strings for dry-all-window, rain stopping, persistent rain, or stop/restart; no official watch wording established here.

### Buienalarm (Dutch; secondary/official store listing not retrieved)
- A software overview says the app shows a timeline and indicates “wanneer het gaat regenen en hoeveel regen er gaat vallen”, “tot op 5 minuten nauwkeurig”: [Gratissoftware.nu](https://www.gratissoftware.nu/app/buienalarm.php). This describes the graph rather than exact visible copy.
- A 2026 user review quotes an alert as “over een half uur gaat het misschien regen. Over een half uur is het droog.” This is user-reported notification text, not independently verified: [MWM app listing/reviews](https://mwm.ai/apps/buienalarm-weer-regenradar/598509141).
- No verified short-status strings for the remaining states.

### KNMI (Dutch; primary)
- Official app FAQ says the app has a precipitation radar and “Sinds 20 mei 2026 zijn er weer vooruitkijkende radarbeelden beschikbaar in de app”; the radar “toont de neerslag 2 uur in het verleden en 2 uur in de toekomst.” It explains chance text: “Bij een neerslagpercentage van 30% is er ‘mogelijk’ sprake van neerslag.” [KNMI app FAQ](https://www.knmi.nl/kennis-en-datacentrum/uitleg/knmi-app)
- The same official source cautions that percentage “zegt dus niets over de duur van de regen”. This is useful: chance-of-rain is not a substitute for start/stop timing.
- No accessible primary exact phrases for the requested nowcast states; official surface is radar/graph plus hourly forecast. Forecast horizon is explicitly bounded by the displayed radar, rather than a claim that it will remain dry indefinitely.

### Apple Weather / Apple Watch (primary)
- Apple Watch support says, “If precipitation is forecast at this location as the appointment time nears, the Precipitation widget appears in the Smart Stack.” Tapping it shows “detailed weather information, including hourly forecasts.” [Apple Watch weather support](https://support.apple.com/en-euro/guide/watch/apd07ec24f9e/watchos)
- Apple documents next-hour precipitation availability as region-dependent, but its public support page does not provide exact state sentences: [iPhone Weather support](https://support.apple.com/en-mk/guide/iphone/iph1ac0b35f/ios).
- No public primary strings found for watch complication, Smart Stack precipitation widget, or dry/start/stop/restart sentences. Do not infer a specific sentence from Apple’s feature description.

### Dark Sky (historic; secondary)
- A user’s contemporaneous 2020 account quotes the phone app: “light rain would be starting in 20 minutes”; earlier it said rain would start “in 13 minutes”. Watch: “rain was coming within the hour.” It also reports later “no precipitation at all.” [Renée Fishman](https://mymeadowreport.com/reneefishman/2020/the-futility-of-predictions/). Secondary firsthand account, historic UI, not a current product.
- These examples show event + intensity + relative lead time, and a useful explicit dry state. No captured stop/restart wording.

### AccuWeather MinuteCast, Tomorrow.io, Yr/NRK, Met Office, DWD WarnWetter, MeteoSwiss, Weeronline, Google/Pixel Weather, Rain Alarm, CARROT Weather, Mercury Weather, Hello Weather, Forecast Bar, Weathergraph, AniMeteo, Rain Today, Rainbow Weather
- I did not find enough publicly accessible, attributable primary source material in this pass to quote exact state strings for these products. App store imagery and live app screens are often region-, platform-, or login-specific. They are not treated as verified here.
- Met Office’s official app page confirms “Check the weather in your area for the next hour and up to 7 days ahead” and hourly/daily widgets, but no state phrases: [Met Office app](https://weather.metoffice.gov.uk/weather-app). Its forecast explainer says weather symbols and precipitation chance represent the period from the shown time to the next period: [forecast guide](https://weather.metoffice.gov.uk/guides/what-does-this-forecast-mean).
- Official Met Office materials therefore demonstrate interval framing, but do not establish start/stop sentence patterns for its app.
- KNMI’s official radar FAQ and Buienradar’s accessible help were more informative for the local Dutch context than broad product marketing.

## State coverage from verified examples

| State | Publicly evidenced wording | Source/surface confidence |
|---|---|---|
| Dry for entire window | Dark Sky report: “no precipitation at all” | Historic, secondary, in-app |
| Dry now, rain starts later | Buienradar: “Na 12:05 lichte neerslag verwacht”; Dark Sky: “light rain would be starting in 20 minutes” | Buienradar secondary transcription; Dark Sky secondary firsthand |
| Raining now, stops later | No verified phrase located | — |
| Raining throughout | No verified phrase located | — |
| Stops then starts again | No verified phrase located | — |
| Drizzle vs nothing | Buienradar example distinguishes “lichte neerslag”; no verified explicit drizzle-vs-zero sentence | Secondary transcription |
| Intensity | Buienradar “lichte”; Dark Sky “light rain” | Secondary |
| Forecast boundary | KNMI says radar shows 2h past + 2h future; does not imply beyond-window conditions | Primary product FAQ |

## Analysis and recommendation (my analysis)

The clearest pattern answers with a **condition plus a transition and duration**. “Dry for 25 min” tells someone whether they can leave now and how long the dry interval lasts. “Rain in 25 min” tells when an umbrella may become useful. When rain is already falling, “Rain stops in 10 min” is more actionable than “Raining”; if another shower follows, state both intervals: “Dry 10 min · rain in 25”. These describe the forecast only; they do not tell the user what to wear or whether an outing is safe.

Use **minutes** for the short horizon and glance surfaces: it is relative to now and avoids requiring the user to calculate from the clock. Use a **clock time** on expanded surfaces or notifications that may be read later, where the timestamp remains meaningful. Avoid showing both on tiny surfaces. On long-form surfaces, “at 14:10 (in 25 min)” can be useful, but duplication is not needed by default.

Say **“No rain”** only when every forecast step in the supported window is zero. If trace precipitation exists, show “Drizzle” or “Light rain”, never “Dry”. If the forecast is dry only until the end of the two-hour window, describe the interval as “Dry for 2h” or “Dry next 2h”; do not imply it will stay dry after that. A compact window label or timeline boundary can carry the horizon, avoiding a sentence that sounds permanent.

### Proposed copy set

Suggested labels are in British English. Circular examples use two stacked lines (about five characters each); exact fit depends on the complication template. “No rain” may need a wider slot or two-line rendering.

| State | Circular (~5 chars/line) | One line (~20 chars) | Full sentence |
|---|---|---|---|
| No rain in next 2h | **NO / RAIN** | **No rain · next 2h** | **No rain is forecast in the next two hours.** |
| Dry now, starts later | **DRY / 25m** | **Dry 25 min · rain** | **It stays dry for 25 minutes; light rain is forecast after that.** |
| Raining now, then stops | **RAIN / 10m** | **Rain stops in 10 min** | **Rain is forecast to stop in 10 minutes.** |
| Rain throughout window | **RAIN / 2h** | **Rain for next 2h** | **Rain is forecast throughout the next two hours.** |
| Stops, then starts again | **DRY / 10m** | **Dry 10m · rain 25m** | **Rain is forecast to stop in 10 minutes, then start again in 25 minutes.** |
| Trace/drizzle, distinct from zero | **DRIZ / 20m** | **Drizzle in 20 min** | **Very light rain (drizzle) is forecast in 20 minutes.** |
| Light/moderate/heavy | **LITE / RAIN**; **MOD / RAIN**; **HVY / RAIN** | **Light rain in 20 min** | **Light rain is forecast to start in 20 minutes.** |
| Dry until window ends, then unknown | **DRY / 2h** | **Dry next 2h** | **No rain is forecast in the next two hours.** |

The bottom row deliberately describes the bounded interval rather than predicting beyond it. Prefer “Dry next 2h” over bare “Dry” when a two-hour forecast window is the data limit. For persistent rain or start/stop states, the line graph should retain the full pattern; text should summarize the next transition, not hide a later return to rain.

### Compact circular vocabulary
- **DRY / 25m** = dry now, rain begins after the stated dry interval (pair with a rain glyph/colour or a clear label on the face if ambiguity remains).
- **RAIN / 10m** = raining now; forecast ends after the interval.
- **DRY / 10m** plus an arc/line showing the next rain onset = interval between showers.
- **NO / RAIN** = all forecast bins zero.
- **DRIZ** is arguably not instantly legible; if user testing finds it unclear, use **LITE / RAIN** and reserve **NO RAIN** for zero. Five characters cannot carry a full sentence, so the plot is the primary truth and text should name the state/next transition.

### Limitations
This is a source-limited web survey, not an installation-by-installation audit of every named app. I did not inspect paid tiers or use paid APIs, and I have not presented unverified memory of app wording as fact. Exact watch complication strings in particular remain unverified.

<!-- Written by AI on 2026.11.14 by model claude sonnet 5.5 (claude-sonnet-5-5), at Josh's request. -->

# Name and price for Rain

Josh asked: "prices - suggest?" and "name - RainWatch or BuienWatch in nl discuss?". Goal: "we know exactly what we want to use to sell or market the app, and how to get it smoothly approved". Worldwide launch is decided.

All store lookups were run on 14 November 2026 with Apple's public iTunes Search API (`itunes.apple.com/search` and `/lookup`, NL, GB and US storefronts) and Apple's public store pages. A store search proves only that a name is visible today. It does not prove a name is free (an unreleased app record can hold it).

## 1. Recommendations

**Name: neither "RainWatch" nor "Rain Watch". Do not use "BuienWatch" as the worldwide name. Use "Rain Ahead" (the fallback already in `LAUNCH.md`) in every language, and put the Dutch search words in the Dutch subtitle and keywords.**

- "RainWatch" is taken, today, in all three stores, by an Apple Watch weather app in the same niche (section 2.1).
- "BuienWatch" is free in all three stores and absent from the US register. I could not check BOIP or EUIPO (section 3). It also copies the "Buien-" pattern of the two market leaders, and means nothing outside the Netherlands.
- "Rain Ahead" has no exact match in NL, GB or US store search and no live US trademark. It is also unchecked at BOIP and EUIPO.
- Dutch discovery does not need "Buien" in the name (section 6).

**Price: a one-off purchase of €2.99 (US$2.99, £2.99 by Apple's equalisation). No subscription, no in-app purchase, no ads.**

- Every Watch-capable weather app I found charges €17 to €25 a year, or €70 to €100 once, for Watch features. A single €2.99 undercuts that and needs no paywall.
- Josh's experts' evidence is against subscriptions for this kind of app and for a €2 to €4 one-off (section 5).
- Running cost is a small server plus WeatherKit, which is free to 500,000 calls a month. About ten sales a month pay for the server (section 5).
- Paid means trader status in the EU. Free with no revenue is the only version that might not (section 7).

## 2. Is the name taken?

### 2.1 App Store (NL, GB, US)

| Name searched | NL | GB | US |
|---|---|---|---|
| RainWatch | Taken: "RainWatch – Pogoda z chmurką", Damian Glasek, id 6812712175 | Taken: "RainWatch – Cute Cloud Weather", same app | Taken: same app |
| Rain Watch | No exact match | No exact match | No exact match |
| BuienWatch | No result at all | No exact match (watch-shop apps only) | No exact match |
| Rain Ahead | No exact match | No exact match | No exact match |

Source: iTunes Search API, queries as above.

The existing RainWatch is a direct competitor, not a bystander. Its store page says it "shows the weather on your Apple Watch as an animated 3D cloud", released 25 September 2026, free with a weekly subscription, "RainWatch Premium Weekly $0.49", English and Polish, forecasts from Apple Weather ([US page](https://apps.apple.com/us/app/rainwatch-cute-cloud-weather/id6812712175), [lookup API](https://itunes.apple.com/lookup?id=6812712175&country=us)). A new Apple Watch rain app called "Rain Watch" would be confused with it. It also has no trademark behind it that I could find (section 3), so Apple's name claim route would not help Josh against it either.

Apple's own rule: "an app name can be used by one app per localization", names belong to language localisations rather than countries, and "App Store Connect only allows for one app title per language localization" ([Apple App Name Dispute form](https://www.apple.com/legal/intellectual-property/dispute-forms/app-store/app-name-dispute.html), [Add a new app, quoted by AxonBuild](https://axonbuild.com/blog/app-store-listing-name-and-description)). The other app's English name includes the words "Cute Cloud Weather", so Apple might accept a bare "RainWatch" in Josh's record. Apple does not document what happens when a different developer already holds a name ([AxonBuild](https://axonbuild.com/blog/app-store-listing-name-and-description)). Guideline 2.3.7 says "Choose a unique app name" and Apple's product page guide says to "avoid names that use generic terms or are too similar to existing app names" ([Review Guidelines](https://developer.apple.com/app-store/review/guidelines), [product page guide](https://developer.apple.com/app-store/product-page)). Do not rely on that gap.

### 2.2 Other "Watch" apps already on the store

Apple's trademark is "Apple Watch", not "Watch" ([Apple Trademark List](https://www.apple.com/legal/intellectual-property/trademark/appletmlist.html), which lists Apple Watch®, Apple Watch SE®, Apple Watch Ultra®, watchOS® and WatchKit®). Apple's guideline bars using its marks "as or as part of a ... product name" ([Guidelines for Using Apple Trademarks](https://www.apple.com/legal/intellectual-property/guidelinesfor3rdparties.html)). It also says not to "use the word watch ... as a pun or verb in your marketing materials" ([Marketing guidelines](https://developer.apple.com/app-store/marketing/guidelines)). Plenty of apps carry "Watch" in the name without trouble (US store, 14 Nov 2026):

- SleepWatch - Top Sleep Tracker (Bodymatter, 328,438 ratings)
- HeartWatch: Heart Rate Monitor (Tantsissa, $8.99)
- RainWatch – Cute Cloud Weather (Damian Glasek)
- TideWatch: Tides & Weather (Technology One)
- StormWatch+ (Cirrus Weather Solutions)
- Boat Watch - Ship Tracking, Ocean Watch, Weather - Storm Radar Watch

"Watch" is allowed. It is also a crowded suffix for this niche, which is a reason to avoid it, not a rule against it. I found no rejection report for a plain "…Watch" name; I did not search for one beyond the above.

## 3. Trademark registers

| Register | Result |
|---|---|
| USPTO (live search, `tmsearch.uspto.gov`) | No mark for RAINWATCH, RAIN WATCH, BUIENWATCH, BUIENRADAR, BUIENALARM, RAIN AHEAD or RAINAHEAD, live or dead. Near hits only: TRAINWATCH (two abandoned, plus a new application from a Polish company, class 9), BRAINWATCH (medical), RAIN FOREST WATCH (cancelled, watches). I queried USPTO's public search back end directly; a control query for "carrot" returned 536 hits, so the search works. |
| BOIP (Benelux) | **Not checked.** The register's API demands a reCAPTCHA token ([BOIP register script](https://boip-registers.boip.int/assets/index.js?v=2)). I did not try to bypass it. |
| EUIPO / TMview | **Not checked.** TMview rejects scripted requests ("Request Rejected"). |
| UKIPO | Not checked. |

The USPTO result is a knockout search for exact and wildcard word marks, not legal clearance. A real-browser check of BOIP and TMview for BUIENWATCH, RAIN AHEAD, BUIENRADAR and BUIENALARM is still to do. Per Josh's rules, that is browser work for the Mac mini.

One legal point from BOIP: it "only registers trade names that do not describe the product or service" ([BOIP merkcheck](https://www.boip.int/nl/merkcheck)). "Buien" is the plain Dutch word for showers, and "Rain" is the plain English word. "BuienWatch" and "Rain Ahead" are both descriptive, so Josh could not easily own either as a mark, and neither could he be sure of keeping others off it.

## 4. "Buien" next to Buienradar and Buienalarm

- Buienradar is owned by RTL Nieuws BV, inside DPG Media (since 2025) ([Wikipedia](https://nl.wikipedia.org/wiki/Buienradar.nl), [buienradar.nl company details](http://buienradar.nl/overbuienradar/bedrijfsgegevens)). Buienalarm is Infoplaza's, which also owns Weeronline and Drops ([Infoplaza](https://www.infoplaza.com/nl/consument), [Adagium](https://www.adagium.nl/kennisbank/weeronline-overgenomen-door-infoplaza-groep-bv)). I could not confirm either mark's registration (section 3).
- The NL store shows third parties using "buienradar" in their names without removal: "Clime: buienradar" (Mosaic), "Weer - buienradar: Weer24" (wetter.com), "Ventusky: Weer & Buienradar", "Weer - Buienalarm & Buienradar" (Numrise), "Druppel, Regen & Buienradar" (S Boersma), "Buienradar Live Nederland" (Voros) ([NL search, 14 Nov 2026](https://itunes.apple.com/search?term=buienradar&country=nl&entity=software)). That is tolerance today, not permission, and I found no enforcement news either way.
- "BuienWatch" does not contain either mark. The risk is likelihood of confusion: same goods (rain apps), same Dutch audience, same "Buien + English-ish word" shape as "Buienradar" and "Buienalarm". NRC reported a 2025 conflict between the two owners and KNMI over its free radar ([NRC, 7 Feb 2025](https://www.nrc.nl/nieuws/2025/02/07/het-rommelt-tussen-de-weer-apps-a4882406)), which suggests they watch rain-app competition closely (my reading).
- Apple's rule applies to Josh's keywords: no "unauthorized use of trademarked terms", "competing app names" ([Apple search guide](https://developer.apple.com/app-store/search)). So "buienradar" and "buienalarm" stay out of every field. "Buien" alone is an ordinary Dutch word and is fine in keywords.

Verdict: low to moderate risk for BuienWatch, not zero, and no upside over a name that does not echo them.

## 5. Price

### 5.1 What comparable apps charge

All are "Free" to download on the store. Prices are in-app purchases, from each store page, 14 Nov 2026.

| App | Model | NL (€) | UK (£) | US ($) |
|---|---|---|---|---|
| Buienradar (DPG Media) | Free with ads; Premium subscription | Premium €6.99/yr (also €1.49 variant listed) | n/a | n/a |
| Buienalarm (Infoplaza) | Free with ads; "Abonnementen" (the page does not show the period) | Ad-Dropper €1.99, Super €3.99, Family €6.99, "1 year without ads" €0.99 | n/a | n/a |
| Drops (Infoplaza, Buienalarm abroad) | Same model | n/a | 1 year no ads £0.99, Ad-Dropper £1.99, Super £3.99, Family £5.99 | n/a |
| KNMI Weer | Free, no ads, public funding | Free | n/a | n/a |
| CARROT Weather | Subscription; Watch complications need Premium | Annual €21.99, monthly €5.49, Ultra up to €43.99 | Annual £19.49, monthly £4.99 | Annual $19.99, monthly $4.99, Ultra $39.99 |
| Hello Weather | Free; Watch app needs Pro; subscription or lifetime | Yearly €19.99, monthly €1.99, lifetime €99.99 | n/a | Yearly $19.99, monthly $1.99, lifetime $99.99 |
| Mercury Weather | Subscription or lifetime | Yearly €17.99, monthly €2.99, lifetime €69.99 | n/a | Yearly $19.99, monthly $3.99, lifetime $99.99 |
| Weathergraph | Free; Pro for complications; subscription or lifetime | Yearly Pro €24.99 (and others), forever €89.99 | n/a | Yearly $24.99, monthly $4.99, forever $99.99 |
| Forecast Bar | Subscription | n/a | n/a | Silver $11.49, Gold $19.99 |
| Rain Radar Pro (DeluxeWare) | Was paid at $11.99 in search results; page now says "monthly and annual subscriptions" | n/a | n/a | Search listing $11.99; page lists no price |
| RainWatch (cloud, Glasek) | Free with weekly subscription | n/a | n/a | $0.49/week |
| Druppel, Regen & Buienradar (Dutch, small) | Free with one-off "Pro" | Pro €0.99 | n/a | n/a |
| Rainspotter | Free with subscription | Premium €12.99/yr, €1.99/month | n/a | n/a |
| WeatherPro (DTN) | Paid up front | €0.99 | £0.99 | n/a |
| Precip | Free with location-count purchases | n/a | n/a | $14.99 yearly up to $99.99 |

Sources, in table order: [Buienradar NL](https://apps.apple.com/nl/app/buienradar-weer/id621542526), [Buienalarm NL](https://apps.apple.com/nl/app/buienalarm-weer-regenradar/id598509141), [Drops GB](https://apps.apple.com/gb/app/drops-the-rain-alarm-radar/id981543863), [NRC on KNMI](https://www.nrc.nl/nieuws/2025/02/07/het-rommelt-tussen-de-weer-apps-a4882406), [CARROT NL](https://apps.apple.com/nl/app/carrot-weather-alerts-radar/id961390574) / [GB](https://apps.apple.com/gb/app/carrot-weather-alerts-radar/id961390574) / [US](https://apps.apple.com/us/app/carrot-weather-alerts-radar/id961390574), [Hello Weather NL](https://apps.apple.com/nl/app/hello-weather/id978393692) / [US](https://apps.apple.com/us/app/hello-weather/id978393692), [Mercury NL](https://apps.apple.com/nl/app/mercury-weather/id1621800675) / [US](https://apps.apple.com/us/app/mercury-weather/id1621800675), [Weathergraph NL](https://apps.apple.com/nl/app/weathergraph-weather-widget/id1501958576) / [US](https://apps.apple.com/us/app/weathergraph-weather-widget/id1501958576), [Forecast Bar US](https://apps.apple.com/us/app/forecast-bar-weather-radar/id1057030968), [Rain Radar Pro US](https://apps.apple.com/us/app/rain-radar-pro-live-forecast/id488674899), [RainWatch US](https://apps.apple.com/us/app/rainwatch-cute-cloud-weather/id6812712175), [Druppel NL](https://apps.apple.com/nl/app/druppel-regen-buienradar/id6756480584), [Rainspotter NL](https://apps.apple.com/nl/app/rainspotter-rain-radar/id1534854735), WeatherPro via NL/GB search, [Precip US](https://apps.apple.com/us/app/precip-rain-forecast-alert/id6471449887).

Not found: no UK-store page was read for Hello Weather, Mercury, Weathergraph, Forecast Bar. The Hello Weather and Mercury lists include family and several duplicate price rows (one row per price point or older version).

What it shows:

1. The Dutch rain leaders are free with ads, and ad-free costs €2 to €7 a year. KNMI's own app is free and has no ads. Buying a Dutch rain app will always be a choice against free options.
2. The Watch-capable weather apps put Watch features behind a subscription or lifetime price: €17 to €25 a year, €70 to €100 once. Reviews show buyers resent it: "everything you really need ... you have to pay a monthly or yearly subscription for" (CARROT US review).
3. The only one-off prices near Rain's niche are very low: Druppel Pro €0.99, WeatherPro €0.99.
4. A weekly subscription exists in the niche (RainWatch at $0.49 a week, about $25 a year), sold with a free trial. The playbook's experts found weekly subscriptions unreliable (below).

### 5.2 Apple's euro price points

Apple no longer has numbered tiers. You choose a base storefront and a price point, and Apple generates the other 174 storefronts "accounting for foreign exchange rates and certain taxes"; the base price is never changed, and Apple adjusts the rest when exchange rates or taxes move ([Set a price](https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price)). Up to 800 price points; the menu opens on 25 common ones. A paid price needs the Account Holder to accept the Paid Apps Agreement first.

Euro price points near the range: €0.99, €1.49, €1.99, €2.99, €3.99, €4.99, €9.99 ([Galva price table for EUR](https://galva.io/tools/apple-pricing-tiers/currency/eur), a third-party mirror; Apple publishes the live list only inside App Store Connect). The same table pairs $2.99 with €2.99.

My arithmetic, not from a source: at €2.99 the Dutch price includes 21% VAT, so ex-VAT is about €2.47. Apple takes 15% under the Small Business Program (30% otherwise) ([Developer Program details](https://developer.apple.com/programs/whats-included)), leaving about €2.10 per sale (about €1.73 at 30%).

### 5.3 Running costs

- WeatherKit: 500,000 calls a month included with the membership; then US$49.99 a month for 1 million, $99.99 for 2 million, $249.99 for 5 million ([Apple WeatherKit](http://developer.apple.com/weatherkit)). The allowance is per membership, shared by all apps ([Emrld Labs](https://emrldlabs.com/blog/weatherkit-swiftui-native-forecast-privacy-first), a developer's report).
- Server and CDN: about €5 to €20 a month (inferred, not checked; `research/global-data.md`, section 7).
- At 10,000 users, `global-data.md` estimates 0.9 million WeatherKit calls a month if 15% of users are outside the national-nowcast countries. That needs the $49.99 plan. KNMI, DWD and the other open sources cost nothing.
- Break-even from my arithmetic: about 3 to 10 sales a month cover the server; about 24 sales cover a $49.99 WeatherKit month.
- A one-off price brings no income from users who keep using the app for years. With the server bill ongoing, that is the main weakness of a one-off. At this scale the bill is small, and caching by tile cell keeps WeatherKit use low (`global-data.md`).

### 5.4 What the experts' evidence says

From `research/launch-playbook.md`, section 3 and section 8:

- kr0der's pricing numbers come from iPhone apps with weekly subscriptions and paid ads: 71 people reached his paywall and none converted; his whole experiment ended at $5,087.81 after 105 days, mostly from X payouts rather than apps. His lesson is that paid marketing did not work.
- The playbook recommends "charge once, in the €2 to €4 range, with no subscription, unless the data source forces a server cost, in which case a single low annual price", and to enrol in the Small Business Program first. It marks this as the author's judgement: "no source here covers one-off pricing for a watch utility".
- Paul Solt's best result came from Apple featuring a plain, good utility, not from price.
- `LAUNCH.md` section 1 already lists "free, or a one-off €2 to €4".

### 5.5 Options considered

| Option | For | Against |
|---|---|---|
| Free, no ads, no purchase | Most downloads and ratings; possibly no trader status | No revenue; running cost paid by Josh forever; against his stated aim to "sell" |
| Free with one-off unlock | Lower barrier; Druppel does it at €0.99 | Needs a paywall, restore purchases, reviewer notes; still trader; extra review risk |
| Subscription (annual or weekly) | Matches running cost | Playbook evidence is against; Watch-app reviews show resentment; needs a paywall |
| **Paid up front, €2.99** | Simplest to build and review; undercuts every Watch competitor; fits the playbook; one price line in the listing | Lower conversion in a market of free incumbents; no ongoing revenue |
| Paid up front, €1.99 or €0.99 | Easier impulse buy; WeatherPro and Druppel price here | Proceeds about €1.40 or €0.70 per sale; needs 5 to 15 sales a month for the server |

The €2.99 price is a judgement. No source tested one-off pricing for a watch utility. Cheap to change later: price changes need no new build ([Schedule price changes](https://developer.apple.com/help/app-store-connect/manage-app-pricing/schedule-price-changes-for-apps)). Starting at €2.99 and later running a promotion is easier than raising a launch price.

## 6. Which name helps Dutch people find the app?

The name matters less than it seems:

- Apple ranks on "text relevance (matches for your app's title, subtitle, keywords, and primary category)" plus downloads, ratings and reviews. It does not publish weights ([App Store search](https://developer.apple.com/app-store/search)). The name (30), subtitle (30) and hidden keyword field (100) are all matched ([App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)).
- What Dutch users search for, from the NL store on 14 Nov 2026: "buienradar", "buienalarm", "regen", "regenradar", "buien", "neerslag". Rankings for each (top three):
  - "regenradar": Buienalarm, Buienradar, Weer & Radar.
  - "buien": Buienalarm, Buienradar, **Pluutje: Regenradar** (50 ratings).
  - "neerslag": Buienalarm, "Regenmeter & Neerslag Tracker" (4 ratings), Buienradar.
  - "regen apple watch": Buienalarm, Weer - buienradar: Weer24, meteoblue.
  - The ratings counts are 154,953 for Buienradar and 49,000 for Buienalarm. A new app will not outrank them for the head terms by name alone.
- "Pluutje: Regenradar" and "KNMI Weer" rank for "buien" without "buien" in their visible name. That suggests the word comes from their subtitle or hidden keywords (I cannot see keyword fields, so this is an inference).
- Apple lets Dutch metadata differ: add a Dutch (nl) localisation with its own name, subtitle and keywords ([Localize app information](https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information)). Dutch is in the supported list ([App Store localizations](https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations)). Apple also says "You can also translate your app's name" ([product page guide](https://developer.apple.com/app-store/product-page)).

How App Store Connect handles names across languages:

- The name is set per localisation, so "BuienWatch" for Dutch and "Rain Ahead" for English is allowed in principle. The same name can belong to different apps in different localisations ([AppAvailability](https://appavailability.com/app-name-availability), a third-party tool; Apple's form says the same about one title per localisation).
- Which one a Dutch user sees depends on the App Store language for their location, device language and Josh's primary language ([App Store localizations](https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations)). Josh's plan has English (U.K.) as primary with Dutch added (`LAUNCH.md`).
- Two names for one app splits recognition: Dutch reviews, a Dutch friend's recommendation and an English review would each name a different app. I would not do it for a single watch utility.
- The name can be edited until first submission and later only with a new version ([App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)). Keywords also change only with a version.

Suggested Dutch metadata (to confirm against `research/launch-runbook.md` C5): name "Rain Ahead"; subtitle "Regen de komende 2 uur" (22 characters); keywords such as `buien,regenradar,neerslag,regenmelding,fiets,weer,horloge` (words not already in the name or subtitle; no "buienradar", no "buienalarm").

## 7. Price and EU trader status

- Apple lists the factors: revenue from the app ("In-App Purchases ... paid or ad-sponsored"), commercial practices towards consumers, VAT registration, and developing the app in a professional capacity. A hobbyist "with no intention of commercializing it ... may not be considered a trader" ([Apple DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements)).
- So a paid app, an in-app purchase or ads points to trader. Free with no ads and no purchase is the only price that might not.
- If trader: Apple publishes address (an individual may use a P.O. Box, with proof of association), phone and email on the product page "in any of the 27 territories of the EU". Apple verifies email and phone with two-factor codes.
- Apple also lets a trader switch the status off for specific apps, but that follows the legal self-assessment; a paid app is hard to call non-commercial.
- US and UK pages do not show the trader details; the display is for the EU's 27 territories. The UK is not in the EU. Even a developer who does not sell in the EU must declare a status.
- Josh's stated aim is to sell. The price recommendation therefore assumes trader status. Another agent is looking at ways to limit the exposure.

## 8. Not checked, and what to do

1. BOIP, EUIPO/TMview and UKIPO word-mark searches for BUIENWATCH, RAIN AHEAD, BUIENRADAR, BUIENALARM. Needs a real browser (CAPTCHA and bot blocks). Mac mini job.
2. Whether App Store Connect accepts "Rain Ahead" and "RainWatch" for a new record. Only the live create-app dialog answers that.
3. Buienradar's and Buienalarm's trademark registrations, their classes, and whether either has objected to "Buien-" names.
4. The period of Buienalarm's "Super" and "Family" purchases, and Buienradar's price variants.
5. Real demand for a €2.99 watch utility: no source tested this.

## Sources

Apple: [Review Guidelines](https://developer.apple.com/app-store/review/guidelines), [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information), [Localize app information](https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information), [App Name Dispute form](https://www.apple.com/legal/intellectual-property/dispute-forms/app-store/app-name-dispute.html), [Trademark List](https://www.apple.com/legal/intellectual-property/trademark/appletmlist.html), [Guidelines for Using Apple Trademarks](https://www.apple.com/legal/intellectual-property/guidelinesfor3rdparties.html), [Marketing guidelines](https://developer.apple.com/app-store/marketing/guidelines), [Set a price](https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price), [WeatherKit](http://developer.apple.com/weatherkit), [Developer Program details](https://developer.apple.com/programs/whats-included), [DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements), [App Store search](https://developer.apple.com/app-store/search).

Stores: the iTunes Search API and the store pages linked in section 5.1.

Other: [NRC on the weather-app conflict](https://www.nrc.nl/nieuws/2025/02/07/het-rommelt-tussen-de-weer-apps-a4882406), [BOIP merkcheck](https://www.boip.int/nl/merkcheck), [Infoplaza](https://www.infoplaza.com/nl/consument), [Galva EUR price table](https://galva.io/tools/apple-pricing-tiers/currency/eur), [AxonBuild](https://axonbuild.com/blog/app-store-listing-name-and-description), [AppAvailability](https://appavailability.com/app-name-availability). In-repo: `LAUNCH.md`, `research/launch-playbook.md`, `research/launch-runbook.md`, `research/global-data.md`, `research/app-review-readiness.md`.

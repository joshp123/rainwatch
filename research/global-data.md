Written by AI on 2026.11.14 by model claude sonnet 5.5.

# Rain: data plan for the Netherlands and the world

## The answer

Replace Buienradar with KNMI in the Netherlands, and put a small server of ours between the watch and every data source. KNMI's rule against embedding its key in an app means the server is needed even for the Netherlands alone.

The server fetches open radar feeds, cuts out the area around each place, and hands the watch one small response in one format. The watch never talks to KNMI, DWD or anyone else, so adding a country later changes the server and leaves the app alone.

Where a country publishes its own free two-hour nowcast (NL, DE, the Nordics, Austria) we pass it on. Where it publishes only radar (UK, US, Canada, the rest of Europe) the server extrapolates the radar forward itself, using the same method KNMI uses. Where there is no usable radar (Australia, most of the world) the app falls back to Apple WeatherKit and says honestly that the horizon is shorter or hourly only.

Nothing I found is better than KNMI for the Netherlands. Nothing free and open covers "everywhere in the world" at minute level. The world beyond the open-radar countries costs money or accepts a worse answer, and section 6 lists exactly what gets worse.

Nothing here needs Josh to pay, and I signed up for nothing. Two free registrations are on Josh's list at the end: a KNMI key, and (only if France is wanted) a Météo-France key.

## 1. What I called for real

Today (14 November 2026, about 12:00 UTC) it was dry almost everywhere. I checked about 40 cities across Europe, North America, Asia and Australia, and only Kuala Lumpur showed rain. So **none of these calls tests forecast skill**. They test coverage, format, time step, latency and access. A rainy-day side-by-side against Buienradar is still to do and I list it at the end.

| What I called | What came back |
|---|---|
| KNMI `radar_forecast` 2.0 with the published anonymous key | Works. 25 frames, +0 to +120 min in 5-minute steps. File for the 12:00 run was created at 12:01:36. 224 KB. |
| KNMI grid, decoded with h5py and pyproj | 700 x 765 km at 1 km, polar stereographic. Rotterdam, Brussels, Cologne, Hamburg and Dover are inside it. Paris (too far south), Copenhagen and London are outside. Values are mm per 5 minutes (`0.01 x PV`). |
| KNMI radars feeding the grid | Eight in the file: Den Helder, Herwijnen, Jabbeke, Helchteren, Wideumont (Belgium), Essen, Neuheilenbach (Germany) and Borkum (marked not operational). |
| Open-Meteo `minutely_15`, six cities | Answers everywhere, all zeros today. Kuala Lumpur showed a smooth 0.2 to 0.1 mm ramp, which is what interpolation from hourly data looks like. |
| MET Norway nowcast, `api.met.no` | Oslo, Copenhagen, Stockholm, Helsinki and Gothenburg: `radar_coverage: ok`, 23 steps of 5 minutes, 12:05 to 13:55. Hamburg and Tallinn: 200 with `no coverage` and one step. Rotterdam, Glasgow, Berlin, New York, Sydney: 422 "outside the Nordic area". Reykjavik: 422. |
| DWD `composite_rv` listing | The 12:00 run was posted at 12:03:44. A `LATEST` file exists. |
| Bright Sky `/radar` (a free JSON wrapper over DWD RV) | Works for Berlin and for Rotterdam. Needs a gzip-capable client. Dry today. |
| GeoSphere Austria INCA nowcast, Vienna | Works with no key. 15-minute steps, 12 steps (3 hours), 1 km. Dry today. |
| Met Office UK radar on open AWS S3 | The 12:00 file appeared at 12:05:33. 1 km UK rain-rate composite, 15-minute steps, 407 KB, grid 1725 x 2175 km. |
| NOAA MRMS on open AWS S3 | `PrecipRate` files every 2 minutes. The 12:04 file was posted at 12:06:41. |
| ECCC GeoMet WMS, `RADAR_1KM_RRAI` | Time dimension 09:00 to 12:00 in 6-minute steps, no key. |
| JMA nowcast tile index | Base times every 5 minutes, no key. |
| MeteoSwiss STAC | Radar `PRECIP` collection exists (5-minute, 1 km, last 14 days). I did not download a file. |
| BoM anonymous FTP | Radar PNGs are listed. The licence forbids commercial use (section 3). |
| RainViewer `weather-maps.json` | 13 past frames, 10-minute spacing, **`"nowcast": []`**. The free API no longer has forecast frames. |
| OPERA via MeteoGate ORD API, no key | The API answers anonymously and lists a 3800 x 4400 km, 1 km composite. A point query for RATE returned four 15-minute values. I could not fetch a composite file: the S3 bucket listing returned two unrelated objects. Treat file retrieval as unverified. |
| Météo-France, WeatherKit, Rainbow.ai, Tomorrow.io | Not called. Each needs an account or a developer token. I read their terms instead. |

## 2. The Netherlands

**Use KNMI `radar_forecast` 2.0.** Verified facts:

- It is a two-hour, five-minute precipitation nowcast on a 1 km grid, made with an operational pySTEPS implementation, started from KNMI's real-time five-minute radar rainfall product.
- Licence CC BY 4.0, free for commercial use. Credit "Source: KNMI", say so when you modify or derive the data, and do not imply KNMI endorses the app. (KNMI fair-use policy.)
- The grid covers the Netherlands, Belgium, Luxembourg, western Germany and Kent, with Belgian and German radars feeding it. This also covers Rain's wider Benelux and border users.
- Latency about 1.5 minutes in my one sample.
- Past frames: each file's first frame (+0) is the analysis. Keep the last six files to show the last 30 minutes. This is my reading of the file layout, not a documented feature.

**KNMI forbids an app key.** Its FAQ says plainly that a key must not go in a mobile app and tells you to proxy through your own backend and cache. The anonymous key is shared by everyone, limited to 3,000 requests an hour and 50 a minute across all users, and expires on 1 August 2027. A registered key gives 1,000 requests an hour of its own and never expires. The server needs about 12 listing calls an hour plus 12 downloads, so the registered key is plenty. KNMI also asks you to use its MQTT notification service instead of polling.

**Is anything better?**

- DWD RV covers Germany and, as the Bright Sky call showed, reaches into the Netherlands, but it is the same kind of product and uses fewer Dutch radars.
- Rainbow.ai claims the top short-term accuracy worldwide, but the ranking site it cites is its own affiliate. That is a vendor claim. I could not check it.
- I found no public product better than KNMI for the Netherlands.

**Is KNMI as good as Buienradar?** Unverified. Both were dry today. Buienradar also adds its own processing that I cannot see. This needs a rainy-day side-by-side before the marketing claims anything. KNMI's feed is deterministic radar extrapolation, so expect the same limits as any such nowcast: it moves existing rain well, and it cannot predict showers that have not formed yet.

## 3. The rest of Europe and the world, source by source

**Free, open, commercial use allowed.** Latency is what I measured; "documented" means I read it but did not measure it.

| Source | Area | Step and horizon | Resolution | Latency |
|---|---|---|---|---|
| KNMI nowcast | NL, BE, LU, W Germany, N France, Kent | 5 min, 2 h | 1 km | 1.6 min measured |
| DWD RV (radar plus DWD's own nowcast) | Germany, plus edges of neighbours | 5 min, 2 h | 1 km | 3.7 min measured |
| MET Norway Nowcast | Norway, Sweden, Finland, Denmark where radar covers | 5 min, 2 h (point only, no frames) | about 1 km | about 3 min |
| GeoSphere INCA nowcast | Austria and surroundings (45.5 to 49.5 N, 8.1 to 17.7 E) | 15 min, 3 h | 1 km | 5 to 10 min |
| OPERA composites (EUMETNET) | Most of Europe | 15 min rain rate, 2 km. Max reflectivity 5 min, 1 km. Observations only. | 1 to 2 km | about 15 min documented |
| Met Office UK radar (AWS) | UK and Ireland | 15 min, observations only | 1 km | 5.5 min measured |
| MeteoSwiss PRECIP | Switzerland and borders | 5 min, observations only | 1 km | under 1 min documented |
| NOAA MRMS | US (CONUS, plus other domains) | 2 min, observations only | about 1 km | 2.7 min measured |
| ECCC GeoMet | Canada and northern US | 6 min, observations only | 1 km | under 8 min |
| JMA nowcast tiles | Japan | 5 min, up to 1 h | about 1 km | under 5 min |
| Météo-France radar mosaic | France | 5 min, observations only | 500 m to 1 km | not measured |

Notes that decide how to use each one:

- **DWD.** Licence is GeoNutzV: free, with source credit. The calibrated nowcast products RQ and RE stop in early 2026; RV and its one-hour sum RS carry on. RV is a `.tar` of ODIM HDF5 files, one per lead time. Bright Sky decodes it for you, but I did not verify its terms for commercial use, so the server should read DWD directly.
- **MET Norway.** CC BY 4.0 and explicitly free for commercial use, paid apps included (their FAQ). You must send a User-Agent with contact details. A mobile app's total traffic must stay under 20 requests a second, and they ask apps not to call directly, for the privacy of user coordinates. The call only works where radar covers: Hamburg, for example, returns "no coverage".
- **GeoSphere.** CC BY 4.0, no key. Rate limits not read. The 15-minute step is coarse for a five-minute rain line.
- **OPERA.** The EUMETNET composites are CC BY 4.0 and openly available through MeteoGate since May 2026. Anonymous use is limited to 60 requests an hour and registered use to 600 an hour, which is plenty for a server pulling one file per 15 minutes. The product is observations only, so we extrapolate it ourselves. The 2 km, 15-minute rain-rate composite is the coarsest thing in this plan. Use it as the Europe-wide floor and prefer any national feed above.
- **Met Office.** The AWS data is licensed CC BY-SA 4.0, credited "British Crown copyright, the Met Office". ShareAlike applies to adapted material. A cropped, recoloured frame is probably an adaptation, so the frames we serve would have to carry the same licence. Josh should decide whether that is acceptable, and it needs a lawyer's read rather than mine. The Met Office's own DataHub is a different product: free tier, limits and a "Powered by Met Office data" credit, but its radar is not part of the free offer.
- **MeteoSwiss.** Open, credit "Source: MeteoSwiss". Their nowcast (INCA-CH) is only released on request, so Switzerland needs our own extrapolation of the radar.
- **MRMS.** US federal data, no licence barrier. gzip GRIB2, CONUS only (plus separate domains for Alaska, Hawaii and the Caribbean that I did not list).
- **ECCC.** Licence allows commercial use with attribution "Data Source: Environment and Climate Change Canada".
- **JMA.** The Public Data License is compatible with CC BY 4.0, with source credit and a note when you edit the content. **Warning, inferred from JMA's terms page, not tested:** Japan's Meteorological Service Act requires a licence to provide your own *forecasts* to the public. Showing JMA's own nowcast unchanged is the safe route. Do not run our extrapolation on Japan.
- **Météo-France.** Etalab Open Licence 2.0 (commercial use allowed). Credit "Météo-France" and the date of last update. It needs a free account and API key, with a limit of 850 calls per five minutes, so I did not call it. Its AROME-PI model nowcast is available through the same portal.
- **Bureau of Meteorology (Australia).** Anonymous FTP radar is "not for commercial use". Using it in a sold app needs a BoM Registered User data licence, which is a paid, cost-recovery arrangement. **Do not use BoM data.**

**Apple WeatherKit.**

- Verified from Apple's support page: next-hour precipitation exists for **Australia, Ireland, Japan, the UK and the US**. It does not exist for the Netherlands or the rest of Europe.
- One hour, minute by minute. Apple builds it from national weather service data.
- The call comes straight from the watch (watchOS 9 and later), with no server and no key, because the entitlement is in the developer account.
- Cost: 500,000 calls a month included with the developer membership, shared by every app on the account. After that the plans are US$49.99 (1M), $99.99 (2M), $249.99 (5M) and $499.99 (10M) a month. Apple publishes no rule for how a request containing several data sets is counted.
- Terms to follow: show the Apple Weather mark and the legal link on every screen with its data. Apple requires an EULA line that real-time weather guidance is "at your sole risk", and forbids use "for emergency or life-saving purposes". The agreement also bars caching beyond a short, performance-only period and bans building a secondary database from it. That rules out serving WeatherKit data to many users from our server.
- Developer reports (MacRumors comments, not tested by me): Apple's Australian rain forecasts are less accurate than BoM's, because Apple does not use BoM data.

**Open-Meteo.**

- The free API is non-commercial only: no subscriptions, ads or "commercial products". An app that charges, or has in-app purchase, counts as commercial (their terms).
- Commercial use needs a paid plan (Standard is 1M calls a month). I could not read the price from the pricing page.
- `minutely_15` is native in Central Europe and North America and interpolated from hourly data elsewhere (their features page, matching the Kuala Lumpur sample).
- It is model output, not radar. Fine for "will it rain this afternoon". Poor for "in 10 minutes".
- Self-hosting is allowed: code under AGPLv3 and data under CC BY 4.0. That is a big server job and gives the same model-quality answer.

**Rainbow.ai.**

- The only commercial minute-level nowcast API I found that allows commercial app use and publishes prices: **US$0.10 per 1,000 requests after 5,000 free a month**. Its tiles API is $0.20 per 1,000 after 30,000 free.
- Claims: 1-minute steps, 4 hours ahead, 1 km, updated every 10 minutes, global.
- Its own page says it "covers the entire developed world" and that coverage beyond radar reach is "coming soon". So the global claim is not yet true by their own account.
- Needs a card and an account. I did not sign up.

**RainViewer.** Not usable. The free API is "personal and educational use only", past frames only, 10-minute spacing, maximum zoom 7, 100 requests per IP per minute. Since 1 January 2026 it has no nowcast. I confirmed the empty `nowcast` list live. Commercial use needs a negotiated deal. A community project, LibreWXR, rebuilds a RainViewer-compatible service from open sources (developer-reported, not tested).

**Not worth it:**

- Tomorrow.io: free plan 500 calls a day and 25 an hour. Third-party comparison pages say non-commercial; paid plans are "quoted by sales".
- OpenWeatherMap One Call 3.0: a 60-minute minutely forecast, 1,000 free calls a day, then about $0.0015 a call, and a card is needed even for the free calls (developer-reported).
- Pirate Weather: 10,000 free calls a month for personal use; the minutely data is model-based outside the US.
- Météo-France, MeteoSwiss and Austria's national nowcasts are useful, but only inside their own countries.

## 4. The architecture

**One server, one response format.**

The watch asks one endpoint: "rain for this place". The response carries:

- a rain-rate series in mm/h from 30 minutes ago to 120 minutes ahead at 5-minute steps, with the same series bent into the app's existing graph;
- a small radar grid for the radar page;
- which source it came from, the credit text to show, when the data was valid, and a `coverage` field (`full`, `observed only`, `hourly only`, `none`).

The watch rounds the place to about 1 km before asking. That is privacy by design and also a cache key. The server logs nothing that ties a place to a person.

**How the server chooses.** A list of areas, checked in order, first match wins:

1. KNMI nowcast: the Netherlands, Belgium, Luxembourg and the rest of its grid.
2. DWD RV: Germany outside the KNMI grid.
3. MET Norway: Norway, Sweden, Finland, Denmark, where `radar_coverage` is `ok`.
4. GeoSphere INCA: Austria and its grid.
5. National radar plus our extrapolation: UK (Met Office), Switzerland (MeteoSwiss), US (MRMS), Canada (ECCC), France (Météo-France, once keyed).
6. OPERA plus our extrapolation: the rest of Europe.
7. On-device WeatherKit minute forecast: Australia, Ireland, Japan, and anywhere above that lacks open radar.
8. WeatherKit hourly forecast, labelled "Hourly only": the rest of the world.

Overlaps (Hamburg, Dover, the Austrian border) go to the national product with the higher resolution and shorter delay.

**Our extrapolation (item 5 and 6).** KNMI's own nowcast is open-source pySTEPS applied to radar. Running pySTEPS ourselves on another country's radar gives the same class of product: it moves rain along and cannot create it. NWP blending is not included; I would not build that at launch. A deterministic extrapolation for two hours is a known decay: good for 30 to 60 minutes, then it degrades fast. The doc for LibreWXR makes the same point and limits its own nowcast to 60 minutes beyond radar reach. Mark any extrapolated series visibly.

**Launch phases, so the work stays small:**

- **Launch:** items 1 to 4, plus items 7 and 8 on the watch. That gives full five-minute nowcast in the Netherlands, Germany, the Nordics and Austria, and a sensible answer everywhere else, with no extrapolation code.
- **Next:** add our extrapolation for the US (MRMS), UK, then Europe (OPERA), then Canada, in order of user numbers once the app is live.
- **Later and only if wanted:** Rainbow.ai as a paid global layer for the places we cannot cover.

**What the watch needs to change.** The app currently calls Buienradar's graph (`percentageValue` height) and image URLs directly. The new server returns mm/h. The graph needs a mm/h-to-height mapping to keep the Light, Moderate and Heavy lines. The mapping itself is a design choice. The radar page paints a small grid with its own palette rather than loading map tiles, so no third-party tile licence is needed.

## 5. What the radar shows outside the Netherlands

The radar page draws the 1 km grid the server cut out, centred on the user, over an Apple Map, with the same Digital Crown scrubbing.

- **NL, DE, AT:** real frames from the national nowcast, 5 minutes (15 in Austria), up to +2 hours.
- **Nordics:** MET Norway's API returns a point nowcast only, no grid. I did not test MET Norway's separate radar image product. Until tested, the Nordic radar page shows observed frames only, or none.
- **UK, US, Canada, Switzerland, France, rest of Europe:** past frames as observed. Future frames are our extrapolation, stamped "projected".
- **Australia, Japan, elsewhere:** no frames. The radar button is hidden, and the app says where its rain data comes from.

Frame size is small: a 100 x 100 km area at 1 km is 10,000 cells. At 4 bits a cell that is 5 KB a frame, about 150 KB for 31 frames before compression. (Inferred from the grid sizes, not measured.)

## 6. What is worse outside the Netherlands

- **Horizon.** Two hours in NL, DE, Nordics and (coarsely) Austria. One hour from WeatherKit. Hourly only for most of the world.
- **Step.** 5 minutes in NL and DE, 15 minutes for OPERA and the Met Office, and Austria.
- **Delay.** 2 to 5 minutes in NL, DE, US and UK. About 15 minutes for OPERA, documented, so "rain in 10 minutes" is weak over most of Europe.
- **Accuracy of intensity.** Real-time radar has no rain-gauge correction. Heavy rain and drizzle are the least reliable.
- **Gaps.** Radar does not cover mountains, the sea or several countries. The app must say "no radar here" rather than draw a dry line. The existing `notCovered` failure in `Buienradar.swift` is the right shape.
- **Mixed products.** The user may notice different behaviour when they travel, for example a 15-minute step in Austria. The server resamples to 5 minutes and sets `coverage` so the UI can tell them.
- **Legal conditions differ by country.** Attribution text changes per source, the Met Office needs ShareAlike, Japan restricts own forecasts, and BoM is off limits. The credit line in the app must switch with the source.

## 7. Cost at 10,000 users

Assume each user triggers about 20 fetches a day (watchOS reloads a complication about every 15 to 20 minutes while the face is up; `research/freshness.md`). That is 200,000 requests a day, 6 million a month, and 5 to 10 KB a response (inferred), so 30 to 60 GB a month.

| Item | Monthly cost | Basis |
|---|---|---|
| KNMI, DWD, MET Norway, GeoSphere, MRMS, ECCC, OPERA, Met Office, MeteoSwiss | €0 | Open data. Our ingest is small and independent of user count, because every request for the same 1 km cell within five minutes is served from cache. |
| The server and a CDN in front | about €5 to €20 | Inferred from typical small-VPS pricing. I did not check prices today. |
| WeatherKit | €0 up to 500,000 calls | Included in the developer membership. If 15% of users (1,500) are in WeatherKit-only places: about 0.9M calls a month, which needs the 1M plan at $49.99. All 10,000 users on WeatherKit would be 6M calls, the 10M plan at $499.99. Both are inferences that depend on how Apple counts requests. |
| Rainbow.ai, only if added | about $90 | 1,500 users x 600 calls = 0.9M calls at $0.10 per 1,000 after the free 5,000. With caching per cell, the real bill is lower. All 10,000 users uncached would be about $600. |

So the launch plan costs about the price of a small server. The paid options are an extra, and each can be switched on per region.

## 8. Verified, reported, inferred

**Verified by me today** (calls, or documents read in full):

- KNMI nowcast works, with its grid, radars, calibration, timing, licence, fair-use rules and key limits.
- MET Norway coverage in 7 cities, licence, terms and the 20 requests per second limit.
- DWD RV timing and licence. Bright Sky radar works.
- GeoSphere nowcast call and licence.
- Met Office UK radar: timing, grid, CC BY-SA.
- MRMS timing. ECCC time steps and licence. JMA tile index and terms. BoM licence refusal.
- RainViewer: no nowcast, personal use only, from both the API call and its own terms.
- WeatherKit: countries, price, attribution and the licence text on caching and emergencies.
- Open-Meteo: non-commercial terms and interpolation outside Central Europe and North America.
- OPERA: the API answers anonymously and the composite exists. Licence and rate limits are from EUMETNET's own documents.

**Reported by others, not tested by me:**

- BoM versus Apple accuracy in Australia (MacRumors comments).
- OpenWeatherMap's call price and card requirement. Tomorrow.io's non-commercial free plan (comparison sites).
- LibreWXR's behaviour. Rainbow.ai's accuracy ranking (the ranking site is theirs).

**Inferred:**

- That KNMI's quality matches Buienradar's.
- That the Met Office's ShareAlike reaches our cropped frames.
- That JMA's Service Act applies to our extrapolation.
- Frame sizes, server costs, call counts, and how WeatherKit counts requests.
- That OPERA files can be fetched; the API works but I did not get a file.
- That the first frame of each KNMI file can serve as the observed past.

## 9. For Josh and Opus to do next

1. **Register a free KNMI developer account** and request an Open Data API key (anonymous key expires 1 August 2027). I did not sign up. This is Josh's account, per KNMI's one-account-per-user rule.
2. **Rainy-day side-by-side** of KNMI against Buienradar, ideally 20 or more sample points, plus gauge data if easy. Buienradar is for comparison only and must not be shipped. This is the only way to know "as good".
3. **Decide Met Office ShareAlike.** If unwanted, the UK uses WeatherKit's hourly and next-hour forecast and shows no radar frames.
4. **Decide whether France matters.** If so, register for the free Météo-France API key.
5. **Test the Nordic radar images** from MET Norway before promising them on the radar page.
6. **Fetch one real OPERA composite file** before building the Europe-wide layer.
7. **Add the credit lines** to the app: "Source: KNMI" (modified, not official), and the other credits only when those sources go live. Add the Apple Weather mark and legal link before any WeatherKit data appears. App Review rejects WeatherKit apps without it (developer-reported).

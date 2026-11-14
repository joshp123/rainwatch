<!-- Written by AI on 2026.11.14 by models claude fable 5.2 (author) and gpt-6 astra (challenge and independent tests), at Josh's request: "Get a better design and discuss with other agents ... think from first principles". Revised the same day after a review by a fresh claude opus 5.5 that saw none of the discussion. A design: nothing is built, deployed or paid for. It replaces PROPOSAL.md. -->

# BuienWatch's server

## The design in seven lines

1. **Once for every KNMI run** (one each 5 minutes) a small job turns KNMI's files into **two files**: a pack with the whole forecast cut into 32 km squares, and a 1 KB contents list called `latest`.
2. **The watch works out which square it is in by itself**, reads `latest`, and downloads only its own square (about 2 KB in rain, nothing when dry). The radar page downloads the squares its map covers.
3. **Only 528 squares exist**, and everyone in the same square asks for the same bytes, so the CDN can serve them from its cache.
4. **It runs on AWS in Ireland**, next to KNMI's own files: one scheduled function, one bucket, CloudFront. No machine to look after.
5. **For 1,000 Dutch users the server costs under $1.50 a month,** at the usage assumed below and with AWS's free allowances unused. Above about 3,000 users, each further 1,000 adds $3.78 in CloudFront requests, at $1.20 per million.
6. **A new forecast is available to watches about 6 minutes after the radar measured it.** A machine that is always on could make that about 3 minutes, for about EUR 6.64 a month. watchOS decides when each watch actually fetches it, usually every 15 to 30 minutes.
7. **The larger bill is Apple's, not ours:** outside KNMI's area the app uses WeatherKit, which is free for about 333 users and then costs $49.99 a month or more.

## Words used here

- **Plain forecast:** KNMI's operational 2-hour forecast, which moves the current rain along.
- **Blend:** KNMI's pilot forecast that mixes that with its weather model, in 20 versions.
- **Season test:** our scoring of both over 66 rainy days (`research/verification/season.md`).
- **Run:** one KNMI forecast, named by its radar time. There is one every 5 minutes.

## What actually has to happen

- **The work is small and does not grow with users.** Nine KNMI files (one plain forecast, one blend, seven observed radar pictures; 0.04 to 40 MB each) become one forecast grid: 765 x 700 cells, 31 time steps. Measured on real rainy files: 2.3 seconds and 0.54 GB on a Mac. It happens 8,640 times a month whether there is one user or a million.
- **Users only add requests.** A watch refreshes about 44 times a day (Josh's watch log) and fetches a few KB each time. The fee per request is the cost that grows with users; data volume and storage reads grow too, but stay small. So the design's job is to make each request cacheable and to send as few as possible.
- **Freshness has two parts: when we publish, and when the watch asks.** A complication usually refreshes every 15 to 30 minutes, and watchOS can delay it much longer, above all in Low Power Mode. So minutes matter on the server and seconds do not.

## What is computed, and how often

A scheduled function runs **once per run, 5 minutes after the run's radar time**. It asks KNMI for that run's three files by name and builds:

| Minutes | Source | Why |
|---|---|---|
| -30 to -5 | KNMI's observed radar | Real past frames for the radar page, not old forecasts |
| 0 to +30 | KNMI's plain forecast | Scored best here in the season test |
| +35 to +120 | KNMI's blend | Scored best here. A cell is wet when at least 10 of the 20 versions say so, as in the season test; its strength is the middle of the 20 |

- **Why 5 minutes after, and not sooner.** KNMI's rules say not to check more often than a dataset updates, not to download a file twice, and not to start jobs exactly on the minute ([fair use](https://developer.dataplatform.knmi.nl/fair-use)); it can revoke a key without notice. So the job asks once per run. Over 300 runs (13 and 14 November) the plain forecast arrived 1.7 minutes after the measurement (worst 4.4) and the observed radar after 1.5 (worst 4.3): at 5 minutes both were there every time. The blend arrived after 3.8 (worst 6.4): at 5 minutes it was there 291 times in 300.
- **If the blend is not there,** the job publishes that run with the plain forecast all the way to 120 minutes, and `latest` says so. It never publishes a run twice and never mixes two runs.
- **The blend's gain is small.** The season test's own words: "The gain is small: about 0.03 CSI over the whole two hours. Plain alone is a fair launch choice", and it "depends on a pilot that KNMI may end". The blend also costs most of the job's code and memory. It stays in because the goal is the best forecast the open data allows, and the job falls back to the plain forecast by itself if KNMI ends the pilot.
- **Each value is one byte:** 0 is dry, 255 is "no radar data", and 1 to 250 is the rain rate from 0.1 mm/h upward in steps of about 5%. The rounding error is at most about 2.3%, and every 1 km cell is kept. A cell voted wet whose middle value is below 0.1 mm/h is drawn as the lightest rain. That keeps the tested wet or dry decision and makes downloads a quarter the size of exact values.
- **"No data" never becomes "dry".** The plain forecast file does not mark the area the radars cannot see (measured: it has no such cells). The observed radar file does (66,070 cells), so the mask comes from there.
- **Calls to KNMI: about 36 an hour of the 1,000 allowed.** Three download links per run, with a few seconds' random wait first and a User-Agent that names the app. The job keeps each observed radar file in the bucket for a day, so it downloads each one once and reads the six earlier ones from there. A missing past frame stays "no data".

## The two files

**`runs/<run time>.bin`, the pack.** The grid is cut into 32 x 32 km squares: 24 rows x 22 columns = 528. Each square holds all its 1 km cells and all 31 time steps, compressed with raw DEFLATE, the form Apple's Compression framework reads; decoding it in Swift is still to be checked when the app is built. The squares sit back to back, row by row. Written once and never changed, so it can be cached for a day.

**`latest`, the contents list.** A small JSON file: a format version, the run time, whether the blend is in it, the pack's name, and the length in bytes of each of the 528 squares. Length 0 means every cell has data and is dry for the whole window. -1 means no radar coverage at all. A square with some of each is stored, with 255 in the cells that have no data. Cached for 60 seconds. The job uploads the whole pack before it replaces `latest`, so a watch never finds half a run.

Measured on the rainy run of 13 November 12:30 UTC (`server/pack_probe.py`). The prototype used zlib's wrapped form, which is 6 bytes larger per square with rain than raw DEFLATE:

| | Size |
|---|---|
| `latest` | 1,775 bytes; 723 compressed |
| Whole pack | 274 KB |
| The square for Rotterdam | 1,758 bytes |
| Largest square in the country | 7,899 bytes |
| Radar page, 30 km view | `latest` + 2 requests, 10 to 14 KB |
| Radar page, 120 km view | `latest` + 4 requests at the places tested (5 at most), 48 to 61 KB |
| Squares: with rain / dry / no coverage | 231 / 253 / 44 |

The prototype read each place back through `latest` as a watch would, and the values matched the encoded grid.

**Why one pack and not 528 small files.** One file per square would be simpler for the watch: one plain request and no contents list. But storage charges for every write, and every square would have to be rewritten for every run, so that the watch can tell how old it is. 528 files x 8,640 runs = 4.6 million writes a month = $22.81 on S3. The pack and `latest` are two writes a run = $0.09. Map tile archives (PMTiles) and cloud-optimised GeoTIFF use the same idea: one file, a list of positions, and requests for byte ranges.

**What that choice costs.** In rain a refresh is two requests, one after the other: the watch must read `latest` first to learn the newest run and where its square sits in the pack. The second request can reuse the first one's connection, and adds one round trip. Its battery cost has not been measured on the watch. In dry weather a refresh is one request of 0.7 KB.

## How the watch gets its square and the ones around it

1. **Its own cell.** KNMI's grid is a flat map with 1 km cells. Turning latitude and longitude into row and column is a fixed formula, about ten lines of arithmetic with no library. Checked: Rotterdam is row 452, column 321, by our formula and by the standard projection library. The square is `row / 32, column / 32`.
2. **Read `latest`** (one request, 0.7 KB). If its square is dry, it is finished. If the square has no coverage, it shows "no radar data".
3. **If not, one more request** for that square's bytes: a normal HTTP range request on the pack, with the position added up from the lengths in `latest`. It unpacks the square and takes its own cell's 31 values.
4. **The radar page** needs the squares under the map. Squares in the same row are neighbours in the file, so after `latest` it sends **one request per row of squares**: 2 for the 30 km view, up to 5 for the 120 km view. Downloading the whole pack in one request would be simpler, but it is 274 KB in rain against 10 to 61 KB, on a watch.

Only the 32 km square leaves the watch, never the position. The CDN also sees what any server sees, such as the IP address.

## How this avoids flooding the CDN

- **A URL with latitude and longitude would be a different address for nearly every user,** so the CDN could cache almost nothing.
- **Here every address is shared.** There is one `latest` and one pack per run. A thousand watches in Rotterdam ask for the same byte range.
- **Measured on real CloudFront** (two 26 MB files that were not in its cache): after one small range was fetched, a different range 200 bytes away came from the cache; ranges about 1 MB away did not. The pattern fits fetching in 1 MB blocks. The rainy pack is under 1 MB, so each CloudFront cache could serve it after one read from S3. AWS's documentation promises range caching but not the block size, so the cost table also shows the case where CloudFront caches nothing.

## Freshness

| Step | Time after the radar measurement |
|---|---|
| KNMI publishes the plain forecast | 1.7 min typical, 4.4 worst seen |
| Our job starts | 5 min, plus a few seconds |
| Build and upload | about 10 s allowed (2.3 s measured on a Mac) |
| `latest` cached at the CDN | up to 1 min more |
| **New run available to watches** | **about 5.5 to 6.5 min** |
| watchOS refreshes the complication | every 15 to 30 min, sometimes much longer |

- **The trade.** KNMI's preferred route is its push service, which tells a listener the moment a file exists. That needs a process that is always connected, so a machine. With one, a run would be available about 3 minutes after the measurement. Having no machine costs about 3 minutes.
- **The watch shows the data's age from the run time in `latest`,** never from when it fetched. A forecast that arrives 6 minutes after its run has 114 minutes left, and the app must not invent the rest.
- **If KNMI or the job fails,** `latest` stays old and the app's existing "Forecast from 15:12" and "No data" states take over. An alarm emails Josh when nothing has been published for 15 minutes.

## What it costs

Prices are the vendors' own, read on 14 November 2026: [CloudFront](https://aws.amazon.com/cloudfront/pricing/pay-as-you-go/), [Lambda](https://aws.amazon.com/lambda/pricing/), [EventBridge](https://aws.amazon.com/eventbridge/pricing/), [S3 Ireland price list](https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonS3/current/eu-west-1/index.json). Free allowances are per AWS account each month; if Josh's other sites use part of them, less is left.

### The server, for users in KNMI's area

**Requests per user per month, assumed:**
- 50 refreshes a day x 2 requests x 30 days = 3,000. Josh's watch made 44 refreshes a day; Apple says 40 to 70 is typical. In dry weather a refresh is 1 request, so 2 is the high end.
- 1 radar session a day x 5 requests (`latest` plus 4 rows) x 30 = 150.
- **Total: 3,150.** At Apple's top figure of 70 refreshes it is 4,350; with dry weather half the time it is about 2,400.

**Fixed costs, the same for any number of users:**

| Item | Arithmetic | A month |
|---|---|---|
| S3 writes | 3 files (pack, `latest`, one observed radar file) x 8,640 runs = 25,920 x $0.005 per 1,000 | $0.13 |
| S3 reads by the job | 6 observed files x 8,640 runs = 51,840 x $0.0004 per 1,000 | $0.02 |
| S3 storage | one day of packs and observed files, under 0.3 GB x $0.023 | $0.01 |
| Function runs | 8,640 of 1,000,000 free | $0 |
| Function time | 8,640 runs x 10 s x 1.5 GB = 129,600 GB-seconds of 400,000 free | $0 ($1.73 if the free allowance were already used) |
| Scheduler | 8,640 of 14,000,000 free | $0 |
| Key storage, alarms, email, certificate | within free allowances | $0 |
| **Fixed total** | | **$0.16** |

**Costs that grow with users.** One line depends on how well CloudFront caches, which only real traffic will show, so the totals give both ends.

| | 1,000 users | 10,000 users | 100,000 users |
|---|---|---|---|
| Requests a month (x 3,150) | 3.15M | 31.5M | 315M |
| CloudFront requests: first 10M free, then $1.20 per million | $0 | 21.5M x $1.20 = $25.80 | 305M x $1.20 = $366 |
| CloudFront data: about 6.3 MB a user, first 1 TB free | $0 | $0 | $0 |
| S3 reads behind CloudFront if it caches nothing: $0.40 per million requests | $1.26 | $12.60 | $126 |
| **Total with fixed costs: if CloudFront caches well, to if it caches nothing** | **$0.16 to $1.42** | **$26 to $39** | **$366 to $492** |

- **Why a thousand users cost what they cost.** For 1,000 users the server costs under $1.50 a month: they make about 3 million requests, inside CloudFront's free 10 million. The free requests run out at about 3,170 users (10M / 3,150). Above that, each further 1,000 users adds $3.78 (3.15M x $1.20), plus at most $1.26 in S3 reads.
- **This is more per user than the rejected design,** which made one request per refresh and came to $1.80 per 1,000 users above the free allowance. The second request exists because the watch must read `latest` to find the newest run and its square's place in the pack. A file per square would remove that lookup but costs $22.81 a month in writes. A second, uncompressed file just for the rain line, as in the rejected design, would also remove it, at the price of two formats to build and keep in step.
- **S3 reads when caching works:** each CloudFront cache that serves us reads `latest` once a minute and each pack once or twice: about 52,000 to 60,000 reads a month, $0.02. We don't know how many caches serve Dutch users; with 10 it is $0.24 a month, with 50 it is $1.20, at any number of users.
- **Data** is an illustration from the one rainy case: 1,500 refreshes x (1 KB list + 2 KB square) + 30 radar sessions x 60 KB = 6.3 MB a user. The free 1 TB then covers about 158,000 users; beyond it data costs $0.085 per GB.

**Nothing caps this bill.** CloudFront pay-as-you-go has no limit, and the address is public: someone who requested `latest` in a loop would cost $1.20 per million requests. Josh's existing sites on CloudFront have the same exposure. The design adds an AWS budget alert (free) that emails Josh at $5 in a month; it warns, it does not stop the spending. Cloudflare's free plan does not charge for requests it serves from its cache, so a loop on a cached file would cost nothing there. Requests that miss its cache are still metered as R2 reads, so its bill is not capped either. This is still the strongest argument for Cloudflare.

### Apple's WeatherKit, for users everywhere else

Outside KNMI's area the watch calls WeatherKit directly and never touches our server. [Apple includes 500,000 calls a month](https://developer.apple.com/weatherkit/) with the developer membership, shared by all of Josh's apps. At 50 refreshes a day a user makes 1,500 calls a month.

| Users outside KNMI's area | Calls a month | Apple's price a month |
|---|---|---|
| up to 333 | 500,000 | $0 |
| up to 666 | 1 million | $49.99 |
| up to 1,333 | 2 million | $99.99 |
| up to 3,333 | 5 million | $249.99 |
| up to 6,666 | 10 million | $499.99 |

- **So 1,000 users abroad would cost more than 10,000 Dutch users on AWS.**
- **Apple never bills by itself.** When the free calls are used up it refuses further calls until Josh subscribes, so the app abroad would stop updating until the month ends.
- **What the app can do:** where WeatherKit only has hourly data, fetch at most once an hour (720 calls a user, so about 690 users fit in the free allowance), and show an honest "no forecast" state when Apple refuses.

## The alternatives

| Option | Cost a month | Verdict |
|---|---|---|
| **AWS: scheduled function + S3 + CloudFront (chosen)** | $0.16 to about $4 up to about 3,000 users | Nothing to patch or restart. Same region as KNMI's files. Josh's OpenTofu already has this pattern for jjpcodes.com. No cap on the bill. |
| **Cloudflare (R2 storage + CDN)** | Requests served from its cache are free. R2 reads on a cache miss: 10M a month free, then $0.36 per million ([R2 prices](https://developers.cloudflare.com/r2/pricing/)) | The cheapest at scale: no fee for cached requests. But its free plan only takes a whole domain ([one hostname alone needs the Business plan](https://developers.cloudflare.com/dns/zone-setups/partial-setup/)). It also means a new account and a second provider, and the job would still run on AWS, because Cloudflare's Workers have 128 MB of memory and the job needs about 0.5 GB. It saves nothing below about 3,000 users unless someone abuses the address. |
| **A small always-on machine ([Hetzner](https://www.hetzner.com/cloud/))** | from EUR 5.49 + VAT, about EUR 6.64 | It could use KNMI's push service and publish about 3 minutes sooner, and answer one plain request per square from memory. But it is a machine to patch and a single point of failure, and it costs EUR 6.64 where AWS costs about $0.16. Second choice. |
| **Josh's home server runs the job** | $0 | Its boot log shows two gaps in the last 36 days, of 72 and 82 minutes. The app shows "No data" once its forecast is an hour old, so a job running only there would have stopped feeding watches for long enough to show it. The log may not show every outage. It saves nothing over the function, which is also $0. |
| **PROPOSAL.md (the rejected design)** | similar | A 13.4 MB uncompressed file with 535,500 different byte ranges, a second format for the radar, "no data" drawn as dry, and a container registry for one script. |

**Is Lambda right?** For this part, yes. The server has two halves. Serving is done entirely by storage and a CDN: no code runs when a watch asks. The other half is a 2-second job on a timer. AWS's other ways to run one are a container task on a schedule (slower to start, no free allowance) or a machine that is always on (to pay for and patch). A scheduled function is the smallest. It needs only numpy and h5py (Astra checked the Linux ARM64 packages: 20.9 MB to download, 77.6 MB unpacked, inside Lambda's zip limit; not yet run on Lambda), so there is no container registry. The honest price of "no machine" is the 3 minutes of freshness above. If Josh prefers the machine, the same script runs there unchanged.

**When to look at Cloudflare again.** When CloudFront passes 8 million requests in a month (about 2,500 users at the high count), or the budget alert fires. It is a review, not an automatic switch.

## Josh's questions

**Why does Buienradar's radar image look finer than 1 km, and what can we show?** Its image has pixels of about 0.65 km. Pixels can be finer than the measurements under them: enlarging a picture smoothly draws soft edges between cells without adding information. The rainy image we compared shows the same shower shapes as KNMI's 1 km field for the same minute (side by side in `server/evidence/`), which is what smoothing looks like. That does not prove how Buienradar makes its picture. KNMI's data is 1 km, and we can draw it just as smoothly: about 30 cells across in the 30 km view, 120 in the 120 km view. "Only two hours" is how far ahead the forecast goes, not how fine it is.

**How does the watch get its square and the squares around it?** It computes its own cell, reads `latest`, and asks for its square's bytes; the radar page sends one request per row of squares.

**How are requests addressed without flooding the CDN?** By square, not by position: 528 shared addresses inside one cached file per run.

**Is Lambda right?** Only for the 2-second job. Nothing a watch talks to runs on it. It costs about 3 minutes of freshness against a machine.

**Why do a thousand users cost what they cost?** For 1,000 users the server costs under $1.50 a month. Above about 3,170 users each further 1,000 adds $3.78, because they make 3.15 million requests at $1.20 per million.

**How do we use the European radar network, and who hosts it?**
- **Who:** OPERA is the radar programme of EUMETNET, the group of European national weather services. It merges 167 radars from 24 countries into one picture. The files are published through EUMETNET's Open Radar Data service, which runs in the European Weather Cloud. They were stored with the Polish cloud company CloudFerro; that store has been stale since October, and EUMETNET's own documentation now points to a backup at ECMWF, the European weather centre. Licence CC BY 4.0.
- **Checked on 14 November:** anonymous listing and download both work. Over the whole day the 1 km reflectivity picture came every 5 minutes, 4.2 minutes after the measurement (worst 7.2), with a few runs missing; the 2 km rain-rate picture came every 15 minutes, 10 minutes late. The grid is 3,800 x 4,400 km.
- **How we would use it:** OPERA is radar only, with no forecast. A second job would move the rain forward itself and publish the same kind of pack on OPERA's grid. The watch would use KNMI where KNMI covers, OPERA elsewhere in Europe, and WeatherKit elsewhere. That would also take European users off Apple's bill. Measured on a real OPERA file on the Mac: finding the motion and moving the rain 24 steps took 8.7 seconds and 3.3 GB at 1 km (2.2 seconds at 2 km). So a larger function looks feasible; it was not run on Lambda.
- **Why not at launch:** OPERA's picture itself failed its first check. On the light showers of 13 and 14 November it showed 5% of the rain KNMI's radar saw over the Netherlands and Belgium, and its rain-rate product almost none (`research/opera-check.md`). One light-rain day is a weak test, but it is not good enough to forecast from until a check in heavier rain, against a second national radar, says otherwise. And nobody has scored a forecast made from it against what fell, as the season test did for KNMI. The 5-minute product is the strongest echo at any height, not rain at the ground, and the true rain-rate product is 15-minute and 10 minutes late. At 1 km it has about 16,000 squares, so its contents list needs a second look. It needs its own test first; WeatherKit covers Europe until then.

## What gets built (OpenTofu)

A new root, `~/code/opentofu-infra/services/buienwatch/`, on the pattern of `websites/jjpcodes.com`. Nothing is applied without a written plan and Josh's approval. The job's code stays in this repo under `server/`.

| Resource | Setting |
|---|---|
| S3 bucket | Private; CloudFront serves it and the job reads its saved radar files. Packs and radar files deleted after one day; `latest` stays. |
| CloudFront distribution | Pay-as-you-go (its free plan allows only 1 million requests), European and North American edges, compression for `latest` only, cache times taken from the files' own headers. |
| Address | `rain.jjpcodes.com`: a certificate and one record in the existing zone, unless Josh chooses a separate domain below. |
| Function | Python 3.13 on ARM, a zip of numpy and h5py, 60 s limit, one run at a time. 1.5 GB: about three times the 0.54 GB measured, and Lambda gives processor speed in proportion to memory. |
| Scheduler | Every 5 minutes. |
| Key | KNMI's key in Parameter Store, loaded from `nix-secrets`; never in OpenTofu state. |
| Freshness alarm | The function reports the age of `latest` on every run. Email to Josh when it passes 15 minutes, or when no report arrives. |
| Budget alert | Email to Josh when the month's AWS bill passes $5. |
| Role | The function may read and write the bucket, read the key and write logs. |

## Proven, and not

**Proven with real data** (scripts in `server/`, full record in `server/council-log.md`):
- the format and the watch's read path, on real KNMI files;
- the sizes and the build time on a Mac;
- CloudFront's range caching, as observed on 14 November;
- KNMI's and OPERA's delays;
- the projection formula;
- that numpy and h5py are enough.

**Not proven until it is built:**
- the build time on Lambda (10 s is an allowance);
- how many CloudFront caches serve Dutch users;
- real requests per user (CloudFront counts them for free);
- sizes on a day of heavy rain over the whole country (a larger pack means more data and a few more S3 reads);
- the battery cost of the second request in rain.

## For Josh to decide

1. **Go or no go** on this design: AWS at launch, one build per run, a new forecast available about 6 minutes after the radar measurement.
2. **The address.** The design uses `rain.jjpcodes.com`, which costs nothing. A later app update can change the address, but versions already installed keep using the old one, so it has to stay working for a long time. If the server ever moves to Cloudflare's free plan, that address would take the whole jjpcodes.com DNS zone with it, which also carries Josh's other sites and his NAS, tailnet and certificate records. The other option is a domain of its own for the app, about EUR 10 a year plus $0.50 a month if its DNS is at AWS; a move would then touch only that domain. Say so if you want that instead.
3. **WeatherKit when the free 500,000 calls run out:** let the app abroad stop updating until the month ends (recommended until real numbers exist), or pay Apple $49.99 a month or more.

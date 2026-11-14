Written by AI on 2026.11.14 by model gpt-6 astra

# RainWatch: the smallest useful infrastructure

**Use the existing VPS. Run the conversion every five minutes and let nginx serve its output directory over HTTPS.** Extra hosting cost: **€0/month** at the three traffic levels below, within its existing allowance. Add Route 53's small, usage-dependent DNS charge. No new machine, bucket, CDN, function or application request handler is needed for launch.

This accepts one machine as a point of failure. It is a reasonable launch trade for this free app, not a promise of uninterrupted forecasts. Keep the serving address independent of the machine so delivery can move later.

## What actually has to happen?

One machine must hold the KNMI key, fetch each new input once, convert it into watch-sized data, and publish complete output. Every watch then reads the same static files. The work happens **288 times/day, 8,640 times per 30-day month**, regardless of user count.

**Why a backend at all?** KNMI forbids embedding the personal key in an app and asks developers to cache behind their own backend. An anonymous shared key exists, but has shared limits and annual expiry; it does not solve large downloads or conversion. A timer and a static web server meet this need. [KNMI fair use](https://developer.dataplatform.knmi.nl/fair-use).

**Why not just mirror the files?** We can mirror the *converted* files. Raw inputs are scientific grids, not a watch response. Today's 18:25 UTC metadata reads returned 223,847 bytes plain forecast, 1,861,746 bytes blend and 39,551 bytes observation. Earlier rainy measurements reached 37.4 MB for the blend. Sending that on every refresh would spend battery on download and scientific decoding. A rainy converted pack was 274,450 bytes nationwide; the tested local square was 1,758 bytes, plus a 723-byte compressed index. The radar map needs roughly 10–61 KB. Those are measurements of one rainy case, not worst-case bounds.

I read the complete [existing design](DESIGN.md), [measurement record](council-log.md) and the pack probe. Its recorded 2.3 seconds and roughly 0.54 GB peak are Mac measurements; the source files were deleted, so I did not pretend to rerun them. No upstream binary was downloaded again for this review. The input bandwidth allowance, using the supplied 0.2–1.2 MB plain, 2–40 MB blend and 40–70 KB observation ranges, is **19–357 GB/month inbound**. Only one new observation is needed per run after warm-up.

**Does it need Lambda?** No. This is a normal batch command. At the Mac timing it occupies 0.8% of one core over time; even ten times slower occupies under 8%. Ordinary Cloudflare Workers cannot run this implementation unchanged: their [128 MB memory limit](https://developers.cloudflare.com/workers/platform/limits/) is below its measured footprint. Neither fact justifies rewriting the job for a cloud runtime.

## Can our VPS do it?

Yes. Read-only SSH and Hetzner API checks at about 18:27 UTC found:

| Fact | Live result |
|---|---|
| Machine | **CAX21, 4 ARM cores, 8 GB**, not the CAX11 in the brief and OpenTofu source |
| Memory | 6,764 MiB available; 952 MiB used; no swap |
| CPU | Load averages 0.13 / 0.05 / 0.01; about 99% idle in four one-second samples |
| Disk | 56 GiB free of 75 GiB |
| Uptime | 316 days; evidence of no reboot, not proof of uninterrupted service |
| Traffic | **20 TiB/month included**; 14.4 GB outgoing so far this month |
| Excess traffic | €1/TB excluding VAT; €1.21 including VAT, from its live server-type price data |

GoHome, VictoriaMetrics and Grafana were active. The running firewall accepts Tailscale and established connections and refuses other incoming traffic. Some services listen on wildcard addresses, so making *all* ports public would be wrong. Publish only a dedicated static virtual host; keep administration private.

The live type's current list price is €10.49/month excluding VAT, already paid for; this is not a new RainWatch cost or a verified invoice price. OpenTofu's CAX11 declaration is stale and must be reconciled against live state before applying infrastructure changes. Do not accidentally resize the machine. [Hetzner traffic billing](https://docs.hetzner.com/cloud/billing/faq/).

This proves spare capacity for the batch workload. It does **not** benchmark public TLS traffic at 100,000 users.

## What grows, and what does it cost?

For comparison: 50 refreshes/day, two requests per refresh, plus one radar session/day making five requests. That is **3,150 requests and about 6.3 MB per user/month**, using the rainy local-square measurement. Dry refreshes need only the index. The observed 44/day and upper 70/day produce 2,790–4,350 requests/user/month. All figures below are incremental, before tax, for Dutch users; existing machines, domain renewals and WeatherKit abroad are excluded.

| 30-day usage | 1,000 users | 10,000 users | 100,000 users |
|---|---:|---:|---:|
| Requests | 3.15 million | 31.5 million | 315 million |
| Mean requests/second | 1.2 | 12.2 | 121.5 |
| Payload sent | 6.3 GB | 63 GB | 630 GB |
| Payload at 70 refreshes/day | 8.1 GB | 81 GB | 810 GB |

HTTP/TLS overhead and bursts are additional. Even allowing three times the 810 GB figure leaves substantial room below 20 TiB. Full-pack downloads on every refresh would instead reach **41 TB/month at 100,000 users**: keep range requests. Rain affects output size; user count affects serving, not conversion or retained history.

| Option: what runs where | 1,000 | 10,000 | 100,000 | What must be maintained; what fails |
|---|---:|---:|---:|---|
| **Existing VPS: timer + files + nginx** | €0 + DNS | €0 + DNS | €0 + DNS* | One NixOS service/timer, static virtual host, certificate, retention and freshness check. VPS/network failure stops publication and downloads; watches retain their local copy until stale. Public traffic shares resources with GoHome. |
| VPS → **S3 + CloudFront** | $0.09–1.35 | $25.89–38.49 | $366.09–492.09 | Timer plus uploader/credentials; bucket, access policy, CDN, certificate and lifecycle in OpenTofu. VPS/upload failure leaves the old published run available; AWS delivery failure prevents downloads. |
| VPS → **R2 + Cloudflare cache** | $0 | $0–7.92 | $0–109.80 | Timer plus uploader; new Cloudflare account, domain setup, bucket, cache rules and lifecycle. Same producer failure as S3; Cloudflare failure prevents downloads. Read charges depend on cache misses. |
| VPS + **Cloudflare proxy**, no bucket | €0 + $0 | €0 + $0 | €0 + $0* | Timer/nginx plus new account, domain and cache rules. Saves origin traffic and adds edge protection; an origin failure leaves only whatever files the edges already cached. |
| **Scheduled Lambda → S3 + CloudFront** | $0.16–1.42 | $25.96–38.56 | $366.16–492.16 | Package/runtime, Scheduler, IAM, key store, bucket, CDN and monitoring. No VPS dependency. Scheduler/function/input failure leaves old files; AWS delivery failure blocks downloads. |
| **Home Linux server or Mac → S3 / R2** | Same delivery costs as above | Same | Same | Systemd or launchd and uploader, plus home power/internet dependency. Old files survive producer outage; freshness does not. Direct home serving has €0 extra hosting but adds public routing/TLS and takes delivery down too. |

\* Hosting allowance, not a capacity guarantee. Test bursts before this audience arrives. No extra home electricity is priced: the machines already run, and the job's marginal energy has not been measured.

**Price arithmetic, checked against vendor sources today:**

- [CloudFront](https://aws.amazon.com/cloudfront/pricing/pay-as-you-go/): first 10M requests and 1 TB/month free, then European HTTPS $1.20/M requests and $0.085/GB. [S3 Ireland price list](https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonS3/current/eu-west-1/index.json): writes $5/M, reads $0.40/M, storage $0.023/GB-month. VPS upload needs two writes/run: $0.0864/month, plus roughly $0.002 storage. Table ranges allow between negligible origin reads and one S3 read per viewer request. Free allowances are shared with other AWS usage; if exhausted, add up to $12 in request charges and $0.085 per GB shown. Flat-rate CloudFront tiers sized for these request counts are $15 / $200 / $1,000, so do not improve this comparison.
- [R2](https://developers.cloudflare.com/r2/pricing/): 10 GB storage, 1M writes and 10M reads free; then $0.36/M reads, rounded up to whole millions; no egress charge. The upper numbers assume every viewer request misses cache. With 50 active cache locations, one index fetch/minute and one whole pack/run/location would be about 2.6M origin reads/month: $0. That is an illustration, not a measured hit rate. Abuse can exceed it.
- [Lambda](https://aws.amazon.com/lambda/pricing/) and [Scheduler](https://aws.amazon.com/eventbridge/pricing/): 8,640 runs × assumed 10 seconds × 1.5 GB = 129,600 GB-seconds, inside 400,000 free. About $1.73 extra if that compute allowance is exhausted; actual runtime remains unmeasured. Its $0.16 baseline includes storing/reading observation history remotely.
- **DNS is not a request fee for every watch fetch.** [Route 53](https://aws.amazon.com/route53/pricing/) charges $0.40/M authoritative queries for a VPS address; resolvers cache the answer. Use a one-hour TTL. For illustration, 1,000 / 10,000 / 100,000 distinct resolvers querying both A and AAAA every hour cost $0.58 / $5.76 / $57.60 monthly. Actual resolver counts will be much lower than user counts in shared networks, but are unmeasured. Existing zone costs do not increase. CloudFront alias queries and Cloudflare DNS are free.

## Why not Cloudflare now?

It is a good delivery option, especially if public traffic needs isolating from GoHome. R2 keeps the VPS entirely private and makes cached requests free. We do not need Workers.

The extra work is account and DNS setup, not difficult compute. Free Cloudflare requires full-zone setup: [partial CNAME setup requires Business or Enterprise](https://developers.cloudflare.com/dns/zone-setups/partial-setup/). An [R2 custom domain](https://developers.cloudflare.com/r2/buckets/public-buckets/) must belong to its account; `r2.dev` is not a production endpoint. Using the existing domain means moving its authoritative DNS, preserving all other records; a separate domain means a purchase. Neither is necessary to ship static files from the VPS.

If chosen, explicitly make `latest` cacheable for 60 seconds and packs immutable. Cloudflare's free plan honours [origin cache headers](https://developers.cloudflare.com/cache/concepts/cache-control/); the dashboard's two-hour Edge TTL minimum is not a blanket freshness limit. Verify range responses and cache hits before switching. Prefer R2 over an origin proxy when the purpose is keeping GoHome private.

## How much history, and how fresh?

**No forecast archive is needed.** Keep seven observations for the past 30 minutes; keep one day of observations for recovery (about 20 MB). Retain one day of packs so a watch that just read an index can finish its range download: about **79 MB**, plus one index. Keep raw inputs only while processing/retrying; remember completed run names so a restart does not fetch them again. No historical backfill after downtime. Never delete the last published pack while `latest` still points to it.

Keeping every pack forever would add **2.37 GB/month, 28.8 GB/year** at the measured size. Keeping every raw blend could add **346 GB/month**. Neither helps the next-two-hours product.

Start once per five-minute run, about five minutes after issue, with an off-minute offset. Publish plain if the matching blend is late. The earlier 300-run sample found plain/observation available by then, but it is not a guarantee. Allow about a minute for processing/delivery: **roughly six minutes old when first available**, then watchOS decides when to refresh. Optional KNMI push notifications can remove polling delay later; they are not necessary for launch.

A home producer is technically sufficient but less reliable: I re-read the Linux boot journal and confirmed gaps of **82 and 72 minutes** in 36 days. Both exceed the one-hour stale limit. An S3/R2 copy cannot fix that. The Mac also depends on home power/internet; its availability was not independently measured.

The app currently implements `staleAt = fetched + one hour` in `Sources/RainGraph/Snapshot.swift`. **KNMI integration must use issue time instead.** Refetching an old static file must never make it young again. Show only its remaining valid forecast, never invent two hours from fetch time. A two-request refresh's watch battery cost is still unmeasured; changing hosting provider does not establish it.

## Exactly what to build after approval

1. Package the other agent's folder-writing job in NixOS on the VPS. A single systemd oneshot/timer every five minutes, persistent state directory, KNMI secret from agenix, one run at a time, timeout, and an initial 1 GiB memory limit. Benchmark a rainy run there; increase only if needed. Keep dependencies pinned and log failures.
2. Publish a complete immutable pack, then atomically replace `latest`. Retain the previous publication on failure. Add bounded cleanup with the retention above. No database, queue or container platform.
3. Add a dedicated nginx static virtual host with HTTPS, byte ranges, 60-second index caching, immutable pack caching and bounded logs. Reject unknown hostnames publicly; keep GoHome/Grafana and SSH reachable only through Tailscale. Declare host configuration in `nixos-config`, DNS/provider firewall changes in `opentofu-infra`; reconcile the stale server type first. Use an app hostname in the existing domain, not the tailnet address.
4. Check forecast issue age from another existing machine every five minutes; mark unhealthy after 15 minutes or failed delivery. Use existing monitoring, not a new platform. Configure a notification only through an explicitly approved destination. A monitor on the producer alone cannot report its own disappearance.
5. Before launch, fetch index and ranges over public HTTPS from the actual watch; check Swift decoding, freshness after a deliberately retained old run, interrupted publication and recovery. Measure watch energy and a realistic burst of TLS requests. At 100,000 users, budget a test around 1,200 requests/second (10× the mean), not a claim based on idle CPU.

This review changed no machines, accounts or cloud resources and spent nothing. `DESIGN.md` remains a separate candidate. The proposal is one timer, one output folder and an existing web server; add independent storage/CDN when its isolation or availability benefit is actually wanted.

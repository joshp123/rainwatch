<!-- Written by AI on 2026.11.14 by model claude opus 5.5, at Josh's request: "find out how to make it as cheap as possible but no cheaper", then "design it properly ... explain what you're building". A design; nothing is built or deployed. -->

# BuienWatch's server

## What it is for

The Netherlands forecast has to come from KNMI. KNMI forbids putting its API key in an app, and a watch can't download and decode KNMI's files (1 to 40 MB every 5 minutes). So a small job turns each KNMI run into something a watch can read in one tiny request.

## What it does, every 5 minutes

1. **Fetch.** EventBridge Scheduler starts a Lambda function 5 minutes apart, aligned to KNMI's runs. The function asks KNMI's API for three files, using Josh's key:
   - the plain forecast, 0.2 to 1.2 MB;
   - the blended forecast, 2 to 40 MB;
   - the latest observed radar.
   
   KNMI keeps its files on AWS in Ireland (eu-west-1), the region Josh's AWS account already uses, so the downloads take about a second.
2. **Build the forecast.** It takes the plain forecast for 0 to 30 minutes and the blend (the median of its 20 versions) for 35 to 120 minutes. That order scored best over 66 rainy days (`research/verification/season.md`). If the blend is missing or late, it uses the plain forecast throughout.
3. **Write two files** to an S3 bucket:
   - **The forecast file, 13.4 MB.** It holds 25 values (now to +120 minutes) for each of the 535,500 one-km cells of KNMI's grid, one byte each on Buienradar's own intensity scale. A cell's 25 bytes sit at a fixed position worked out from its row and column. So a watch asks for exactly those 25 bytes with one HTTP range request, and the file never needs an index.
   - **The radar file, 7 KB dry to about 100 KB in rain.** It holds the radar page's frames, compressed. The app downloads it only when someone opens the radar page.
4. **Serve.** CloudFront serves both files from S3. The forecast file is cached for 2 minutes, so a watch never sees data more than 2 minutes behind the latest run, plus KNMI's own 2 to 3 minute delay.

**Measured** on a rainy run (13 November, the largest blend file), with `server/build_run.py`: 2.0 seconds and 0.64 GB of memory on this Mac. Lambda's processors are slower, so the design allows 10 seconds at 2 GB.

## How often a watch asks

- **Complication refresh:** one request for 25 bytes, plus about 0.5 KB of HTTP headers, each time watchOS refreshes the complication. Josh's watch log shows 44 refreshes in the last 24 hours, usually 30 minutes apart. That count includes my test runs, so it is a high estimate.
- **Opening the app:** one more request for the 25 bytes, and the radar file if the radar page is opened.
- **Planning figure:** about 1,500 requests and 4 MB per user per month.
- **Outside KNMI's area:** watches call Apple's WeatherKit directly and never touch this server.

## What gets built (OpenTofu)

It goes in a new root, `~/code/opentofu-infra/services/buienwatch/`, following the same pattern as `websites/jjpcodes.com` (S3 behind CloudFront, region eu-west-1). Per that repo's rules, nothing is applied without a written plan and Josh's approval.

| Resource | Setting |
|---|---|
| S3 bucket | Private; only CloudFront can read it, through an Origin Access Control. Keeps just the latest files. |
| CloudFront distribution | Pay-as-you-go pricing, Europe and North America edges only. A cache policy with a 2-minute lifetime. Range requests on. |
| Lambda function | Python 3.13 on ARM, 2 GB, 60-second timeout. Shipped as a container image in ECR, because numpy, h5py, netCDF4 and pyproj are too big for a zip. |
| EventBridge Scheduler | Runs every 5 minutes, starting 3 minutes after each KNMI run. |
| SSM Parameter Store | Holds KNMI's key (a free standard SecureString), loaded from `nix-secrets`; the key is never in OpenTofu state. |
| IAM role | The function may write to the bucket, read the key and write logs; nothing else. |
| CloudWatch alarm and SNS email | Emails Josh if runs fail for 15 minutes. |
| Address | The free `*.cloudfront.net` name. `rain.jjpcodes.com` costs nothing extra, since the Route 53 zone already exists. |

The job's code lives in this repo under `server/`; the infrastructure root's `AGENTS.md` points back here.

## What it costs

Prices are AWS list prices, read on 14 November 2026: [CloudFront](https://aws.amazon.com/cloudfront/pricing/pay-as-you-go/), [Lambda](https://aws.amazon.com/lambda/pricing/), [S3](https://aws.amazon.com/s3/pricing/), [EventBridge](https://aws.amazon.com/eventbridge/pricing/). Every month has 8,640 runs. The free allowances are AWS's "always free" ones, which apply to every account indefinitely.

| Item | Usage a month | Free allowance | Cost |
|---|---|---|---|
| Lambda compute | 8,640 runs × 10 s × 2 GB = 172,800 GB-seconds | 400,000 GB-seconds | $0 |
| Lambda requests | 8,640 | 1 million | $0 |
| EventBridge Scheduler | 8,640 | 14 million | $0 |
| S3 writes | 2 files × 8,640 = 17,280, at $0.005 per 1,000 | none | $0.09 |
| S3 storage | under 0.1 GB | none | under $0.01 |
| ECR image storage | about 0.4 GB, at $0.10 per GB | none | $0.04 |
| CloudFront fetches from S3 | Free transfer, but each fetch is an S3 read at $0.0004 per 1,000. CloudFront fetches the forecast in 1 MB slices: at most one read per slice, per edge location, per 2 minutes, and only while watches are asking. | none | $0.01 to $1.20 |
| CloudFront requests | 1,500 per user | 10 million | $0 up to about 6,600 users |
| CloudFront data out | 4 MB per user | 1 TB | $0 up to about 250,000 users |
| Key, alarm, logs | | free allowances | $0 |

**Total:**
- **Under 1,000 users:** about $0.15 to $0.40 a month.
- **Up to about 6,600 users:** under $1.50 a month.
- **Above that:** HTTPS requests cost $0.012 per 10,000 in Europe, so each further 1,000 daily users adds about $1.80 a month. For example, 50,000 users would cost about $80 a month. At that size, putting Cloudflare's free CDN in front makes cached requests free; until then it isn't worth a second provider.

My earlier "$0.15 a month" left out the S3 reads behind CloudFront and the container image. These are the full numbers.

## What any cheaper option would break

| Cheaper option | What breaks |
|---|---|
| Running the job on the home server | Every watch goes stale whenever the home internet or power is down. |
| Running every 10 or 15 minutes | KNMI publishes every 5 minutes, so the face would fall up to 10 minutes further behind. |
| Caching the file for longer than 2 minutes | Watches would get the previous run more often. |
| 2 km cells | It saves nothing, because uploads within AWS are free, and it loses the street-level precision. |
| KNMI's shared key | Everyone shares its 50 requests a minute; it ran out on 14 November. |
| Serving straight from S3 without CloudFront | S3 charges for every read and for data out, while CloudFront's first 10 million requests are free. |
| Dropping the blend | It saves nothing, because it fits in the free compute, and the forecast gets worse in the second hour. |
| ChatGPT Sites | It doesn't support background jobs, so it can't run the 5-minute job. |

## Later: Europe

EUMETNET's OPERA composite is open under CC BY 4.0. Measured on 14 November:
- 167 radars from 24 countries, the UK and Ireland included; Austria, Italy and Greece don't share.
- Reflectivity at 1 km every 5 minutes, about 4 minutes after measurement.
- Rain rate at 2 km every 15 minutes.
- About 2 MB a file. While OPERA's cloud provider has trouble, the files come from a backup host.

Running the same forecast method on it would give all of Europe a 2-hour forecast. The grid is 3,800 × 4,400 km, about 31 times KNMI's, so the computing has to be measured before choosing between running it on every run, at 2 km, or only over regions with users.

<!-- Written by AI on 2026.11.14 by model claude opus 5.5, at Josh's request: "find out how to make it as cheap as possible but no cheaper". A proposal; nothing is built or deployed. -->

# BuienWatch's server: as cheap as possible, no cheaper

**Cost: about US$0.15 a month at launch, and free of fixed costs.** The floor is Josh's freshness goal: "i can always trust the data because its always current enough without pwning battery".

## What it does

Every 5 minutes, when KNMI publishes a new nowcast, a job:

1. Fetches KNMI's plain forecast (0.2 to 1.2 MB), its blended forecast (2 to 40 MB) and its latest observed radar, using Josh's own key. It uses the plain forecast for the first 30 minutes and the blend after that (where at least half of its 20 versions show rain), because that order scored best over 66 rainy days (`research/verification/season.md`). If the blend is late or KNMI ends the pilot, it uses the plain forecast throughout.
2. Writes two files to storage:
   - **The forecast file.** It holds every 1 km cell's 25 five-minute values, one byte each on Buienradar's own scale. A cell's values sit at a fixed place in the file, so a watch downloads only its own 25 bytes with one HTTP range request.
   - **The radar file.** It holds every frame of the radar page, compressed (7 KB when dry). The app downloads it only when the radar page opens.

Measured on today's 15:55 file, the run takes 0.2 seconds on this Mac.

## Where it runs, and what it costs

All of it runs on Josh's AWS account, where his website already runs and his infrastructure code (`~/code/opentofu-infra`) lives.

| Part | Use a month | Cost |
|---|---|---|
| EventBridge Scheduler, every 5 minutes | 8,640 runs | free (14 million included) |
| Lambda, Python with h5py and numpy | 8,640 runs of about 1 s | free (400,000 GB-seconds included) |
| S3, two to three files per run, overwritten | about 26,000 writes | about $0.13 |
| CloudFront in front of S3 | watches' requests | free up to 10 million requests and 1 TB |
| The watches' download | 25 bytes per refresh | free, inside CloudFront's allowance |

**When it would cost more:** past about 6,600 daily users. A watch on a face that's in use refreshes about 50 times a day (`research/freshness.md`), so it makes about 1,500 requests a month. Beyond 10 million requests a month, CloudFront charges about $1.20 per million, roughly $1.80 a month for every further 1,000 daily users.

The earlier $0 to $5 estimate assumed hundreds of tile files per run, and each write costs money. Two files per run removes almost all of that.

## Why not cheaper

| Cheaper option | What it would break |
|---|---|
| Run it on the home server | Every watch goes stale whenever the home internet or power is down. |
| Run it every 10 or 15 minutes | KNMI publishes every 5 minutes, so the face would be up to 10 minutes further behind. |
| Use 2 km cells | It saves nothing, because uploads within AWS are free, and it loses the street-level precision that is the point ("precision not national"). |
| Keep using KNMI's shared key | Everyone shares it; it hit its limit today, which blanks every watch. Josh's own key allows 1,000 requests an hour, and this needs about 50. |
| Serve straight from S3 without CloudFront | S3 charges for every download (about $2.40 per 6 million), while CloudFront's first 10 million are free. |
| ChatGPT Sites | It doesn't support background jobs, so it can't run the 5-minute job. |

## Outside KNMI's area

Watches call WeatherKit directly, which is free up to 500,000 calls a month. Apple doesn't bill for more calls on its own: the account holder has to subscribe to a bigger plan, and without one Apple answers further calls with "OVER_QUOTA" ([Apple](https://developer.apple.com/weatherkit/get-started)). To stay inside the free allowance:
- The watch keeps each answer until its expiry date.
- It asks only for the data it shows.
- It asks for the hourly forecast at most once an hour, since that data changes hourly.

## To build it, after Josh says go

- The Lambda, written in Python and reusing `server/knmi_probe.py`.
- The OpenTofu stack in `~/code/opentofu-infra`.
- A free CloudWatch alarm that emails Josh if a run fails.
- The app changed to read its 25 bytes, and the radar file, from the server.

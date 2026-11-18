<!-- Written by AI on 2026.11.17 by model claude opus 5.5. The server as built; earlier drafts and the measurements behind them are in git history. -->
<!-- Updated by AI on 2026.11.18 by model gpt-6.2-sol for the compact KNMI blend. -->

# RainWatch's server

## What it does

KNMI forbids its API key in an app, and its files (0.2 to 40 MB of HDF5 every 5 minutes) are no use to a watch. So one job turns each KNMI run into two static files, and a CDN serves them.

1. **Every 5 minutes** (20 seconds past), `job.py` builds the run measured five minutes earlier. It asks KNMI by name for the plain forecast and newest observed radar. The six earlier radar files are kept from previous runs. A run already built is never fetched again (KNMI's [fair use](https://developer.dataplatform.knmi.nl/fair-use)).
2. **It writes two files:**
   - `runs/<run>.bin`, the pack: KNMI's 765 x 700 km grid cut into 528 squares of 32 km, each holding every 1 km cell for 31 frames (-30 to +120 minutes), one byte a value, compressed with raw DEFLATE. 5 KB when dry, about 280 KB in widespread rain.
   - `latest`, about 1 KB of JSON: the run time, whether the blend is in it, and the length of each square in the pack (0 dry, -1 no radar coverage).
3. **It uploads** the pack, then `latest`, to S3 with an upload-only key. CloudFront serves them at `https://rain.jjpcodes.com`: `latest` cached for 60 seconds, packs for a day.

### Forecast

The newest plain radar forecast supplies +0 through +60 minutes. For +65 through +120, use KNMI's radar–weather-model blend from the previous issue, aligned to the same valid time (its +70 through +125 minutes). Where the probability or radar grid has gaps, use the plain value. The blend marks rain at a probability of at least 50% at 0.1 mm/h. In the [season verification](../research/verification/probabilities.md#using-the-previous-issue), the previous issue improved the second-hour Critical Success Index from 0.435 to 0.465. On the current grid it lowered the +35 through +60 score, so the full first hour uses the newest radar.

For a wet cell, estimate its rate where the probability crosses 50%, interpolating in log rain rate between KNMI's adjacent thresholds. The six thresholds run from 0.1 to 30 mm/h, so the estimated rate tops out at 30. Interpolation preserves the wet/dry vote and avoids making the line sit at the six thresholds. The app draws the join at one hour with its existing rain curve.

At issue +8:20, a separate timer prepares that issue's blend for the next publish. It looks up `KNMI_PYSTEPS_BLEND_PROB_<run>.nc` in `seamless_precipitation_ensemble_forecast_probabilities` version 1.0. It records the attempt before contacting KNMI, accepts at most 40 MB, and runs with a 20-second limit and a 512 MiB memory budget. It saves the validated overlay atomically. Two minutes later, the publisher reads the expected issue's completed overlay from disk or writes a plain pack. A missing, slow, invalid or oversized file leaves the cache empty for that issue. Each issue gets one attempt and each forecast gets one publish. `latest.blend` says whether the pack used the overlay, and `latest.blend_run` gives its issue time when used.

## What the watch does

It works out its 1 km cell from latitude and longitude (a closed formula, no library), reads `latest`, and stops if its square is dry. Otherwise it makes one range request for its square, about 2 KB. The radar page asks for one range per row of squares under the map. Only the square leaves the watch, never the position. `watch_client.py` does exactly this in Python; `check_against_knmi.py` checks its values against KNMI's own files.

Age comes from the run time in `latest`, never from when the watch fetched. Missing radar data is never shown as dry. Both forecasts use the same pack format, frame times and refresh schedule.

## Where it runs

On mini-server-1 (`~/code/nix/nixos-config/hosts/nixos/mini-server-1/rainwatch.nix`), the publisher and blend preparation share their own unprivileged service user and state directory, with internet access through the same sandbox. Only the publisher receives the upload credential. The AWS side is `~/code/opentofu-infra/services/rainwatch`.

When mini-server-1 or KNMI is down, the last files stay on CloudFront and watches show their age; after an hour the app says "No Recent Forecast". A new run reaches watches about 6 minutes after the radar measured it; watchOS refreshes the face every 15 to 30 minutes.

## What it costs

S3 uploads: 2 files x 8,640 runs = 17,280 a month at $0.005 per 1,000 = $0.09. CloudFront is free up to 10 million requests a month; a user makes about 3,150 (50 refreshes a day, two requests in rain), so about 3,000 users are free. Above that each 1,000 users adds $3.78 at $1.20 per million requests. A budget alert emails Josh if CloudFront passes $5 in a month.

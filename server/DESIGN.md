<!-- Written by AI on 2026.11.17 by model claude opus 5.5. The server as built; earlier drafts and the measurements behind them are in git history. -->
<!-- Updated by AI on 2026.11.18 by model gpt-6.2-sol for the compact KNMI blend. -->

# RainWatch's server

## What it does

KNMI forbids its API key in an app, and its files (0.2 to 40 MB of HDF5 every 5 minutes) are no use to a watch. So one job turns each KNMI run into two static files, and a CDN serves them.

1. **Every 5 minutes** (20 seconds past), `job.py` builds the run measured five minutes earlier. It asks KNMI by name for the plain forecast and newest observed radar. The six earlier radar files are kept from previous runs. In parallel it tries that run's compact probability forecast once. A run already built is never fetched again (KNMI's [fair use](https://developer.dataplatform.knmi.nl/fair-use)).
2. **It writes two files:**
   - `runs/<run>.bin`, the pack: KNMI's 765 x 700 km grid cut into 528 squares of 32 km, each holding every 1 km cell for 31 frames (-30 to +120 minutes), one byte a value, compressed with raw DEFLATE. 5 KB when dry, about 280 KB in widespread rain.
   - `latest`, about 1 KB of JSON: the run time, whether the blend is in it, and the length of each square in the pack (0 dry, -1 no radar coverage).
3. **It uploads** the pack, then `latest`, to S3 with an upload-only key. CloudFront serves them at `https://rain.jjpcodes.com`: `latest` cached for 60 seconds, packs for a day.

### Forecast

The plain radar forecast supplies +0 through +30 minutes. For +35 through +120, use KNMI's radar–weather-model blend where the probability file covers the cell and the plain forecast has radar coverage. The blend marks rain at a probability of at least 50% at 0.1 mm/h. This reproduces the vote from the 20 members in the [season verification](../research/verification/probabilities.md). The second-hour Critical Success Index was 0.475 with the blend and 0.435 with plain radar.

For a wet cell, estimate its rate where the probability crosses 50%, interpolating in log rain rate between KNMI's adjacent thresholds. The six thresholds run from 0.1 to 30 mm/h, so the estimated rate tops out at 30. Interpolation preserves the wet/dry vote and avoids making the line sit at the six thresholds. In the [archived rain-line comparison](../research/verification/blend-lines.png), the app's curve joins the two forecasts at +30 minutes without a separate smoothing rule. The two forecasts can disagree about the intensity or presence of rain near the join.

A worker looks up `KNMI_PYSTEPS_BLEND_PROB_<run>.nc` in `seamless_precipitation_ensemble_forecast_probabilities` version 1.0. It records the attempt before contacting KNMI, accepts at most 40 MB, and has a five-second work limit. On Linux it has a separate 512 MiB address-space limit within the service's 1 GiB memory budget. The publisher checks once, when its plain grid is ready to pack. It uses a completed, validated overlay or publishes plain immediately. A missing, slow, invalid or oversized file does not trigger a retry or a later rebuild. The journal reports the result of the attempt and `latest.blend` says whether the published pack used the overlay.

## What the watch does

It works out its 1 km cell from latitude and longitude (a closed formula, no library), reads `latest`, and stops if its square is dry. Otherwise it makes one range request for its square, about 2 KB. The radar page asks for one range per row of squares under the map. Only the square leaves the watch, never the position. `watch_client.py` does exactly this in Python; `check_against_knmi.py` checks its values against KNMI's own files.

Age comes from the run time in `latest`, never from when the watch fetched. Missing radar data is never shown as dry. Both forecasts use the same pack format, frame times and refresh schedule.

## Where it runs

On mini-server-1 (`~/code/nix/nixos-config/hosts/nixos/mini-server-1/rainwatch.nix`), as its own unprivileged service user, sandboxed: it can read only its KNMI key and upload key, write only its own folder, and reach only the internet, not the home network. The AWS side is `~/code/opentofu-infra/services/rainwatch`.

When mini-server-1 or KNMI is down, the last files stay on CloudFront and watches show their age; after an hour the app says "No Recent Forecast". A new run reaches watches about 6 minutes after the radar measured it; watchOS refreshes the face every 15 to 30 minutes.

## What it costs

S3 uploads: 2 files x 8,640 runs = 17,280 a month at $0.005 per 1,000 = $0.09. CloudFront is free up to 10 million requests a month; a user makes about 3,150 (50 refreshes a day, two requests in rain), so about 3,000 users are free. Above that each 1,000 users adds $3.78 at $1.20 per million requests. A budget alert emails Josh if CloudFront passes $5 in a month.

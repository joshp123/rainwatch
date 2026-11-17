<!-- Written by AI on 2026.11.17 by model claude opus 5.5. The server as built; earlier drafts and the measurements behind them are in git history. -->

# RainWatch's server

## What it does

KNMI forbids its API key in an app, and its files (0.2 to 40 MB of HDF5 every 5 minutes) are no use to a watch. So one job turns each KNMI run into two static files, and a CDN serves them.

1. **Every 5 minutes** (20 seconds past), `job.py` builds the run measured 5 to 10 minutes earlier. It asks KNMI for that run's files by name: the plain forecast and the newest observed radar. The six earlier radar files are kept from previous runs, so a normal run makes 2 KNMI calls. A run already built is never fetched again (KNMI's [fair use](https://developer.dataplatform.knmi.nl/fair-use)).
2. **It writes two files:**
   - `runs/<run>.bin`, the pack: KNMI's 765 x 700 km grid cut into 528 squares of 32 km, each holding every 1 km cell for 31 frames (-30 to +120 minutes), one byte a value, compressed with raw DEFLATE. 5 KB when dry, about 280 KB in widespread rain.
   - `latest`, about 1 KB of JSON: the run time, whether the blend is in it, and the length of each square in the pack (0 dry, -1 no radar coverage).
3. **It uploads** the pack, then `latest`, to S3 with an upload-only key. CloudFront serves them at `https://rain.jjpcodes.com`: `latest` cached for 60 seconds, packs for a day.

Forecast: KNMI's plain forecast for the whole two hours. KNMI's blend with its weather model scored a little better after 30 minutes over 66 rainy days (`research/verification/season.md`: +0.03 on a 0-to-1 score), but in widespread rain its file is 210 to 265 MB a run and arrives about 6.5 minutes after it, so it is off. Its 17 MB probabilities file carries the same wet-or-dry vote and is the way back in, once scored.

## What the watch does

It works out its 1 km cell from latitude and longitude (a closed formula, no library), reads `latest`, and stops if its square is dry. Otherwise it makes one range request for its square, about 2 KB. The radar page asks for one range per row of squares under the map. Only the square leaves the watch, never the position. `watch_client.py` does exactly this in Python; `check_against_knmi.py` checks its values against KNMI's own files.

Age comes from the run time in `latest`, never from when the watch fetched. Missing radar data is never shown as dry.

## Where it runs

On mini-server-1 (`~/code/nix/nixos-config/hosts/nixos/mini-server-1/rainwatch.nix`), as its own unprivileged service user, sandboxed: it can read only its KNMI key and upload key, write only its own folder, and reach only the internet, not the home network. The AWS side is `~/code/opentofu-infra/services/rainwatch`.

When mini-server-1 or KNMI is down, the last files stay on CloudFront and watches show their age; after an hour the app says "No Recent Forecast". A new run reaches watches about 6 minutes after the radar measured it; watchOS refreshes the face every 15 to 30 minutes.

## What it costs

S3 uploads: 2 files x 8,640 runs = 17,280 a month at $0.005 per 1,000 = $0.09. CloudFront is free up to 10 million requests a month; a user makes about 3,150 (50 refreshes a day, two requests in rain), so about 3,000 users are free. Above that each 1,000 users adds $3.78 at $1.20 per million requests. A budget alert emails Josh if CloudFront passes $5 in a month.

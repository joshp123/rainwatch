<!-- Written by AI on 2026.11.18 by model gpt-6.2-sol. -->

# Can KNMI's probabilities replace the blend?

**Leave the blend off on the current schedule.** The probabilities file reproduces the blend's rain vote and takes about a second to fetch and decode on the server when it is ready. In a week of runs, KNMI published it after the server's 5 minute 20 second start time 11% of the time. Waiting for it on those runs would start adding delay at the source, before any CDN or watch refresh delay.

## What the watch would gain

Second hour (65–120 minutes after the radar measurement), on the 66 rainy days in the season test:

| Forecast | Rain shown per 20 wet place-times | Dry per 20 place-times shown as rain | CSI |
|---|---:|---:|---:|
| Plain radar forecast | 11.7 | 7.4 | 0.435 |
| Full blend, at least 10 of 20 members wet | 12.8 | 7.0 | 0.475 |
| Probabilities, at least 50% at 0.1 mm/h | 12.8 | 7.0 | 0.475 |

Those are five-minute samples at a place. The two columns have different denominators. The blend caught 338 more wet samples and called 34 fewer dry samples wet across the 66 days (6,591 observed wet samples in the second hour). CSI is hits divided by hits plus misses plus false alarms. The second-hour improvement is +0.040 (95% paired day bootstrap interval +0.024 to +0.055).

| Lead after measurement | Plain CSI | Full blend CSI | Probabilities CSI |
|---|---:|---:|---:|
| 5–30 min | 0.755 | 0.762 | 0.762 |
| 35–60 min | 0.554 | 0.577 | 0.577 |
| 65–120 min | 0.435 | 0.475 | 0.475 |
| 5–120 min | 0.533 | 0.562 | 0.562 |

Keeping plain through 30 minutes and using either blend vote after that raises the whole-window CSI from 0.533 to 0.560 (+0.027, interval +0.017 to +0.038). On the 30 days with the current grid (10 from the season plus 20 extra), plain leads in the first half hour, 0.766 versus 0.734. In the second hour the blend catches 12.7 instead of 11.6 out of 20 wet samples and stays dry on 5.7 instead of 6.4 out of 20 rain predictions. Its CSI is 0.507 versus 0.455 (+0.052, interval +0.012 to +0.093). The plain-first combination scores 0.588 versus 0.557 over two hours on that sample.

KNMI had the probabilities for all 86 original issue times. The comparison joins the new file to the saved forecasts and radar truth by issue, location and lead, using the issue timestamp in the case file even if the radar archive day has a different date. It uses the same 48 places, nearest-cell selection, 24 five-minute leads, common validity mask, 0.1 mm/h wet threshold and 4,000 whole-day bootstrap draws as [the season test](season.md). It covers 99,072 distinct comparable place-times. These rainy windows measure wet/dry forecast skill. The counts do not describe how often rain occurs over a whole day, or the watch's actual refresh schedule.

## What KNMI publishes

`seamless_precipitation_ensemble_forecast_probabilities` version 1.0, file `KNMI_PYSTEPS_BLEND_PROB_YYYYMMDDHHMM.nc`, is a NetCDF file for one run. `exceedance_probability` stores integer percentages at 0.1, 0.3, 1, 3, 10 and 30 mm/h for every five-minute lead from +5 to +360, 72 leads. Older files have the 765 × 700, 1 km polar-stereographic radar grid. The current 780 × 780 grid uses regular latitude and longitude spacing (0.009° × 0.0145°, about 1 km over the Netherlands). The files and the full-member dataset are both outputs of KNMI's pySTEPS blend of live radar and HARMONIE-AROME. [KNMI probabilities catalogue](https://dataplatform.knmi.nl/dataset/seamless-precipitation-ensemble-forecast-probabilities-1-0), [KNMI member catalogue](https://dataplatform.knmi.nl/dataset/seamless-precipitation-ensemble-forecast-members-1-0).

At 0.1 mm/h the encoded probability equals five times the number of wet members in every one of the 99,072 comparisons, across both grids. Thus 50% includes ties and exactly recovers the old vote at the places and leads checked. The six thresholds do not recover the continuous median rain rate that the old server used for the height of the rain line.

## What a run would cost

For every five-minute run on 11–17 November 2026 UTC, I compared the issue time in the name with KNMI's file `created` timestamp. Each of the three catalogues contained a file for each of the 2,016 slots. The probability file's creation and last-modified timestamps agreed on every slot. This dates creation at KNMI and does not measure first successful retrieval from a client.

| Product | Median age at creation | 95th percentile | Latest | After 5:20 |
|---|---:|---:|---:|---:|
| Plain | 1:51 | 4:26 | 4:45 | 0 of 2,016 |
| Probabilities | 4:10 | 6:38 | 7:09 | 221 of 2,016 (11.0%) |
| Full blend | 4:10 | 6:38 | 7:09 | 221 of 2,016 (11.0%) |

The two blend products arrived within a second of each other in 2,013 of 2,016 runs. Among the 221 late probability files, creation was a median 76 seconds after 5:20 and up to 109 seconds after. Even by 5:30, 198 of the 2,016 were still due. On 17 November, 62 of 288 were late at 5:20. Keeping the current start and skipping unavailable probabilities would keep the plain forecast on those runs. The 89% ready at 5:20 is an estimate from catalogue timestamps before allowing any budget for the fetch, decode or upload.

I downloaded six distinct files on mini-server-1 (Intel N100) and timed a separate process using the server's NumPy and HDF5 environment. It reads the 0.1 mm/h field for +35 to +120, maps it to the 765 × 700 radar grid as the old server did, and builds the wet/dry mask. Widespread rain here means 63–65% of those grid cells and leads voted wet. Dry means 0%.

| Test files | Sizes | API lookup | File download | Decode and map | Combined |
|---|---:|---:|---:|---:|---:|
| Three dry runs, 14 Nov 17:55–18:05 UTC | 0.327 MB | 0.15–0.20 s | 0.14–0.19 s | 0.35–0.41 s | 0.65–0.78 s |
| Three widespread runs, 17 Nov 08:10, 08:25, 08:35 UTC | 27.96–28.11 MB | 0.16–0.17 s | 0.53–0.66 s | 0.35–0.36 s | 1.06–1.17 s |

Decoder peak RSS was 86.2–86.5 MiB, about 39 MiB above the process after imports. These are measurements of the additional data path in isolation. They exclude encoding the rest of a watch forecast, upload and watch refresh. The existing server takes about 7 seconds for the plain run. The full blend previously pushed a run to 223 seconds. In this week's catalogue the probability files ranged from 0.33 to 28.23 MB (median 10.78 MB). The largest was paired with a 426 MB member file. At the week's average, downloading every probabilities file would be about 94 GB per 30 days, against 897 GB for the full blend.

The six timings describe the tested connection, and the catalogue sample covers a week. KNMI still calls this a pilot. An end-to-end publish deadline with probabilities enabled and a method for recovering rain-line heights both remain untested. Keeping the plain publish deadline would require the blend to be optional whenever its result is late.

## Reproduce

Use Python with NumPy and h5py and a scratch directory outside the repo. The collector reads `KNMI_API_KEY` from the environment. Use existing downloaded files if present. The measurements used 106 distinct successful file transfers and about 230 HTTP requests including file lookups and catalogue pages, with no polling. The archive forecasts and radar truth were reused from the saved season cells.

```sh
python research/verification/probabilities_fetch.py "$scratch" season
python research/verification/probabilities_score.py "$scratch"

python research/verification/probabilities_fetch.py "$scratch" recent --start 2026-11-11 --days 7
python research/verification/probabilities_bench.py "$scratch/catalogue.json"

# The separately timed runs on mini-server-1.
python research/verification/probabilities_fetch.py "$scratch" recent --only \
  202611141755 202611141800 202611141805 202611170810 202611170825 202611170835
git show 788d167^:server/job.py > "$scratch/old_job.py"
for stamp in 202611141755 202611141800 202611141805 202611170810 202611170825 202611170835; do
  python research/verification/probabilities_bench.py \
    "$scratch/KNMI_PYSTEPS_BLEND_PROB_${stamp}.nc" "$scratch/old_job.py"
done
```

Forecast and observation source is KNMI. Timings, comparisons and decision are derived here. [KNMI Open Data API](https://developer.dataplatform.knmi.nl/open-data-api), [KNMI fair use](https://developer.dataplatform.knmi.nl/fair-use).

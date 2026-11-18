<!-- Written by AI on 2026.11.18 by model claude opus 5.5, for the launch film. -->

# The film's shower

`shower.json` is one real KNMI forecast for one 1 km cell, as the watch receives it: KNMI's plain forecast (`radar_forecast` 2.0) run of 17 November 2025, 05:25 UTC (06:25 in Arnhem), for the cell over Arnhem's city centre (row 436, column 423, at 51.9819 N, 5.9167 E). It is dry for 20 minutes, then a shower of 0.4, 3.6, 5.8 and 1.5 mm/h, then dry for an hour, with a trace of drizzle (0.4 mm/h) at 07:10 UTC. The first six values are KNMI's radar for the half hour before the run, as in the server's pack.

The app's own code (`RainForecast.at` and `RainCopy`, Amsterdam time) says "IN 10 MIN" at 06:35, counts down to "IN 1 MIN" at 06:44, then says "FOR 20 MIN" when the rain arrives at 06:45, and "Rain stops in 20 min", "Dry 07:05–08:10" below it.

## How it was found

- KNMI's free hourly station data (daggegevens.knmi.nl) for October to December 2025 and October to November 2026 gave the mornings with short showers after the clock change, so a 06:30 run would show a winter-time clock.
- KNMI's observed radar for seven of those nights (`nl_rdr_data_rtcor_5m_tar`, one file a day) gave the issue times when a short shower reached a town of 15,000 people or more.
- Eight forecast runs at those times were checked in every cell within 1 to 2 km of those towns, after packing each value as `server/job.py` does. This run had the strongest short showers. Arnhem's centre cell was the best place a viewer would know.
- 25 KNMI requests in all, none for the same file twice. Two of the day files (18 and 23 November 2025) had been fetched once before, for `research/verification/season.md`.

The forecast was the real nowcast that morning, not what happened. KNMI's radar measured a lighter shower in the cell (up to 1.2 mm/h, from 05:45 to 05:55 UTC), then a second one about an hour later.

The cell just south of it (row 437, column 423, 51.9733 N, 5.9152 E, over the Rhine) has a cleaner shower of 2.6, 5.2 and 1.7 mm/h from 05:50 UTC. There the app says "IN 10 MIN" at 06:40 and "FOR 15 MIN" at 06:50.

## How to check it against KNMI

1. Get `RAD_NL25_RAC_FM_202511170525.h5` from `radar_forecast` 2.0, and `RAD25_OPER_R___TARRRT__L2__20251116T080500_20251117T080000_0001.tar` from `nl_rdr_data_rtcor_5m_tar` 1.0, on the KNMI Data Platform.
2. Run `uv run --with numpy --with h5py python -I shower.py <forecast .h5> <radar .tar>`. It rewrites `shower.json` from them: the watch's cell for the place, then each value packed and read back as `server/job.py` and the watch do.

Running the same two files through `server/job.py`'s `build` and `server/watch_client.py` gives the same 31 values.

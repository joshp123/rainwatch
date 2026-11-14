Written by AI on 2026.11.14 by model gpt-6 astra

# Why OPERA missed the Dutch rain

OPERA really missed rain reaching the ground. The strongest explanation is loss of Dutch echoes in OPERA's ingestion, quality control or scan selection, before the final composite. The Dutch radar volumes supplied through ORD contain the echoes; the published OPERA composites largely do not. We cannot identify the particular filter or configuration from the public composites alone.

The failure is not representative of all Europe. In an inland German test, OPERA DBZH detected 94% of DWD's wet cells and RATE detected 69%. **OPERA is worth a German nowcast trial, but is not yet a dependable Europe-wide source for RainWatch.** These are observation comparisons, not evidence that our own two-hour forecast would beat another forecast.

## What changed from the first check

The original 5.2% figure was the fraction of KNMI-wet cell-times also wet in OPERA DBZH, at 0.1 mm/h. It was not the fraction of rainfall volume measured, nor a Europe-wide score. Most of the reference rain was offshore or coastal. Its pooled counts remain in [the original results](verification/opera_check_result.json).

This follow-up adds three checks:

1. Surface observations at 25 half-hourly times, 13 November 18:00 to 14 November 06:00 UTC. Each observation reports the preceding ten minutes. KNMI radar is averaged over the same ten minutes; OPERA is sampled at the nominal end time.
2. The Dutch polar radar volumes supplied through ORD at 13 November 17:55, compared with the 18:00 composites. This traces echoes upstream of OPERA's published output.
3. DWD's own radar analysis at 15 three-hourly times from 13 November 00:00 to 14 November 18:00. The times and German test rectangle were selected before looking at their rainfall.

## Ground instruments confirm genuine misses

Among 820 usable Dutch gauge/time observations, 22 report at least 0.1 mm/h. KNMI radar detects 16, OPERA DBZH detects one, and OPERA RATE detects none. Even accepting any wet pixel in a roughly 10 km-wide square around the station only raises DBZH to two detections; RATE stays at zero. A small map displacement cannot explain this.

Examples, all in mm/h:

| UTC | Station | Gauge | Present-weather sensor | KNMI radar | OPERA DBZH converted to rain | OPERA RATE |
|---|---|---:|---:|---:|---:|---:|
| 13 Nov 18:00 | Woensdrecht | 2.42 | 2.33 | 0.84 | 0 | 0 |
| 13 Nov 18:30 | Voorschoten | 0.534 | 0.94 | 0.36 | 0 | 0 |
| 13 Nov 21:30 | Leeuwarden | 1.53 | 1.20 | 1.74 | 0 | 0 |
| 14 Nov 00:30 | Schiphol | 1.10 | 0.807 | 0.12 | 0 | 0 |

These gauges are a separate physical measurement, but they are not a statistically independent validation set for KNMI's gauge-adjusted radar. The separate present-weather sensors also support real precipitation. On their available matched observations, KNMI detects 21 of 38 wet observations, RATE zero of 38, and DBZH two of 37; one wet observation has no DBZH coverage. This sensor sample includes offshore installations as well as land stations.

The instantaneous-versus-ten-minute mismatch affects exact scores. Sparse gauges also cannot establish what fraction of the original offshore radar echoes was real. They do establish that the discrepancy is not simply KNMI inventing sea rain.

KNMI's published gauge-adjustment field spans −4.88 to +1.84 dB across the 50 radar frames used here. It is not a huge positive correction manufacturing the discrepancy. Its [product paper](https://essd.copernicus.org/articles/17/4715/2025/essd-17-4715-2025.html) describes polarimetric clutter removal and vertical-profile correction, but also documents residual interference over the sea. KNMI remains an imperfect reference.

## Where the echoes disappear

I decoded the **filtered DBZH**, not unfiltered TH, in the Dutch volumes delivered through ORD. I mapped the low scans, at elevations up to 2.8°, onto KNMI cell centres using the radar location, actual ray azimuths and range-bin metadata. Wet means at least 7.01 dBZ, equivalent to 0.1 mm/h under Marshall–Palmer.

At 13 November 18:00:

| Cells within 100 km of radar | KNMI wet | Wet in at least one low input scan | Wet in OPERA DBZH |
|---|---:|---:|---:|
| Den Helder | 3,277 | 2,627 | 186 |
| Herwijnen | 2,367 | 2,063 | 391 |

These overlapping areas must not be added together. The input scans run from approximately 17:55 to 17:59, within CIRRUS's recorded 17:50:01–18:00 window. Even the individual 0.3° scans contain far more matching echoes than the composite. At 1,483 Den Helder-area cells and 1,053 Herwijnen-area cells, an input low scan reaches **20 dBZ or more**, while OPERA DBZH remains below 7.01 dBZ. This is not just rounding away marginal drizzle.

The original checker’s unit conversions are correct. KNMI's calibration is `0.01 * stored value` mm per five minutes. OPERA's gain is 1 and offset 0. Its grid's upper-left projected corner is effectively (0, 0), confirming the original mapping. Missing values and undetect values are distinct. At Woensdrecht, both OPERA products explicitly store **undetect**, not missing data.

This locates a substantial discrepancy between the input volume available through ORD and the composite. It does **not** prove which volume the production system actually selected: the composite lists radar nodes, not each selected source file or the rejected gates. A source-selection or ingestion problem remains possible alongside excessive filtering.

### Best-supported mechanism, and the remaining uncertainty

[EUMETNET's production description](https://www.eumetnet.eu/wp-content/uploads/2024/06/NIMBUS_composite_vs_ODYSSEY_1.0_19062024.pdf) explains that NIMBUS selects the lowest scan and then the radar beam closest to sea level; it does not average all available echoes. Its processing includes clutter, beam-blockage and satellite filters, configurable by radar provider. The satellite filter can explicitly replace echoes with undetect. CIRRUS takes a vertical maximum, so rain retained in higher scans can survive there while RATE remains dry.

That combination fits the observed loss and the difference between RATE and DBZH. It does not establish that the satellite filter caused this event. The public files expose only the total quality field, without the individual filter results. Woensdrecht's RATE quality is 0.9 despite measured rain and an undetect output. **That is not 90% confidence in dry weather.** NIMBUS's documented quality index combines filter indicators and can even default to 1 when none were applied.

To settle the exact cause, the production trace must identify the selected Dutch volumes/scans at 17:45–18:15 on 13 November and compare DBZH before and after each filter, including its radar-specific configuration and satellite input. Replaying those selected inputs with each filter disabled would distinguish suppression from ingestion or selection. Nothing in this investigation contacted the operators. Public incoming volumes alone cannot recover that trace.

## Independent national comparison outside the Netherlands

The reference is [DWD's public RV product](https://opendata.dwd.de/weather/radar/composite/rv/), **lead time 000 only**, not its extrapolated forecast. The actual HDF5 metadata identifies a five-minute `ACRR` accumulation, converted to mm/h with its stored gain and offset, then multiplied by 12. Geolocation uses DWD's own projection and upper-left corner, including its half-pixel offset.

The test covers the inland German rectangle **9–13°E, 51–54°N**, around 98,212 valid DWD cells per time. This is outside the useful Dutch reference area. DWD and OPERA process some of the same radar measurements, so this is an independent national **processing chain**, not independent radar hardware or ground truth.

All scores exclude missing data. A hit is a cell both products call wet; a false alarm here means OPERA wet and DWD dry, not proven absence of rain. CSI is hits divided by hits + misses + false alarms.

| Pooled threshold | Product | DWD wet cells detected | OPERA wet cells dry in DWD | CSI |
|---|---|---:|---:|---:|
| 0.1 mm/h | RATE | 68.8% | 21.2% | 0.581 |
| 0.1 mm/h | DBZH, Marshall–Palmer | 94.2% | 33.8% | 0.636 |
| 1 mm/h | RATE | 68.4% | 43.2% | 0.450 |
| 1 mm/h | DBZH, Marshall–Palmer | 95.6% | 53.5% | 0.455 |

At 0.1 mm/h, the reference contains 26,348 wet cell-times. RATE has 18,128 hits, 8,220 misses and 4,869 false alarms; DBZH has 24,819 hits, 1,529 misses and 12,698 false alarms. Averaging DWD inside RATE's 2 km cells gives virtually the same result: 68.2% detection and CSI 0.588.

There is real variation: RATE detects 45–80% of wet cells in the substantial rainy samples on 13 November. Both products perform worse as the region becomes nearly dry on 14 November. A few isolated strong DWD pixels then dominate the intensity statistics. Only 282 reference cell-times reach 5 mm/h across the whole sample; neither that count nor the isolated maximum of about 64 mm/h makes this a convincing heavy-rain test.

DBZH's high detection comes with an expanded wet footprint and unreliable surface intensity. A vertical maximum converted through a fixed Z–R relation is not a calibrated ground rain rate. The German result disproves a Europe-wide “OPERA sees only 5%” conclusion. It does not resolve the original disagreement specifically around Essen and Neuheilenbach, nor validate Belgium, France, mountains or coastlines.

## Reproduction and what remains to test

The scripts and numeric results are in `research/verification/`:

- `opera_cause.py WORKDIR OUT.json`: DWD comparison, surface observations, Dutch gauge-adjustment ranges. Dependencies: numpy, h5py, pyproj, xarray, netcdf4; also imports the original `opera_check.py`.
- `opera_polar.py WORKDIR OUT.json`: Dutch volume tracing and exact composite metadata. Also needs scipy. Run after the first script.
- `opera_summary.py RESULT.json`: pooled counts used above.
- `opera_cause_result.json` and `opera_polar_result.json`: retained public observations, per-time scores and metadata. The earlier check's results remain separately available.

Supply `KNMI_API_KEY` by decrypting the existing age file into an environment variable; do not print it. This investigation used fewer than 100 KNMI API requests. Downloads were cached through every rerun and deleted afterwards. No paid service or registration was used. Fixed dates make the experiment explicit; once the rolling stores expire, it needs archived files rather than a blind rerun.

Before shipping, collect several independent rain episodes per intended country, including shallow coastal rain, widespread frontal rain and sustained heavy showers. Save simultaneous national observations and gauges while the rolling files remain available. Then run the actual nowcast retrospectively at 5–120-minute leads, measuring onset/cessation error, missed rain and false alerts against persistence and the relevant national service. The current 42-hour, three-hourly German sample establishes input plausibility; it cannot test motion tracking or forecast skill.

## Verdict for RainWatch

Keep KNMI in its home area. Do not deploy OPERA as an unqualified European fallback: genuine Dutch rain is lost, and the exact production cause remains unresolved. Outside that area, **DBZH is credible enough for a German nowcast experiment**, with RATE as an additional input to evaluate. Neither is yet validated for a trustworthy two-hour rain line across Europe. The next useful work is a forecast trial against national observations, not rejecting OPERA on the Dutch 5% figure or assuming good German detection proves a good forecast.

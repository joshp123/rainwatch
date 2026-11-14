<!-- Written by AI on 2026.11.14 by model claude opus 5.5, at Josh's request: "if we're using KNMI data, then why aren't we also including the British, Belgian, German radars in our own version? ... figure out what's actually state of the art". -->

# Which radar data and which forecast method BuienWatch should use

## Short answer

- KNMI's radar picture already includes the Belgian and German radars, and it reaches far enough west that British radars would change nothing within two hours.
- What matters more is the method used to move the rain forward. Blending the radar with a weather model is the method the best weather services use. KNMI publishes exactly that, free, as a pilot.
- On the one rainy case measured, the blend was clearly better for the first hour and worse in the second. A season of KNMI's archive will settle it.

## What KNMI's picture contains (measured from its files)

Every KNMI radar file lists the radars it uses:
- **Netherlands:** Den Helder and Herwijnen.
- **Belgium:** Jabbeke, Helchteren and Wideumont.
- **Germany:** Essen, Neuheilenbach and Borkum (Borkum was switched off on 14 November).

KNMI then cleans the picture and adjusts it to its rain gauges ([KNMI, 11 May 2026](https://www.knmi.nl/over-het-knmi/nieuws/regenbuien-nu-nog-beter-te-volgen)).

The picture has data out to the edge of its grid, at 0° longitude (Greenwich), from latitude 50 to 53 N. That is about 300 km west of the Dutch coast. Rain moving at 80 km/h covers 160 km in two hours, so anything that reaches the Netherlands within two hours is already on KNMI's picture. British radars only extend the view beyond 0°.

## Why Buienradar adds British radars

Buienradar buys KNMI's images plus British, Belgian and German ones and builds its own, larger picture ([Buienradar](https://www.buienradar.nl/nederland/weerbericht/blog/hoe-werkt-de-buienradar-precies-motregen-regen-radar-uitleg-radio-golven)). The larger area serves its 3-, 8- and 24-hour radars and its European map, not the next two hours over the Netherlands. Its forecast moves the latest picture along and, by its own account, cannot handle showers forming or dying out ([FAQ](https://www.buienradar.nl/overbuienradar/faq)).

## The state of the art

- **Moving the rain along.** KNMI's operational forecast does this ([dataset](https://dataplatform.knmi.nl/dataset/radar-forecast-2-0)). It is "deterministic", made with the open-source pySTEPS library from KNMI's cleaned, gauge-adjusted picture. Like Buienradar's, it can't see showers forming or dying, which is why both fade after about an hour.
- **Blending with a weather model.** pySTEPS mixes the radar forecast with a high-resolution weather model, scale by scale. Small showers hand over to the model sooner than large rain areas, and the weights come from how well each has done in the last hours ([Imhoff et al. 2023](https://rmets.onlinelibrary.wiley.com/doi/10.1002/qj.4461)). This is the operational practice:
  - Belgium's RMI runs it every 5 minutes: 24 versions, 1 km, 6 hours ahead ([RMI, 2026](https://www.meteo.be/uploads/media/6a0884354476c/rmi-enwfc2026-poster.pdf?v20250829-1211)).
  - MeteoSwiss blends its own nowcast with its weather model ([Ntoumos et al. 2026](https://rmets.onlinelibrary.wiley.com/doi/10.1002/qj.70181)).
  - KNMI publishes its own blend as a pilot, free under CC BY 4.0: 20 versions blended with the HARMONIE-AROME weather model, 1 km, every 5 minutes, 6 hours ahead, with the chance of rain at six thresholds ([members](https://dataplatform.knmi.nl/dataset/seamless-precipitation-ensemble-forecast-members-1-0), [probabilities](https://dataplatform.knmi.nl/dataset/seamless-precipitation-ensemble-forecast-probabilities-1-0)). It was announced to run until January 2026 "at the latest", but it was still updating every 5 minutes on 14 November 2026.
- **Machine learning.** Models trained on radar, often with satellite and weather-model data, beat extrapolation mostly beyond the first hour:
  - Google's MetNet-3.
  - RainPro-8, over Europe for 8 hours ([ICLR 2026](https://proceedings.iclr.cc/paper_files/paper/2026/file/2c2f104b95306ab94058a97ba13b8927-Paper-Conference.pdf)). Its CSI was 0.279, against 0.270 for MetNet-3 and 0.149 for pySTEPS.
  - KNMI's own research model is skilful for heavy rain up to 60 minutes ([Cambier van Nooten et al. 2023](https://www.knmi.nl/research/publications/improving-precipitation-nowcasting-for-high-intensity-events-using-deep-generative-models-with-balanced-loss-and-temperature-data-a-case-study-in-the-netherlands)).
  
  None of these is offered as an open, ready-to-run forecast for the Netherlands. Running one ourselves would need GPUs and our own training and checking.
- **Radars across Europe.** EUMETNET's OPERA composite of European radars has been open since May 2026, under CC BY 4.0. It is 1 km, every 5 minutes, all of Europe, through the Open Radar Data API and a public 24-hour cache ([OPERA docs](https://eumetnet.github.io/openradardata-documentation/1-ORD-API-overview/)). Each country decides whether its radars are included.

## Measured: one rainy case

The forecasts were issued at 12:30 UTC on 13 November. They were scored at 48 Dutch places against KNMI's observed 5-minute radar rainfall, with "wet" meaning 0.1 mm/h or more; 125 wet steps were observed. The script is `research/verification/score_case.py`. Each cell gives CSI, the share of rain caught, and the share of forecast rain that stayed dry.

| | 5–30 min | 35–60 min | 65–120 min | All |
|---|---|---|---|---|
| KNMI plain | 0.44, 50%, 20% | 0.30, 61%, 63% | 0.10, 17%, 82% | 0.20 |
| KNMI blended (rain if half the versions agree) | 0.51, 56%, 14% | 0.40, 52%, 37% | 0.05, 6%, 82% | 0.22 |
| Buienradar | 0.34, 47%, 44% | 0.24, 65%, 73% | 0.07, 16%, 89% | 0.15 |

The blend is better in the first hour, with far fewer false alarms, and worse after it, where it forecasts almost no rain. This is one day of light rain. KNMI's archive holds the plain forecast since August 2024 and the blend since March 2025, so a season of cases, including summer showers, can be scored without waiting for rain.

## What BuienWatch should do

1. **At launch,** use KNMI's plain forecast, as built and proposed.
2. **Show the plain forecast for the first 30 minutes, then the blend.** The season test (`research/verification/season.md`) scored 66 rainy days from April 2025 to November 2026, 24 of them in summer and 10 with thunderstorm cells. The 13 November pattern, where the blend was worse in the second hour, did not hold:
   - **5 minutes ahead:** the plain forecast is better.
   - **10 to 30 minutes:** level.
   - **35 to 60 minutes:** the blend is slightly better.
   - **65 to 120 minutes:** the blend is better, CSI 0.48 against 0.44, on 77% of days.
   
   Switching at 30 minutes gains 0.027 CSI over the plain forecast alone (95% interval 0.016 to 0.038). The newest 30 days agree. If KNMI's blend file is late or the pilot ends, the server falls back to the plain forecast.
3. **Don't build our own Dutch radar picture.** KNMI's already has the Belgian and German radars and is cleaned and gauge-adjusted. Ours would be worse and take more work.
4. **Outside KNMI's area,** use OPERA's open European composite and run pySTEPS on it ourselves. That gives a 2-hour, 5-minute forecast across Europe in place of WeatherKit's hourly one, and it is where adding other countries' radars pays. Still to check: OPERA's delay, which countries share, whether the Met Office does, and the computing cost.
5. **Machine learning:** not now. Revisit when an open model trained for this region exists, or KNMI ships one.

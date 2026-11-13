"""Fetch Buienradar's graph nowcast on a grid over the Netherlands and at European cities,
save every response, and classify each two-hour window."""
import json, sys, time, urllib.request, pathlib

out = pathlib.Path(sys.argv[1])
points = [(round(lat, 2), round(lon, 2), "NL") for lat in [50.9 + 0.35 * i for i in range(8)] for lon in [3.6 + 0.45 * j for j in range(8)]]
cities = {"London": (51.51, -0.13), "Paris": (48.86, 2.35), "Brussels": (50.85, 4.35), "Berlin": (52.52, 13.40), "Hamburg": (53.55, 9.99),
          "Copenhagen": (55.68, 12.57), "Oslo": (59.91, 10.75), "Stockholm": (59.33, 18.07), "Dublin": (53.35, -6.26), "Glasgow": (55.86, -4.25),
          "Manchester": (53.48, -2.24), "Bergen": (60.39, 5.32), "Munich": (48.14, 11.58), "Zurich": (47.37, 8.54), "Vienna": (48.21, 16.37),
          "Prague": (50.08, 14.44), "Warsaw": (52.23, 21.01), "Milan": (45.46, 9.19), "Rome": (41.90, 12.50), "Madrid": (40.42, -3.70),
          "Barcelona": (41.39, 2.17), "Lisbon": (38.72, -9.14), "Bordeaux": (44.84, -0.58), "Lyon": (45.76, 4.84), "Brest": (48.39, -4.49),
          "Cork": (51.90, -8.47), "Aberdeen": (57.15, -2.09), "Gdansk": (54.35, 18.65), "Budapest": (47.50, 19.04), "Athens": (37.98, 23.73)}
points += [(lat, lon, name) for name, (lat, lon) in cities.items()]

def fetch(product, lat, lon):
    url = f"https://graphdata.buienradar.nl/3.0/forecast/geo/{product}?lat={lat}&lon={lon}&language=en"
    with urllib.request.urlopen(url, timeout=15) as r:
        return json.load(r)

def classify(heights):
    w = heights[:25]
    rain = [h > 0 for h in w]
    if not any(rain): return "dry"
    if all(rain): return "raining throughout"
    changes = sum(1 for a, b in zip(rain, rain[1:]) if a != b)
    if rain[0]: return "raining, stops" if changes == 1 else "raining, stops, returns"
    return "dry, rain starts" if changes <= 2 else "dry, showers on and off"

summary = []
for lat, lon, name in points:
    product = "RainNL3Hour" if name == "NL" else "RainEU3Hour"
    try:
        data = fetch(product, lat, lon)
    except Exception as error:
        try:
            product = "RainEU3Hour"; data = fetch(product, lat, lon)
        except Exception as error2:
            summary.append({"name": name, "lat": lat, "lon": lon, "error": str(error2)}); continue
    (out / f"{name}_{lat}_{lon}.json").write_text(json.dumps(data))
    f = data.get("forecasts", [])
    heights = [x["percentageValue"] for x in f]
    mm = [x["dataValue"] for x in f]
    summary.append({"name": name, "lat": lat, "lon": lon, "product": product, "start": f[0]["dateTime"] if f else None,
                    "steps": len(f), "state": classify(heights), "peak_pct": max(heights[:25], default=0), "peak_mm": max(mm[:25], default=0),
                    "heights": heights[:25]})
    time.sleep(0.3)

(out / "summary.json").write_text(json.dumps(summary, indent=1))
from collections import Counter
print(Counter(s.get("state", "error") for s in summary))
for s in summary:
    if s.get("state") not in (None, "dry"):
        print(f'{s["name"]:11} {s["lat"]:6} {s["lon"]:6} {s["state"]:26} peak {s["peak_pct"]:5}% {s["peak_mm"]:5} mm/h  ' + "".join("▁▂▃▄▅▆▇█"[min(7, int(h / 12.5))] if h > 0 else "·" for h in s["heights"]))

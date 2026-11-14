#!/usr/bin/env python3
# Written by AI on 2026.11.14 by model claude opus 5.5, for research/europe-sources.md.
# Scores national radar nowcasts outside KNMI's area (DWD RV for Germany and its neighbours, MET Norway's radar
# nowcast for the Nordics) against each service's own observed radar, and compares them with "rain stays as it is",
# with a perfect hourly forecast, and with real archived hourly model forecasts (Open-Meteo), which stand in for
# WeatherKit's hourly data. Also scores the hourly forecasts on the 86 Dutch cases of season.py.
#
#   python -I europe_check.py collect dwd|met WORK START END   # START/END as YYYYMMDDHHMM, inside the last 48 hours
#   python -I europe_check.py geo WORK COUNTRIES.geojson         # country of each 10 km lattice point (Natural Earth 50m)
#   python -I europe_check.py score dwd|met WORK Germany,Austria [MODELS.json]   # writes WORK/<src>_sample.json
#   python -I europe_check.py models WORK/<src>_sample.json best_match,ecmwf_ifs025 OUT.json 2026-11-12,2026-11-13
#   python -I europe_check.py nl season_cells.csv.gz WORK          # Dutch cases: fetches the models, then scores
# Needs numpy, h5py, netCDF4 (with OPeNDAP), pyproj and shapely. Wet means 0.1 mm/h or more, as in season.py.
# DWD and MET Norway keep only the last 48 hours, so a case can only be collected within two days of the rain.
import collections, csv, datetime as dt, glob, gzip, io, json, os, sys, tarfile, time, urllib.error, urllib.parse, urllib.request
import numpy as np

UA = {"User-Agent": "rainwatch-research/0.1 (verification script)"}
WET, QUALIFY, STEP = 0.1, 0.05, 10          # mm/h; share of place-leads wet for a case to count; lattice step in km
DWD = "https://opendata.dwd.de/weather/radar/composite/rv/composite_rv_{:%Y%m%d_%H%M}.tar"
MET = ("https://thredds.met.no/thredds/dodsC/radarnowcasting/"
       "yrwms-nordic.mos.pcappi-0-rr.noclass-clfilter-novpr-clcorr-block.nordiclcc-1000.{:%Y%m%dT%H%M}00Z.nc")
OPEN_METEO = "https://historical-forecast-api.open-meteo.com/v1/forecast?"

def get(url, rng=None):
    headers = dict(UA, **({"Range": rng} if rng else {}))
    for attempt in range(5):
        try: return urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=120).read()
        except urllib.error.HTTPError as e:
            if e.code == 404: return None
        except (urllib.error.URLError, TimeoutError, ConnectionError): pass
        time.sleep(5 * (attempt + 1))
    return None

# ---------------------------------------------------------------- collect: +0 of every run, all leads of runs on the half hour
def dwd_frame(raw):
    import h5py
    f = h5py.File(io.BytesIO(raw), "r"); w = f["dataset1/data1/what"].attrs
    d = f["dataset1/data1/data"][()][::STEP, ::STEP].astype("float64")
    r = (d * w["gain"] + w["offset"]) * 12; r[d == 0] = 0; r[d == w["nodata"]] = np.nan    # mm per 5 min -> mm/h
    return r.astype("float32")

def collect_dwd(t):
    full = t.minute in (0, 30)
    raw = get(DWD.format(t)) if full else get(DWD.format(t), "bytes=0-1048575")   # the +0 member comes first in the tar
    if raw is None: return None, None
    tar, frames = tarfile.open(fileobj=io.BytesIO(raw)), {}
    while True:
        try: m = tar.next()
        except (tarfile.ReadError, EOFError): break
        if m is None: break
        frames[int(m.name.split("_")[-1][:3])] = dwd_frame(tar.extractfile(m).read())
        if not full: break
    forecast = np.stack([frames[L] for L in range(0, 125, 5)]) if full and len(frames) == 25 else None
    return frames.get(0), forecast

def collect_met(t):
    import netCDF4
    for attempt in range(4):
        try:
            ds = netCDF4.Dataset(MET.format(t)); v = ds["lwe_precipitation_rate"]
            a = np.ma.filled((v[:, ::STEP, ::STEP] if t.minute in (0, 30) else v[0:1, ::STEP, ::STEP]).astype("float32"), np.nan)
            ds.close(); return a[0], (a if a.shape[0] == 24 else None)       # 24 steps: +0 to +115 minutes
        except OSError: time.sleep(5 * (attempt + 1))
    return None, None

def collect(src, work, start, end):
    truth, fc, t = {}, {}, dt.datetime.strptime(start, "%Y%m%d%H%M")
    while t <= dt.datetime.strptime(end, "%Y%m%d%H%M"):
        obs, forecast = (collect_dwd if src == "dwd" else collect_met)(t)
        if obs is not None: truth[t] = obs
        if forecast is not None: fc[t] = forecast
        print(src, t, "forecast" if forecast is not None else "", flush=True); t += dt.timedelta(minutes=5)
    np.savez_compressed(os.path.join(work, f"{src}_{start}_{end}.npz"),
        truth_times=np.array([f"{s:%Y%m%d%H%M}" for s in truth]), truth=np.stack(list(truth.values())),
        fc_times=np.array([f"{s:%Y%m%d%H%M}" for s in fc]), fc=np.stack(list(fc.values())))

def geo(work, countries):
    import h5py, netCDF4
    from pyproj import Proj
    from shapely.geometry import Point, shape
    from shapely.strtree import STRtree
    raw = get("https://opendata.dwd.de/weather/radar/composite/rv/composite_rv_LATEST.tar", "bytes=0-1048575")
    tar = tarfile.open(fileobj=io.BytesIO(raw)); w = h5py.File(io.BytesIO(tar.extractfile(tar.next()).read()), "r")["where"].attrs
    p = Proj(w["projdef"].decode() if isinstance(w["projdef"], bytes) else w["projdef"]); x0, y0 = p(w["UL_lon"], w["UL_lat"])
    ii, jj = np.meshgrid(np.arange(0, 1200, STEP), np.arange(0, 1100, STEP), indexing="ij")
    dlon, dlat = p(x0 + (jj + 0.5) * 1000, y0 - (ii + 0.5) * 1000, inverse=True)            # row 0 is the northern edge
    t = dt.datetime.now(dt.timezone.utc).replace(tzinfo=None, second=0, microsecond=0); t -= dt.timedelta(minutes=10 + t.minute % 5)
    ds = netCDF4.Dataset(MET.format(t)); mlat, mlon = np.asarray(ds["lat"][::STEP, ::STEP]), np.asarray(ds["lon"][::STEP, ::STEP])
    feats = json.load(open(countries))["features"]; shapes = [shape(f["geometry"]) for f in feats]; tree = STRtree(shapes)
    def country(lat, lon):
        out = []
        for la, lo in zip(lat.ravel(), lon.ravel()):
            hit = [k for k in tree.query(Point(lo, la)) if shapes[k].contains(Point(lo, la))]
            out.append(feats[hit[0]]["properties"]["ADMIN"] if hit else "")
        return np.array(out)
    np.savez(os.path.join(work, "geo.npz"), dwd_lat=dlat.ravel(), dwd_lon=dlon.ravel(), dwd_cty=country(dlat, dlon),
             met_lat=mlat.ravel(), met_lon=mlon.ravel(), met_cty=country(mlat, mlon))

# ---------------------------------------------------------------- archived hourly model forecasts
def models(sample_path, model_list, out_path, days):
    """Open-Meteo's archive of each model's latest run, hourly; value at hour H is the sum over the hour ending at H."""
    sample = json.load(open(sample_path)); ms = model_list.split(",")
    out = json.load(open(out_path)) if os.path.exists(out_path) else {}
    out["_places"] = sample["places"]
    for reg, latlon in sample["latlon"].items():
        for day in days.split(","):
            key = f"{reg}|{day}"
            if all(key in out.get(m, {}) for m in ms): continue
            for i0 in range(0, len(latlon), 50):
                chunk = latlon[i0:i0 + 50]
                q = {"latitude": ",".join(f"{a:.4f}" for a, _ in chunk), "longitude": ",".join(f"{b:.4f}" for _, b in chunk),
                     "hourly": "precipitation", "start_date": day, "end_date": day, "models": ",".join(ms), "timezone": "GMT"}
                for attempt in range(10):
                    try: d = json.loads(urllib.request.urlopen(OPEN_METEO + urllib.parse.urlencode(q), timeout=120).read()); break
                    except urllib.error.HTTPError: time.sleep(30 * (attempt + 1))        # 429: the free API's minute limit
                else: raise RuntimeError(f"Open-Meteo kept refusing {key}; its free limit is 5,000 places an hour")
                for j, loc in enumerate(d if isinstance(d, list) else [d]):
                    for m in ms:
                        out.setdefault(m, {}).setdefault(key, {})[str(i0 + j)] = loc["hourly"].get(f"precipitation_{m}" if len(ms) > 1 else "precipitation")
                time.sleep(3)
            json.dump(out, open(out_path, "w")); print(key, flush=True)

def model_wet(om, model, key_for_day, place, hour_start, threshold):
    end = hour_start + dt.timedelta(hours=1)
    v = om[model].get(key_for_day(end.strftime("%Y-%m-%d")), {}).get(str(place))
    return v is not None and v[end.hour] is not None and v[end.hour] >= threshold

# ---------------------------------------------------------------- scoring
def csi(obs, fc):
    h, m, fa = np.sum(obs & fc), np.sum(obs & ~fc), np.sum(~obs & fc)
    return round(float(h / (h + m + fa)), 3) if h + m + fa else float("nan")

def clock_hours(t, leads):
    """Indices of the leads that fall in each clock hour; the 5-minute step ending at lead L starts at t + L - 5."""
    out = collections.defaultdict(list)
    for k, L in enumerate(leads): out[(t + dt.timedelta(minutes=L - 5)).replace(minute=0)].append(k)
    return out

def perfect_hourly(t, leads, obs, threshold):
    out = np.zeros(obs.shape, bool)
    for ks in clock_hours(t, leads).values(): out[:, ks] = (obs[:, ks].mean(1) >= threshold)[:, None]
    return out

def bands(leads):
    return {"5-30": [k for k, L in enumerate(leads) if L <= 30], "35-60": [k for k, L in enumerate(leads) if 35 <= L <= 60],
            "65+": [k for k, L in enumerate(leads) if L >= 65], "all": list(range(len(leads)))}

def report(name, cases, leads, forecast):
    """cases: (t, obs[places, leads]); forecast(t, obs) -> bool[places, leads]. Pools all place-leads, as season.py does."""
    fcs = [forecast(t, o) for t, o in cases]
    row = {b: csi(np.concatenate([o[:, ks] >= WET for _, o in cases]).ravel(), np.concatenate([f[:, ks] for f in fcs]).ravel())
           for b, ks in bands(leads).items()}
    print(f"  {name:28s}", "  ".join(f"{b} {v:.3f}" for b, v in row.items()))

def score(src, work, regions, om_path=None):
    g = np.load(os.path.join(work, "geo.npz")); cty = g[f"{src}_cty"]
    truth, fc = {}, {}
    for p in sorted(glob.glob(os.path.join(work, f"{src}_2*.npz"))):
        z = np.load(p)
        for t, a in zip(z["truth_times"], z["truth"]): truth[dt.datetime.strptime(str(t), "%Y%m%d%H%M")] = a.ravel()
        for t, a in zip(z["fc_times"], z["fc"]): fc[dt.datetime.strptime(str(t), "%Y%m%d%H%M")] = a.reshape(a.shape[0], -1)
    leads = list(range(5, 125, 5)) if src == "dwd" else list(range(5, 120, 5))
    om = json.load(open(om_path)) if om_path else None
    sample = {"places": {}, "latlon": {}}
    for reg in regions.split(","):
        mask = np.isin(cty, reg.split("+")); cases = []
        for t in sorted(fc):
            if t not in truth or not all(t + dt.timedelta(minutes=L) in truth for L in leads): continue
            obs = np.stack([truth[t + dt.timedelta(minutes=L)] for L in leads], 1); now = fc[t][[L // 5 for L in leads]].T
            ok = mask & np.isfinite(obs).all(1) & np.isfinite(now).all(1) & np.isfinite(truth[t])
            if ok.sum() >= 20 and np.mean(obs[ok] >= WET) >= QUALIFY: cases.append((t, ok, obs, now, truth[t]))
        if not cases: print(f"\n{src} {reg}: no rainy case"); continue
        print(f"\n{src} {reg}: {len(cases)} issue times, {cases[0][0]:%d %b %H:%M} to {cases[-1][0]:%d %b %H:%M} UTC, "
              f"{sum(c[1].sum() for c in cases)} place-issues")
        def run(sel):
            cs = [(t, obs[s]) for t, ok, obs, now, t0 in cases for s in [ok & sel]]
            lookup = {t: (now[ok & sel], t0[ok & sel], np.where(ok & sel)[0]) for t, ok, obs, now, t0 in cases}
            report("radar nowcast", cs, leads, lambda t, o: lookup[t][0] >= WET)
            report("rain stays as it is", cs, leads, lambda t, o: np.repeat(lookup[t][1][:, None] >= WET, len(leads), 1))
            report("perfect hourly forecast", cs, leads, lambda t, o: perfect_hourly(t, leads, o, 0.1))
            return cs, lookup
        run(np.ones(len(cty), bool))
        rng = np.random.default_rng(1); first = np.where(cases[0][1])[0]
        pick = np.sort(rng.choice(first, min(150, len(first)), replace=False)); sample["places"][reg] = pick.tolist()
        sample["latlon"][reg] = [[float(g[f"{src}_lat"][i]), float(g[f"{src}_lon"][i])] for i in pick]
        if om and reg in om.get("_places", {}):
            sel = np.zeros(len(cty), bool); sel[om["_places"][reg]] = True; pos = {p: i for i, p in enumerate(om["_places"][reg])}
            print(f"  on {sel.sum()} sampled places:")
            cs, lookup = run(sel)
            for model in [m for m in om if not m.startswith("_")]:
                for th in (0.1, 0.2, 0.5):
                    def f(t, o, model=model, th=th):
                        out = np.zeros(o.shape, bool)
                        for h, ks in clock_hours(t, leads).items():
                            for r, place in enumerate(lookup[t][2]):
                                out[r, ks] = model_wet(om, model, lambda d: f"{reg}|{d}", pos[place], h, th)
                        return out
                    report(f"{model}, wet if >= {th} mm", cs, leads, f)
    json.dump(sample, open(os.path.join(work, f"{src}_sample.json"), "w"))

def nl(cells_path, work):
    rows = list(csv.DictReader(gzip.open(cells_path, "rt"))); leads = list(range(5, 121, 5))
    by = collections.defaultdict(dict)
    for r in rows: by[(r["issue"], float(r["lat"]), float(r["lon"]))][int(r["lead"])] = (float(r["obs"]), float(r["det"]))
    places = sorted({(k[1], k[2]) for k in by}); pidx = {p: i for i, p in enumerate(places)}
    days = sorted({d for k in by for d in (k[0][:8], (dt.datetime.strptime(k[0], "%Y%m%d%H%M") + dt.timedelta(minutes=125)).strftime("%Y%m%d"))})
    days = [f"{d[:4]}-{d[4:6]}-{d[6:]}" for d in days]
    sp = os.path.join(work, "nl_sample.json"); json.dump({"places": {"nl": list(range(len(places)))}, "latlon": {"nl": places}}, open(sp, "w"))
    op = os.path.join(work, "nl_models.json"); models(sp, "best_match,ecmwf_ifs025,icon_d2,knmi_seamless", op, ",".join(days))
    om = json.load(open(op))
    groups = collections.defaultdict(list)
    for (issue, la, lo), d in by.items():
        if all(np.isfinite(d[L][0]) for L in leads): groups[issue].append(((la, lo), d))
    cases = [(dt.datetime.strptime(i, "%Y%m%d%H%M"), np.array([[d[L][0] for L in leads] for _, d in g]), g) for i, g in sorted(groups.items())]
    print(f"Netherlands: {len(cases)} KNMI cases from season.py, 48 places")
    cs = [(t, o) for t, o, _ in cases]; det = {t: np.array([[d[L][1] >= WET for L in leads] for _, d in g]) for t, _, g in cases}
    plc = {t: [pidx[p] for p, _ in g] for t, _, g in cases}
    report("KNMI plain forecast", cs, leads, lambda t, o: det[t])
    report("perfect hourly forecast", cs, leads, lambda t, o: perfect_hourly(t, leads, o, 0.1))
    for model in [m for m in om if not m.startswith("_")]:
        for th in (0.1, 0.2, 0.5):
            def f(t, o, model=model, th=th):
                out = np.zeros(o.shape, bool)
                for h, ks in clock_hours(t, leads).items():
                    for r, p in enumerate(plc[t]): out[r, ks] = model_wet(om, model, lambda d: f"nl|{d}", p, h, th)
                return out
            report(f"{model}, wet if >= {th} mm", cs, leads, f)
            if model == "icon_d2" and th == 0.2: best = f
    # KNMI minus the best hourly model (ICON-D2, wet at 0.2 mm), 95% interval from resampling whole days 4,000 times
    per_day = collections.defaultdict(lambda: np.zeros((2, 4, 3)))
    for t, o in cs:
        for j, fc in enumerate((det[t], best(t, o))):
            for b, ks in enumerate(bands(leads).values()):
                ob, f = o[:, ks] >= WET, fc[:, ks]; per_day[t.date()][j, b] += [np.sum(ob & f), np.sum(ob & ~f), np.sum(~ob & f)]
    arr = np.stack(list(per_day.values())); rng = np.random.default_rng(0)
    def diff(a):
        tot = a.sum(0); c = tot[..., 0] / tot.sum(-1); return c[0] - c[1]
    boot = np.array([diff(arr[rng.integers(0, len(arr), len(arr))]) for _ in range(4000)])
    lo, hi = np.percentile(boot, [2.5, 97.5], axis=0)
    print(f"  KNMI minus ICON-D2 >= 0.2 mm, {len(arr)} days:", "  ".join(f"{b} {d:+.3f} ({l:+.3f} to {h:+.3f})" for b, d, l, h in zip(bands(leads), diff(arr), lo, hi)))

if __name__ == "__main__":
    cmd, a = sys.argv[1], sys.argv[2:]
    if cmd == "collect": collect(*a)
    elif cmd == "geo": geo(*a)
    elif cmd == "models": models(*a)
    elif cmd == "score": score(*a)
    elif cmd == "nl": nl(*a)
    else: sys.exit("usage: see the comment at the top of europe_check.py")

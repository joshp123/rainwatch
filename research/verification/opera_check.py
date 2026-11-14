#!/usr/bin/env python3
# Written by AI on 2026.11.14 by model claude sonnet 5.5, for research/opera-check.md.
# Compares EUMETNET OPERA radar composites (RATE, and DBZH converted with Marshall-Palmer) with KNMI's
# gauge-adjusted observed 5-minute radar rainfall (nl_rdr_data_rtcor_5m 1.0) on KNMI's grid, wet = 0.1 mm/h.
# Also audits the OPERA backup store for missing and late files.
#
#   KNMI_API_KEY=... python -I opera_check.py scan    WORKDIR   # download KNMI's last 24 h at 15-minute steps, print rain per time
#   KNMI_API_KEY=... python -I opera_check.py compare WORKDIR   # download OPERA + KNMI 5-minute files at rainy times, pool the scores
#   KNMI_API_KEY=... python -I opera_check.py figure WORKDIR YYYYMMDDHHMM OUT.png   # side-by-side picture at one time
#   python -I opera_check.py store                              # missing and late files in the backup store, no key needed
# Needs numpy, h5py, pyproj, scipy, global-land-mask (and matplotlib for figure). Downloads stay in WORKDIR; delete it when finished.
#
# OPERA: DBZH (1 km, maximum-reflectivity composite, 5 min) -> mm/h with Marshall-Palmer Z = 200 R^1.6, i.e.
# R = (10^(dBZ/10) / 200)^(1/1.6). RATE (2 km, 15 min) is used as published. In both, "undetect" (-8888000) means
# radar looked and saw nothing (0 mm/h); "nodata" (-9999000) means unknown and is dropped from every score.
import datetime as dt, json, os, re, sys, time, urllib.error, urllib.parse, urllib.request
import numpy as np

KNMI = "https://api.dataplatform.knmi.nl/open-data/v1/datasets/nl_rdr_data_rtcor_5m/versions/1.0"
STORE = "https://object-store.os-api.cci1.ecmwf.int/openradar-24h-backup"
WET = 0.1                                   # mm/h
UNDETECT, NODATA = -8888000.0, -9999000.0
RAIN_SHARE = 0.002                          # a time is "rainy" when 0.2% of KNMI's valid cells are wet (the last 24 h never passed 2.2%)
UTC = dt.timezone.utc

def stamp(t): return t.strftime("%Y%m%d%H%M")
def opera_url(t, prod): return f"{STORE}/{t:%Y/%m/%d}/OPERA/COMP/OPERA@{t:%Y%m%dT%H%M}@0@{prod}.h5"

# ---------------------------------------------------------------- downloads
_rl = {"remaining": 1000, "reset": 0}
def knmi_api(path):
    for attempt in range(6):
        req = urllib.request.Request(f"{KNMI}/{path}", headers={"Authorization": os.environ["KNMI_API_KEY"]})
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                _rl["remaining"] = int(r.headers.get("x-ratelimit-remaining", _rl["remaining"])); _rl["reset"] = int(r.headers.get("x-ratelimit-reset", 0))
                return json.loads(r.read())
        except urllib.error.HTTPError as e:
            if e.code == 429: time.sleep(max(5, _rl["reset"] - time.time() + 2)); continue
            if e.code >= 500: time.sleep(5 * (attempt + 1)); continue
            raise
        except (urllib.error.URLError, TimeoutError, ConnectionError): time.sleep(5 * (attempt + 1))
    raise RuntimeError("KNMI API kept failing")

def knmi_file(work, t):
    """Local path of KNMI's observed rainfall file ending at t, or None if KNMI has none."""
    path = os.path.join(work, "knmi", f"RAD_NL25_RAC_RT_{stamp(t)}.h5")
    if os.path.exists(path): return path
    if _rl["remaining"] < 40: time.sleep(max(0, _rl["reset"] - time.time()) + 3); _rl["remaining"] = 1000   # 1,000 requests an hour
    try: info = knmi_api(f"files/{os.path.basename(path)}/url")
    except urllib.error.HTTPError as e:
        if e.code in (400, 404): return None
        raise
    os.makedirs(os.path.dirname(path), exist_ok=True)
    for attempt in range(4):
        try: urllib.request.urlretrieve(info["temporaryDownloadUrl"], path); return path
        except (urllib.error.URLError, TimeoutError, ConnectionError): time.sleep(5 * (attempt + 1))
    raise RuntimeError("KNMI download kept failing")

def opera_file(work, t, prod):
    path = os.path.join(work, "opera", f"{stamp(t)}_{prod}.h5")
    if os.path.exists(path): return path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    for attempt in range(4):
        try: urllib.request.urlretrieve(opera_url(t, prod), path); return path
        except urllib.error.HTTPError as e:
            if e.code == 404: return None
            time.sleep(3)
        except (urllib.error.URLError, TimeoutError, ConnectionError): time.sleep(3 * (attempt + 1))
    return None

# ---------------------------------------------------------------- readers
def read_knmi(path):
    """mm/h on KNMI's 765 x 700 grid; NaN where KNMI has no data or is outside the picture."""
    import h5py
    a = h5py.File(path, "r")["image1/image_data"][()].astype("float64")
    a[a >= 65534] = np.nan
    return a * 0.01 * 12

def read_opera(path):
    """(values, nodata mask, undetect mask, node list). Values still in file units (mm/h for RATE, dBZ for DBZH)."""
    import h5py
    f = h5py.File(path, "r"); d = f["dataset1/data1/data"][()]
    nodes = f["how"].attrs.get("nodes", b"")
    nodes = nodes.decode() if isinstance(nodes, bytes) else str(nodes)
    return d, d == NODATA, d == UNDETECT, re.findall(r"'(\w+)'", nodes)

def marshall_palmer(dbz):
    return (10.0 ** (dbz / 10.0) / 200.0) ** (1 / 1.6)

# ---------------------------------------------------------------- geometry
class Geo:
    """KNMI cell centres mapped to OPERA cells, plus groupings (coast, range from radar, nearest radar)."""
    def __init__(self, knmi_path, opera_dbzh_path):
        import h5py
        from pyproj import Proj
        from scipy import ndimage
        from global_land_mask import globe
        f = h5py.File(knmi_path, "r"); kp = Proj(f["geographic/map_projection"].attrs["projection_proj4_params"].decode())
        R, C = np.mgrid[0:765, 0:700]
        self.lon, self.lat = kp(C + 0.5, -(R + 0.5 + 3650), inverse=True)
        o = h5py.File(opera_dbzh_path, "r")["where"].attrs; proj = o["projdef"]
        op = Proj(proj.decode() if isinstance(proj, bytes) else proj)
        x, y = op(self.lon, self.lat)                       # metres; the grid's upper-left corner is (0, 0)
        self.c1 = np.floor(x / 1000).astype(int); self.r1 = np.floor(-y / 1000).astype(int)
        self.inside = (self.c1 >= 0) & (self.c1 < 3800) & (self.r1 >= 0) & (self.r1 < 4400)
        self.c1c, self.r1c = np.clip(self.c1, 0, 3799), np.clip(self.r1, 0, 4399)
        self.c2c, self.r2c = self.c1c // 2, self.r1c // 2    # the 2 km grid shares the 1 km grid's corner
        self.block = self.r2c * 1900 + self.c2c
        self.radars = []                                     # (name, lat, lon) of the radars KNMI lists in the file
        for k in sorted(f):
            if k.startswith("radar"):
                a = f[k].attrs; nm = a["radar_name"]; nm = nm.decode() if isinstance(nm, bytes) else str(nm)
                if int(a["radar_operational"][0]): self.radars.append((nm, float(a["radar_location"][1]), float(a["radar_location"][0])))
        # the stored radar_location is (lon, lat) in KNMI files; sanity-check against the Netherlands
        if not all(45 < la < 58 for _, la, _ in self.radars): self.radars = [(n, lo, la) for n, la, lo in self.radars]
        # groupings: name -> (integer labels with -1 = excluded, label names)
        land = globe.is_land(self.lat, self.lon)
        d_land = ndimage.distance_transform_edt(land)        # km from a land cell to the nearest water cell
        d_water = ndimage.distance_transform_edt(~land)      # km from a water cell to the nearest land cell
        coast = np.full(land.shape, 0)
        coast[~land & (d_water > 10)] = 0; coast[~land & (d_water <= 10)] = 1; coast[land & (d_land <= 10)] = 2; coast[land & (d_land > 10)] = 3
        self.groups = {"coast": (coast, ["water more than 10 km from land", "water within 10 km of land", "land within 10 km of water", "land more than 10 km from water"])}
        xr = np.array([kp(lo, la) for _, la, lo in self.radars])      # radar positions in KNMI km
        cx, cy = C + 0.5, -(R + 0.5 + 3650)
        dist = np.stack([np.hypot(cx - px, cy - py) for px, py in xr])
        self.dist_radar = dist.min(0)
        self.region = self.dist_radar <= 100               # "both cover": within 100 km of a radar KNMI lists as operational
        self.groups["nearest radar"] = (dist.argmin(0), [n for n, _, _ in self.radars])
        rng = np.digitize(self.dist_radar, [50, 100, 150, 200, 250])
        self.groups["distance to nearest KNMI radar"] = (rng, ["0-50 km", "50-100 km", "100-150 km", "150-200 km", "200-250 km", "over 250 km"])
        self.ndimage = ndimage

# ---------------------------------------------------------------- scoring
STATS = ["n_valid", "sumK", "sumP", "hits", "misses", "false_alarms", "n_both_wet", "sumK_bw", "sumP_bw", "sumlog_bw"]
def stats_by(labels, nlab, K, P, valid, thr=WET):
    """Per-label sums for the STATS columns. K, P in mm/h, valid = both finite."""
    wk, wp = (K >= thr) & valid, (P >= thr) & valid
    bw = wk & wp
    ok = valid & (labels >= 0)
    lab = labels[ok]
    def b(w): return np.bincount(lab, weights=w, minlength=nlab)
    Kv, Pv = K[ok], P[ok]
    out = np.stack([b(np.ones(lab.size)), b(Kv), b(Pv), b(bw[ok].astype(float)), b((wk & ~wp)[ok].astype(float)), b((wp & ~wk)[ok].astype(float)),
                    b(bw[ok].astype(float)), b(np.where(bw[ok], Kv, 0.0)), b(np.where(bw[ok], Pv, 0.0)),
                    b(np.where(bw[ok], np.log10(np.maximum(Pv, 1e-6) / np.maximum(Kv, 1e-6)), 0.0))], axis=1)
    return out

def csi(h, m, f): return h / (h + m + f) if h + m + f else float("nan")

def summarise(arr):
    """Dict of readable numbers from one row of pooled STATS."""
    n, sK, sP, h, m, f, nbw, sKb, sPb, slg = arr
    return {"cells": int(n), "hits": int(h), "misses": int(m), "false_alarms": int(f), "csi": csi(h, m, f),
            "pod": h / (h + m) if h + m else float("nan"), "far": f / (h + f) if h + f else float("nan"),
            "wet_cells_opera_over_knmi": (h + f) / (h + m) if h + m else float("nan"),
            "mean_ratio_both_wet": sPb / sKb if sKb else float("nan"),
            "median_free_log_bias_db": 10 * slg / nbw if nbw else float("nan"),
            "rain_volume_ratio": sP / sK if sK else float("nan")}

INT_BINS = [0.1, 0.5, 1, 2, 5, 10, 20, 50]
INT_NAMES = ["KNMI 0.1-0.5 mm/h", "0.5-1", "1-2", "2-5", "5-10", "10-20", "20-50", "over 50"]
def intensity_labels(K, valid):
    lab = np.digitize(np.where(valid, K, 0), INT_BINS) - 1      # -1 below 0.1 mm/h
    return np.where(valid, lab, -1)

# ---------------------------------------------------------------- commands
def window(work):
    """15-minute times in KNMI's last 24 hours (latest file listed minus 24 h)."""
    d = knmi_api("files?maxKeys=1&orderBy=created&sorting=desc")["files"][0]["filename"]
    end = dt.datetime.strptime(d[-15:-3], "%Y%m%d%H%M").replace(tzinfo=UTC)
    first = (end - dt.timedelta(hours=24)); first += dt.timedelta(minutes=(-first.minute) % 15)
    ts = []; t = first
    while t <= end: ts.append(t); t += dt.timedelta(minutes=15)
    return ts

def cmd_scan(work):
    out = {}
    for t in window(work):
        p = knmi_file(work, t)
        if p is None: out[stamp(t)] = None; print(stamp(t), "no KNMI file"); continue
        K = read_knmi(p); v = ~np.isnan(K)
        out[stamp(t)] = {"valid": int(v.sum()), "wet_share": float((K[v] >= WET).mean()), "max": float(np.nanmax(K)), "wet_cells": int((K[v] >= WET).sum())}
        print(stamp(t), out[stamp(t)], flush=True)
    json.dump(out, open(os.path.join(work, "scan.json"), "w"), indent=1)

def cmd_compare(work):
    from scipy import ndimage
    scan = json.load(open(os.path.join(work, "scan.json")))
    rainy = sorted(s for s, v in scan.items() if v and v["wet_share"] >= RAIN_SHARE)
    dry = sorted(s for s, v in scan.items() if v and v["wet_cells"] == 0)[::8]       # a dry time every two hours, for false alarms
    print(len(rainy), "rainy 15-minute times and", len(dry), "dry ones, of", len(scan)); sys.stdout.flush()
    todo = [(s, "") for s in rainy] + [(s, "@dry") for s in dry]
    geo = None; pooled = {}; per_time = []; hist = {k: np.zeros(104) for k in ("k_wet", "k_dry")}; undet = {"k_wet": 0, "k_dry": 0}
    offs = {}; nodes_seen = {}; blobs = {}
    def pool(key, arr):
        pooled[key] = pooled.get(key, 0) + arr
    for s, tag in todo:
        t = dt.datetime.strptime(s, "%Y%m%d%H%M").replace(tzinfo=UTC)
        pr, pd_ = opera_file(work, t, "RATE"), opera_file(work, t, "DBZH")
        if geo is None and pd_: geo = Geo(knmi_file(work, t), pd_)
        Kp = {o: knmi_file(work, t + dt.timedelta(minutes=o)) for o in (-5, 0, 5)}
        if geo is None or Kp[0] is None: continue
        Ks = {o: read_knmi(p) for o, p in Kp.items() if p}
        reg = geo.region                                                    # within 100 km of an operational KNMI radar
        rec = {"time": s + tag, "knmi_wet_share": scan[s]["wet_share"]}
        products = {}
        if pr:
            d, nod, und, nodes = read_opera(pr); nodes_seen[s + "_RATE"] = nodes
            P = np.where(nod, np.nan, np.where(und, 0.0, d))
            products["RATE"] = P[geo.r2c, geo.c2c]
            Kb = Ks[0]; okb = ~np.isnan(Kb) & geo.inside                    # like-for-like at 2 km: KNMI averaged inside each OPERA cell
            cnt = np.bincount(geo.block[okb], minlength=2200 * 1900); sm = np.bincount(geo.block[okb], weights=Kb[okb], minlength=2200 * 1900)
            with np.errstate(invalid="ignore", divide="ignore"): K2 = np.where(cnt >= 3, sm / cnt, np.nan)
            reg2 = np.zeros(2200 * 1900, bool); reg2[geo.block[geo.region & okb]] = True
            Pf = P.ravel(); v2 = np.isfinite(K2) & np.isfinite(Pf) & reg2
            pool(("RATE_2km_block" + tag, "within 100 km"), stats_by(np.zeros(Pf.size, int), 1, K2, Pf, v2))
            rec["RATE_nodata_share_100km"] = float(np.isnan(products["RATE"][reg & geo.inside & ~np.isnan(Ks[0])]).mean())
        if pd_:
            d, nod, und, nodes = read_opera(pd_); nodes_seen[s + "_DBZH"] = nodes
            Z = np.where(nod, np.nan, np.where(und, -np.inf, d))
            R = marshall_palmer(np.where(np.isfinite(Z), Z, -999)); R = np.where(np.isnan(Z), np.nan, np.where(np.isinf(Z), 0.0, R))
            products["DBZH_MP"] = R[geo.r1c, geo.c1c]
            dz = Z[geo.r1c, geo.c1c]
            ok = reg & geo.inside & ~np.isnan(Ks[0]) & ~np.isnan(dz)
            fin = ok & np.isfinite(dz); kw = Ks[0] >= WET
            if not tag:
                idx = np.clip(np.floor(dz[fin] + 33).astype(int), 0, 103)
                np.add.at(hist["k_wet"], idx[kw[fin]], 1); np.add.at(hist["k_dry"], idx[~kw[fin]], 1)
                u = ok & np.isneginf(dz); undet["k_wet"] += int((u & kw).sum()); undet["k_dry"] += int((u & ~kw).sum())
            rec["DBZH_nodata_share_100km"] = float(np.isnan(products["DBZH_MP"][reg & geo.inside & ~np.isnan(Ks[0])]).mean())
        for name, P in products.items():
            for o, K in Ks.items():
                v = ~np.isnan(K) & ~np.isnan(P) & geo.inside
                a = stats_by(np.zeros(K.shape, int), 1, K, P, v & reg)
                offs[(name + tag, o)] = offs.get((name + tag, o), 0) + a
                if o: continue
                pool((name + tag, "within 100 km"), a)
                pool((name + tag, "whole KNMI picture"), stats_by(np.zeros(K.shape, int), 1, K, P, v))
                pool((name + tag, "within 100 km, wet = 1 mm/h"), stats_by(np.zeros(K.shape, int), 1, K, P, v & reg, thr=1.0))
                rec[name + "_csi_100km"] = csi(a[0, 3], a[0, 4], a[0, 5]); rec[name + "_cells_100km"] = int(a[0, 0])
                vr = v & reg
                for g, (lab, names) in geo.groups.items(): pool((name + tag, g), stats_by(lab, len(names), K, P, vr))
                pool((name + tag, "KNMI intensity"), stats_by(intensity_labels(K, vr), len(INT_NAMES), K, P, vr))
                if not tag:         # does OPERA see each KNMI rain area at all? (areas of connected wet cells, by size and peak rate)
                    lab, n = ndimage.label((np.nan_to_num(K) >= WET) & vr)
                    if n:
                        idx = np.arange(1, n + 1); size = ndimage.sum(np.ones(K.shape), lab, idx); peak = ndimage.maximum(np.nan_to_num(K), lab, idx)
                        hit = ndimage.maximum(np.where(np.isnan(P), 0, P) >= WET, lab, idx) > 0
                        for sz, pk, h in zip(size, peak, hit):
                            key = (name, int(np.digitize(sz, [4, 16, 64])), int(np.digitize(pk, [0.5, 1, 2])))
                            c = blobs.setdefault(key, [0, 0]); c[0] += 1; c[1] += int(h)
        per_time.append(rec); print(rec, flush=True)
        for p in (pr, pd_):
            if p and os.path.exists(p): os.remove(p)
    summary = {"times": len(per_time), "per_time": per_time, "pooled": {}, "offsets": {}, "dbzh_hist_within_100km": {k: v.tolist() for k, v in hist.items()}, "dbzh_undetect_within_100km": undet}
    for (name, g), arr in pooled.items():
        names = ({"KNMI intensity": INT_NAMES}.get(g) or (geo.groups[g][1] if g in geo.groups else ["all"]))
        summary["pooled"].setdefault(name, {})[g] = {names[i]: summarise(arr[i]) for i in range(arr.shape[0])}
    for (name, o), arr in offs.items(): summary["offsets"].setdefault(name, {})[str(o)] = summarise(arr[0])
    sz_names = ["1-3 km2", "4-15 km2", "16-63 km2", "64+ km2"]; pk_names = ["peak 0.1-0.5 mm/h", "0.5-1", "1-2", "2+"]
    summary["rain_areas"] = {f"{n} | {sz_names[a]} | {pk_names[b]}": {"areas": c[0], "detected": c[1]} for (n, a, b), c in sorted(blobs.items())}
    summary["nodes_per_time"] = nodes_seen
    json.dump(summary, open(os.path.join(work, "result.json"), "w"), indent=1, default=float)
    print("done")

def cmd_figure(work, s, out):
    """KNMI, OPERA RATE and OPERA DBZH (Marshall-Palmer) side by side on KNMI's grid at one time, Netherlands and Belgium crop."""
    import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
    from global_land_mask import globe
    t = dt.datetime.strptime(s, "%Y%m%d%H%M").replace(tzinfo=UTC)
    kp, pr, pd_ = knmi_file(work, t), opera_file(work, t, "RATE"), opera_file(work, t, "DBZH")
    geo = Geo(kp, pd_); K = read_knmi(kp)
    r, rn, ru, _ = read_opera(pr); d, dn, du, _ = read_opera(pd_)
    R = np.where(rn, np.nan, np.where(ru, 0.0, r))[geo.r2c, geo.c2c]
    Z = np.where(dn, np.nan, np.where(du, -np.inf, d)); M = np.where(np.isnan(Z), np.nan, np.where(np.isinf(Z), 0.0, marshall_palmer(np.where(np.isfinite(Z), Z, -99))))[geo.r1c, geo.c1c]
    sl = (slice(120, 560), slice(100, 560)); land = globe.is_land(geo.lat, geo.lon)
    fig, ax = plt.subplots(1, 3, figsize=(15, 5.6))
    for a, f, title in zip(ax, (K, R, M), ("KNMI observed (reference)", "OPERA RATE", "OPERA DBZH as mm/h (Marshall-Palmer)")):
        im = a.imshow(np.clip(f[sl], 0, 2), vmin=0, vmax=2, cmap="turbo"); a.set_title(title); a.set_xticks([]); a.set_yticks([])
        a.contour(land[sl].astype(float), levels=[0.5], colors="w", linewidths=0.6)
    fig.colorbar(im, ax=ax, shrink=0.8, label="mm/h (clipped at 2)"); fig.suptitle(f"{t:%d %b %Y %H:%M} UTC, 1 km KNMI grid")
    fig.savefig(out, dpi=70)

def cmd_store():
    """Missing and late OPERA files for each UTC day in the backup store (listing only, no downloads)."""
    ns = {"s": "http://s3.amazonaws.com/doc/2006-03-01/"}
    import xml.etree.ElementTree as ET
    now = dt.datetime.now(UTC); rows = {}
    for day in sorted({(now - dt.timedelta(days=i)).date() for i in (0, 1)}):
        token = None
        while True:
            url = f"{STORE}?list-type=2&prefix={day:%Y/%m/%d}/OPERA/COMP/&max-keys=1000" + (f"&continuation-token={urllib.parse.quote(token)}" if token else "")
            root = ET.fromstring(urllib.request.urlopen(url, timeout=60).read())
            for c in root.findall("s:Contents", ns):
                k = c.find("s:Key", ns).text; m = re.search(r"@(\d{8}T\d{4})@0@(\w+)\.h5$", k)
                if m: rows[(m.group(2), m.group(1))] = (dt.datetime.strptime(c.find("s:LastModified", ns).text[:19], "%Y-%m-%dT%H:%M:%S").replace(tzinfo=UTC), int(c.find("s:Size", ns).text))
            t = root.find("s:NextContinuationToken", ns); token = t.text if t is not None else None
            if token is None: break
    out = {}
    for prod, step in (("DBZH", 5), ("RATE", 15)):
        for day in sorted({(now - dt.timedelta(days=i)).date() for i in (0, 1)}):
            t = dt.datetime.combine(day, dt.time(), UTC); last = min(t + dt.timedelta(days=1), now - dt.timedelta(minutes=30 if prod == "RATE" else 15))
            expected, missing, delays, sizes = 0, [], [], []
            while t < last:
                expected += 1; key = (prod, t.strftime("%Y%m%dT%H%M"))
                if key in rows: delays.append((rows[key][0] - t).total_seconds() / 60); sizes.append(rows[key][1])
                else: missing.append(t.strftime("%H:%M"))
                t += dt.timedelta(minutes=step)
            d = np.array(delays)
            late_lim = (7, 10) if prod == "DBZH" else (12, 15)
            out[f"{prod} {day}"] = {"expected": expected, "present": len(delays), "missing": len(missing), "missing_times_utc": missing,
                                    "delay_min_median": float(np.median(d)), "delay_min_p95": float(np.percentile(d, 95)), "delay_min_max": float(d.max()),
                                    f"later_than_{late_lim[0]}_min": int((d > late_lim[0]).sum()), f"later_than_{late_lim[1]}_min": int((d > late_lim[1]).sum()),
                                    "size_min": min(sizes), "size_max": max(sizes), "small_files_under_60pct_median": int((np.array(sizes) < 0.6 * np.median(sizes)).sum())}
    print(json.dumps(out, indent=1))

if __name__ == "__main__":
    if sys.argv[1] == "store": cmd_store()
    elif sys.argv[1] == "scan": cmd_scan(sys.argv[2])
    elif sys.argv[1] == "compare": cmd_compare(sys.argv[2])
    elif sys.argv[1] == "figure": cmd_figure(sys.argv[2], sys.argv[3], sys.argv[4])
    else: sys.exit(__doc__)

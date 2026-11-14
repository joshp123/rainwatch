#!/usr/bin/env python3
# Written by AI on 2026.11.14 by model claude sonnet 5.5, for research/verification/season.md.
# Season-long comparison of KNMI's plain radar forecast (radar_forecast 2.0) and KNMI's blended ensemble
# (seamless_precipitation_ensemble_forecast_members 1.0), scored at the 48 Dutch places in research/live-data
# (north of 51.6 N) against observed 5-minute radar rainfall (nl_rdr_data_rtcor_5m_tar 1.0), wet = 0.1 mm/h.
#
#   KNMI_API_KEY=... [EXTRA_CASES=20] python -I season.py collect WORKDIR   # download, score, delete; resumable
#   python -I season.py merge WORKDIR season_cells.csv.gz                   # one file for all cases (+ season_cases.json)
#   python -I season_analyse.py season_cells.csv.gz season_cases.json       # tables and confidence intervals -> stdout
# Needs numpy, h5py, netCDF4, pyproj. EXTRA_CASES adds days from the newest blend file layout (30 Aug 2026 on).
#
# collect picks, month by month, random days from the observed archive. A day qualifies when some 2-hour
# window (issue times on the half hour) has at least 5% of its 48 places x 24 lead times wet. One random
# qualifying issue time is taken per day. Each case's files are deleted once scored.
import csv, datetime as dt, glob, io, json, os, random, shutil, sys, tarfile, time, urllib.error, urllib.parse, urllib.request
import numpy as np

LIVE = os.path.expanduser("~/code/buienradar-apple-watch/research/live-data")
BASE = "https://api.dataplatform.knmi.nl/open-data/v1/datasets"
LEADS = list(range(5, 125, 5))
WET = 0.1                       # mm/h
QUALIFY = 0.05                  # share of place-lead cells that must be wet in a window
EXCLUDE_DAYS = {"20261113"}     # the single case already studied in radar-sota.md
SUMMER = {6, 7, 8}
FIRST_DAY = dt.date(2025, 4, 9)  # first day the blend archive covers whole days

def places():
    out = []
    for p in sorted(glob.glob(f"{LIVE}/NL_*.json")):
        _, lat, lon = os.path.basename(p)[:-5].split("_")
        if float(lat) >= 51.6: out.append((float(lat), float(lon)))
    return out

# ---------------------------------------------------------------- KNMI Open Data API
_rl = {"remaining": 1000, "reset": 0}
def _call(url, headers):
    for attempt in range(6):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=120) as r:
                if r.headers.get("x-ratelimit-remaining") is not None:
                    _rl["remaining"] = int(r.headers["x-ratelimit-remaining"]); _rl["reset"] = int(r.headers.get("x-ratelimit-reset", 0))
                return json.loads(r.read())
        except urllib.error.HTTPError as e:
            if e.code == 429: time.sleep(max(5, _rl["reset"] - time.time() + 2)); continue
            if e.code >= 500: time.sleep(5 * (attempt + 1)); continue
            raise
        except (urllib.error.URLError, TimeoutError, ConnectionError):
            time.sleep(5 * (attempt + 1))
    raise RuntimeError("API call kept failing: " + url.split("?")[0])
def api(path):
    if _rl["remaining"] < 30:  # stay well under the 1,000 requests an hour
        time.sleep(max(0, _rl["reset"] - time.time()) + 3); _rl["remaining"] = 1000
    return _call(f"{BASE}/{path}", {"Authorization": os.environ["KNMI_API_KEY"]})
def fetch(dataset, version, filename, dest):
    try: info = api(f"{dataset}/versions/{version}/files/{urllib.parse.quote(filename)}/url")
    except urllib.error.HTTPError as e:
        if e.code in (400, 404): return False
        raise
    for attempt in range(4):
        try: urllib.request.urlretrieve(info["temporaryDownloadUrl"], dest); return True
        except (urllib.error.URLError, TimeoutError, ConnectionError): time.sleep(5 * (attempt + 1))
    raise RuntimeError("download kept failing: " + filename)
def list_tars():
    """{start day 'YYYYMMDD': filename} for the daily tars of observed 5-minute radar (08:05 UTC to 08:00 UTC next day)."""
    days, after = {}, "RAD25_OPER_R___TARRRT__L2__20250405"
    while True:
        d = api(f"nl_rdr_data_rtcor_5m_tar/versions/1.0/files?maxKeys=1000&startAfterFilename={after}")
        for f in d["files"]: days[f["filename"].split("__L2__")[1][:8]] = f["filename"]
        if not d["isTruncated"] or not d["files"]: return days
        after = d["files"][-1]["filename"]

# ---------------------------------------------------------------- readers
def mmh(a):
    a = a.astype("float64"); a[a >= 65534] = np.nan; return a * 0.01 * 12

class Grid:
    """Maps a place to its cell in KNMI's 765 x 700 radar grid (same grid for observations and the plain forecast)."""
    def __init__(self, h5file):
        from pyproj import Proj
        self.proj = Proj(h5file["geographic/map_projection"].attrs["projection_proj4_params"].decode())
        g = h5file["geographic"].attrs; self.co, self.ro = float(g["geo_column_offset"][0]), float(g["geo_row_offset"][0])
    def cell(self, lat, lon):
        x, y = self.proj(lon, lat); return int(round(-y - self.ro)), int(round(x - self.co))

def read_day(tar_path, pl):
    """All 288 observed frames of one tar: values at the places, and wet share / maximum over the Dutch box."""
    import h5py
    t = tarfile.open(tar_path); times, vals, wetshare, mx = [], [], [], []
    names = sorted(n for n in t.getnames() if n.endswith(".h5"))
    grid = box = None
    for n in names:
        f = h5py.File(io.BytesIO(t.extractfile(n).read()), "r")
        if grid is None:
            grid = Grid(f); cells = [grid.cell(la, lo) for la, lo in pl]
            rs, cs = [c[0] for c in cells], [c[1] for c in cells]; box = (min(rs) - 10, max(rs) + 10, min(cs) - 10, max(cs) + 10)
        a = mmh(f["image1/image_data"][()]); b = a[box[0]:box[1], box[2]:box[3]]; ok = ~np.isnan(b)
        times.append(dt.datetime.strptime(n[-15:-3], "%Y%m%d%H%M")); vals.append(np.array([a[r, c] for r, c in cells]))
        wetshare.append(float((b[ok] >= WET).mean()) if ok.any() else np.nan); mx.append(float(np.nanmax(b)) if ok.any() else np.nan)
    return grid, cells, times, np.array(vals), np.array(wetshare), np.array(mx)

def read_blend(path, pl):
    """(places, 20 members, 24 leads) in mm/h. Handles both file layouts KNMI has used (radar grid, then lat/lon grid)."""
    import netCDF4
    b = netCDF4.Dataset(path); lat, lon = b["lat"][:], b["lon"][:]; out = np.full((len(pl), 20, len(LEADS)), np.nan, dtype="float32")
    assert list(b["time"][:len(LEADS)]) == [L * 60 for L in LEADS], "unexpected blend time axis"
    ij = []
    for la, lo in pl:
        if lat.ndim == 1: ij.append((int(np.abs(lat - la).argmin()), int(np.abs(lon - lo).argmin())))
        else: ij.append(tuple(int(v) for v in np.unravel_index((((lat - la) ** 2) + ((lon - lo) * np.cos(np.radians(la))) ** 2).argmin(), lat.shape)))
    ii, jj = np.array([c[0] for c in ij]), np.array([c[1] for c in ij])
    i0, i1, j0, j1 = ii.min(), ii.max() + 1, jj.min(), jj.max() + 1
    for m in range(20):
        block = np.ma.filled(b["precip_intensity"][m, :len(LEADS), i0:i1, j0:j1], np.nan)
        out[:, m, :] = block[:, ii - i0, jj - j0].T
    b.close(); return out

def read_det(path, grid, cells):
    import h5py
    f = h5py.File(path, "r"); assert f["image1"].attrs["image_datetime_valid"].decode()[:11] != ""
    return np.array([[mmh(f[f"image{L//5 + 1}/image_data"][()])[r, c] for L in LEADS] for r, c in cells])

# ---------------------------------------------------------------- collect
def case_csv(out, key):
    return os.path.join(out, "cases", f"{key}.csv")

def collect(work, quota_summer=4, quota_other=3, only=None, extra=0):
    pl = places(); out = os.path.join(work, "out"); tmp = os.path.join(work, "tmp")
    os.makedirs(os.path.join(out, "cases"), exist_ok=True); os.makedirs(tmp, exist_ok=True)
    statef = os.path.join(out, "state.json"); state = json.load(open(statef)) if os.path.exists(statef) else {}
    tars = list_tars()
    months = {}
    for day in sorted(tars):
        d = dt.datetime.strptime(day, "%Y%m%d").date()
        if d >= FIRST_DAY and day not in EXCLUDE_DAYS and day in tars and d <= dt.date(2026, 11, 12): months.setdefault(day[:6], []).append(day)
    for month, days in sorted(months.items()):
        quota = quota_summer if int(month[4:]) in SUMMER else quota_other
        random.Random(month).shuffle(days)
        for day in days:
            have = sum(1 for v in state.values() if v.get("month") == month and v["status"] == "scored" and not v.get("extra"))
            if have >= quota: break
            if day in state: continue
            if only and day not in only: continue
            state[day] = {"month": month, **process_day(day, tars[day], pl, tmp, out)}
            json.dump(state, open(statef, "w"), indent=1)
            print(day, state[day]["status"], state[day].get("issue", ""), f"remaining requests {_rl['remaining']}", flush=True)
    # extra cases from the newest blend file layout (issued from 30 Aug 2026), kept out of the seasonal sample
    recent = sorted(d for d in tars if "20260830" <= d <= "20261112" and d not in EXCLUDE_DAYS and d not in state)
    random.Random("recent").shuffle(recent)
    for day in recent:
        if sum(1 for v in state.values() if v.get("extra") and v["status"] == "scored") >= extra: break
        state[day] = {"month": day[:6], "extra": True, **process_day(day, tars[day], pl, tmp, out)}
        json.dump(state, open(statef, "w"), indent=1)
        print(day, "extra", state[day]["status"], state[day].get("issue", ""), f"remaining requests {_rl['remaining']}", flush=True)
    shutil.rmtree(tmp, ignore_errors=True)

def process_day(day, tarname, pl, tmp, out):
    tp = os.path.join(tmp, "day.tar"); dp, bp = os.path.join(tmp, "det.h5"), os.path.join(tmp, "blend.nc")
    try:
        if not fetch("nl_rdr_data_rtcor_5m_tar", "1.0", tarname, tp): return {"status": "no tar"}
        grid, cells, times, vals, wetshare, mx = read_day(tp, pl); idx = {t: k for k, t in enumerate(times)}
        cands = []
        for t in times:
            if t.minute % 30 or t + dt.timedelta(minutes=120) not in idx: continue
            k = idx[t]; w = vals[k + 1:k + 25]
            if np.nansum(w >= WET) >= QUALIFY * w.size: cands.append(t)
        random.Random(day).shuffle(cands)
        for t in cands[:3]:
            k = idx[t]; stamp = t.strftime("%Y%m%d%H%M")
            ok1 = fetch("radar_forecast", "2.0", f"RAD_NL25_RAC_FM_{stamp}.h5", dp)
            ok2 = ok1 and fetch("seamless_precipitation_ensemble_forecast_members", "1.0", f"KNMI_PYSTEPS_BLEND_ENS_{stamp}.nc", bp)
            if not ok2: continue
            det = read_det(dp, grid, cells); blend = read_blend(bp, pl)
            obs = vals[k + 1:k + 25].T; pers = np.repeat(vals[k][:, None], len(LEADS), axis=1)
            w = slice(k, k + 25)
            with open(case_csv(out, f"{day}_{stamp}"), "w", newline="") as fh:
                wr = csv.writer(fh); wr.writerow(["day", "issue", "lat", "lon", "lead", "obs", "pers", "det", "nwet", "bmean", "bmed"])
                for p, (la, lo) in enumerate(pl):
                    for li, L in enumerate(LEADS):
                        m = blend[p, :, li]
                        wr.writerow([day, stamp, la, lo, L, obs[p, li], pers[p, li], det[p, li], int(np.sum(m >= WET)), float(np.nanmean(m)), float(np.nanmedian(m))])
            case = {"issue": stamp, "wet_cells": int(np.nansum(obs >= WET)), "place_wet_share": float(np.nanmean(obs >= WET)),
                    "box_wet_share": float(np.nanmean(wetshare[w])), "box_max_mmh": float(np.nanmax(mx[w])), "n_candidates": len(cands)}
            return {"status": "scored", **case}
        return {"status": "no qualifying window" if not cands else "forecast files missing", "n_candidates": len(cands)}
    finally:
        for p in (tp, dp, bp):
            if os.path.exists(p): os.remove(p)

def merge(work, dest):
    import gzip
    out = os.path.join(work, "out"); files = sorted(glob.glob(os.path.join(out, "cases", "*.csv")))
    with gzip.open(dest, "wt", newline="") as fh:
        for n, p in enumerate(files):
            lines = open(p).read().splitlines(); fh.write("\n".join(lines if n == 0 else lines[1:]) + "\n")
    cases = json.load(open(os.path.join(out, "state.json")))
    json.dump({d: v for d, v in sorted(cases.items())}, open(dest.replace("cells.csv.gz", "cases.json"), "w"), indent=1)

if __name__ == "__main__":
    cmd, work = sys.argv[1], sys.argv[2]
    if cmd == "collect": collect(work, extra=int(os.environ.get("EXTRA_CASES", "0")))
    elif cmd == "merge": merge(work, sys.argv[3])
    else: sys.exit("usage: season.py collect WORKDIR | merge WORKDIR OUT.csv.gz")

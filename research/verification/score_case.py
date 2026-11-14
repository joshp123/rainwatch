# Written by AI on 2026.11.14 by model claude opus 5.5. Run from a folder holding det.h5, blend.nc and obs/ (see research/radar-sota.md).
# Scores four 2-hour rain forecasts issued 13 Nov 2026 12:30 UTC against KNMI's observed 5-minute
# radar rainfall at the Dutch grid places in research/live-data (north of 51.6 N), wet = 0.1 mm/h.
import glob, json, os, h5py, numpy as np, netCDF4
from pyproj import Proj
LIVE = os.path.expanduser("~/code/buienradar-apple-watch/research/live-data")
places = []
for p in glob.glob(f"{LIVE}/NL_*.json"):
    _, lat, lon = os.path.basename(p)[:-5].split("_")
    if float(lat) >= 51.6: places.append((float(lat), float(lon), p))
det = h5py.File("det.h5")
proj = Proj(det["geographic/map_projection"].attrs["projection_proj4_params"].decode())
g = det["geographic"].attrs; co, ro = float(g["geo_column_offset"][0]), float(g["geo_row_offset"][0])
def cell(lat, lon):
    x, y = proj(lon, lat); return int(round(-y - ro)), int(round(x - co))
leads = list(range(5, 125, 5))
def knmi_mmh(a): a = a.astype(float); a[a >= 65534] = np.nan; return a * 0.01 * 12
obs = {L: knmi_mmh(h5py.File(f"obs/20261113{12 + (30 + L)//60:02d}{(30 + L) % 60:02d}.h5")["image1/image_data"][()]) for L in leads}
detf = {L: knmi_mmh(det[f"image{L//5 + 1}/image_data"][()]) for L in leads}
b = netCDF4.Dataset("blend.nc"); bt = list(b["time"][:]); blat = b["lat"][:]; blon = b["lon"][:]
bp = b["precip_intensity"]
def bidx(lat, lon): return int(np.abs(blat - lat).argmin()), int(np.abs(blon - lon).argmin())
sources = {"KNMI plain": {}, "KNMI blended, median of 20": {}, "KNMI blended, rain if half agree": {}, "Buienradar": {}}
truth = {}
for lat, lon, path in places:
    r, c = cell(lat, lon); i, j = bidx(lat, lon)
    members = bp[:, :, i, j]  # (20, 72)
    br = {f["utcDateTime"]: f["dataValue"] for f in json.load(open(path))["forecasts"]}
    for L in leads:
        key = (lat, lon, L)
        truth[key] = obs[L][r, c]
        sources["KNMI plain"][key] = detf[L][r, c]
        k = bt.index(L * 60)
        sources["KNMI blended, median of 20"][key] = float(np.median(members[:, k]))
        sources["KNMI blended, rain if half agree"][key] = 1.0 if (members[:, k] >= 0.1).mean() >= 0.5 else 0.0
        t = f"2026-11-13T{12 + (30 + L)//60:02d}:{(30 + L) % 60:02d}:00"
        sources["Buienradar"][key] = br.get(t, np.nan)
def score(src, band):
    h = m = f = 0
    for key, o in truth.items():
        if not (band[0] <= key[2] <= band[1]) or np.isnan(o) or np.isnan(src[key]): continue
        ow, fw = o >= 0.1, src[key] >= 0.1
        h += ow and fw; m += ow and not fw; f += fw and not ow
    csi = h / (h + m + f) if h + m + f else float("nan")
    far = f / (h + f) if h + f else float("nan"); pod = h / (h + m) if h + m else float("nan")
    return csi, pod, far
print(f"{len(places)} places, {len(leads)} lead times; wet steps observed: {sum(1 for v in truth.values() if v >= 0.1)}")
print(f"{'':36s}{'all':>18s}{'5-30 min':>18s}{'35-60 min':>18s}{'65-120 min':>18s}")
for name, src in sources.items():
    row = "".join(f"  {score(src, band)[0]:.2f} {score(src, band)[1]:.2f} {score(src, band)[2]:.2f}" for band in [(5, 120), (5, 30), (35, 60), (65, 120)])
    print(f"{name:36s}{row}")
print("columns: CSI, share of rain caught, share of forecast rain that stayed dry")

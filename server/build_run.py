# Written by AI on 2026.11.14 by model claude opus 5.5. Prototype of one server run: KNMI's plain
# forecast for the first 30 minutes, its blend (median of 20 versions) from 35 to 120 minutes, as
# one file a watch reads 25 bytes from, plus the radar page's frames. Prints how long each part takes.
# Run: python3 build_run.py plain.h5 blend.nc out/
import sys, time, zlib, os, resource
import h5py, numpy as np, netCDF4
from pyproj import Proj

t0 = time.time(); stamp = {}
plain_path, blend_path, out = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(out, exist_ok=True)

f = h5py.File(plain_path)
rows, cols = f["image1/image_data"].shape
def mmh(a):
    a = a.astype(np.float32); a[a >= 65534] = 0; return a * 0.12   # 0.01 mm per 5 min -> mm/h
plain = np.stack([mmh(f[f"image{k}/image_data"][()]) for k in range(1, 26)])   # 0..120 min
stamp["read plain"] = time.time()

# Where each KNMI 1 km cell falls on the blend's latitude/longitude grid (computed once, cached).
proj = Proj(f["geographic/map_projection"].attrs["projection_proj4_params"].decode())
g = f["geographic"].attrs; co, ro = float(g["geo_column_offset"][0]), float(g["geo_row_offset"][0])
b = netCDF4.Dataset(blend_path); blat = b["lat"][:]; blon = b["lon"][:]
cc, rr = np.meshgrid(np.arange(cols) + 0.5 + co, -(np.arange(rows) + 0.5 + ro))
lon, lat = proj(cc, rr, inverse=True)
bi = np.clip(np.searchsorted(-blat if blat[0] > blat[-1] else blat, -lat if blat[0] > blat[-1] else lat), 0, len(blat) - 1)
bj = np.clip(np.searchsorted(blon, lon), 0, len(blon) - 1)
stamp["map grids"] = time.time()

times = list(b["time"][:]); bp = b["precip_intensity"]
hybrid = plain.copy()
for step in range(7, 25):                      # 35..120 minutes
    k = times.index(step * 300)
    median = np.median(bp[:, k, :, :], axis=0)  # 20 versions -> one field, 780 x 780
    hybrid[step] = median[bi, bj]
stamp["blend 35-120 min"] = time.time()

# Buienradar's byte scale: mm/h = 10^((v - 109) / 32), 0 = dry.
v = np.where(hybrid >= 0.1, np.clip(np.round(109 + 32 * np.log10(np.maximum(hybrid, 1e-3))), 1, 255), 0).astype(np.uint8)
point = np.ascontiguousarray(v.transpose(1, 2, 0))      # a cell's 25 values are adjacent
open(f"{out}/forecast.bin", "wb").write(point.tobytes())
q = np.clip(np.round(np.log2(hybrid + 1) * 4), 0, 15).astype(np.uint8)
frames = [zlib.compress(((fr[:, 0::2] << 4) | fr[:, 1::2]).tobytes(), 6) for fr in q]
open(f"{out}/radar.bin", "wb").write(b"".join(len(x).to_bytes(4, "big") + x for x in frames))
stamp["write files"] = time.time()

prev = t0
for name, t in stamp.items():
    print(f"{name:20s} {t - prev:6.2f} s"); prev = t
print(f"{'total':20s} {prev - t0:6.2f} s; peak memory {resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 2**30:.2f} GB")
print("forecast.bin", os.path.getsize(f"{out}/forecast.bin"), "bytes; radar.bin", os.path.getsize(f"{out}/radar.bin"), "bytes")

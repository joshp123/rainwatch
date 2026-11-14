# Written by AI on 2026.11.14 by model claude fable 5.2. Design experiment: builds one run in the proposed
# format from real KNMI files (6 observed frames, 25 forecast frames, 32 km tiles, one byte per value),
# then reads it back the way a watch would. Run: python3 -I fable-pack-probe.py plain.h5 blend.nc obsdir out
import sys, time, zlib, json, gzip, glob, math, resource
import h5py, numpy as np
t0 = time.perf_counter()
plain_p, blend_p, obs_dir, out = sys.argv[1:5]
A, B = 6378.137, 6356.752; E = math.sqrt(1 - (B / A) ** 2); TS = math.radians(60)
def _t(phi): return np.tan(np.pi / 4 - phi / 2) / ((1 - E * np.sin(phi)) / (1 + E * np.sin(phi))) ** (E / 2)
MC = math.cos(TS) / math.sqrt(1 - E ** 2 * math.sin(TS) ** 2)
def cell(lat, lon):                      # the watch's whole "where am I": 4 lines of arithmetic
    rho = A * MC * _t(np.radians(lat)) / _t(TS)
    return int(math.floor(rho * math.cos(math.radians(lon)) - 3650)), int(math.floor(rho * math.sin(math.radians(lon))))
def lonlat(row, col):                    # inverse, for mapping the blend's lat/lon grid (server only, cacheable)
    x, y = col + 0.5, -(row + 0.5 + 3650); rho = np.hypot(x, y); ts = rho * _t(TS) / (A * MC)
    phi = np.pi / 2 - 2 * np.arctan(ts)
    for _ in range(6): phi = np.pi / 2 - 2 * np.arctan(ts * ((1 - E * np.sin(phi)) / (1 + E * np.sin(phi))) ** (E / 2))
    return np.degrees(np.arctan2(x, -y)), np.degrees(phi)

obs_files = sorted(glob.glob(obs_dir + '/*.h5'))            # 7 files: -30..0 min
obs = np.stack([h5py.File(p)['image1/image_data'][()] for p in obs_files])
outside = obs[-1] == 65535                                  # KNMI's own coverage mask; the forecast file has none
f = h5py.File(plain_p); raw = np.stack([f[f'image{i}/image_data'][()] for i in range(1, 26)])
rate = np.concatenate([obs[:6], raw]).astype(np.float32) * 0.12        # 0.01 mm per 5 min -> mm/h; 31 frames
nodata = np.concatenate([obs[:6] >= 65534, raw >= 65534]) | outside
wet = rate >= 0.1
b = h5py.File(blend_p); bp = b['precip_intensity']; times = list(b['time'][:])
H, W = raw.shape[1:]; rr, cc = np.meshgrid(np.arange(H), np.arange(W), indexing='ij'); lon, lat = lonlat(rr, cc)
blat, blon = b['lat'][:], b['lon'][:]
bi = np.rint((lat - blat[0]) / (blat[1] - blat[0])).astype(int); bj = np.rint((lon - blon[0]) / (blon[1] - blon[0])).astype(int)
inb = (bi >= 0) & (bi < len(blat)) & (bj >= 0) & (bj < len(blon)); bi, bj = np.clip(bi, 0, len(blat) - 1), np.clip(bj, 0, len(blon) - 1)
for step in range(7, 25):                                   # 35..120 min from the blend, where the blend has data
    m = bp[:, times.index(step * 300)]; fill = (m == 65535).any(0)[bi, bj]
    v = m.astype(np.float32) * 0.01
    votes = (v >= 0.1).sum(0)[bi, bj]; med = np.median(v, 0)[bi, bj]
    use = inb & ~fill                                       # elsewhere keep the plain forecast
    k = 6 + step
    wet[k][use] = votes[use] >= 10                          # the season test's rule: wet if half the versions say so
    rate[k][use] = np.maximum(med[use], 0.1)                # a wet cell is never drawn below the wet threshold
# one byte: 0 dry, 255 no data, 1..250 = rain on a log scale from 0.1 mm/h, 50 steps per factor of ten
byte = np.where(wet, np.clip(1 + np.rint(50 * np.log10(np.maximum(rate, 0.1) / 0.1)), 1, 250), 0).astype(np.uint8)
byte[nodata] = 255
t_build = time.perf_counter()
T = 32; rows, cols = -(-H // T), -(-W // T); lengths = []; pack = bytearray(); biggest = 0
for tr in range(rows):
    for tc in range(cols):
        tile = byte[:, tr * T:(tr + 1) * T, tc * T:(tc + 1) * T]
        if not tile.any(): lengths.append(0); continue                 # every value valid and dry
        if (tile == 255).all(): lengths.append(-1); continue           # no radar coverage at all
        z = zlib.compress(np.ascontiguousarray(tile.transpose(1, 2, 0)).tobytes(), 9)   # a cell's 31 values adjacent
        lengths.append(len(z)); pack += z; biggest = max(biggest, len(z))
manifest = {"run": "2026-11-13T12:30Z", "blend": "2026-11-13T12:30Z", "first_frame_min": -30, "frames": 31, "step_min": 5,
            "tile_km": T, "rows": rows, "cols": cols, "pack": "runs/202611131230.bin", "tiles": lengths}
mj = json.dumps(manifest, separators=(',', ':')).encode()
open(out + '/latest.json', 'wb').write(mj); open(out + '/run.bin', 'wb').write(pack)
t_done = time.perf_counter()

# ---- the watch ----
def offsets(m):
    off, o = [], 0
    for n in m["tiles"]: off.append(o); o += max(n, 0)
    return off
def series(lat, lon):
    m = json.load(open(out + '/latest.json')); r, c = cell(lat, lon); i = (r // T) * m["cols"] + c // T; n = m["tiles"][i]
    if n == 0: return [0] * m["frames"], 0
    if n < 0: return None, 0
    blob = open(out + '/run.bin', 'rb').read()[offsets(m)[i]:offsets(m)[i] + n]          # = one HTTP range request
    tile = np.frombuffer(zlib.decompress(blob), np.uint8)
    h = min(T, H - (r // T) * T); w = min(T, W - (c // T) * T)
    return tile.reshape(h, w, m["frames"])[r % T, c % T].tolist(), n
def view(lat, lon, km):
    m = json.load(open(out + '/latest.json')); r, c = cell(lat, lon); off = offsets(m); reqs = 0; total = 0
    for tr in range(max(0, (r - km // 2) // T), min(rows - 1, (r + km // 2 - 1) // T) + 1):
        idx = [tr * cols + tc for tc in range(max(0, (c - km // 2) // T), min(cols - 1, (c + km // 2 - 1) // T) + 1)]
        n = sum(max(m["tiles"][i], 0) for i in idx)
        if n: reqs += 1; total += n                                   # one range per tile row: tiles in a row are adjacent
    return reqs, total
for name, (la, lo) in {"Rotterdam": (51.92, 4.48), "Groningen": (53.22, 6.57), "Maastricht": (50.85, 5.69), "Texel": (53.06, 4.80)}.items():
    s, n = series(la, lo); r, c = cell(la, lo)
    assert s == byte[:, r, c].tolist()
    print(f"{name} cell {(r, c)} tile bytes {n}; 30 km view {view(la, lo, 30)}; 120 km view {view(la, lo, 120)} (requests, bytes); series {s[6:16]}")
L = np.array(lengths)
print(f"tiles {len(L)}: dry {(L == 0).sum()}, no coverage {(L < 0).sum()}, with data {(L > 0).sum()}; biggest {biggest} B; median wet tile {int(np.median(L[L > 0]))} B")
print(f"pack {len(pack)} B; latest.json {len(mj)} B raw, {len(gzip.compress(mj))} B gzipped")
print(f"build {t_build - t0:.2f} s, pack {t_done - t_build:.2f} s, peak memory {resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 2**30:.2f} GB")

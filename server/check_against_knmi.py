# Written by AI on 2026.11.14 by model claude fable 5.2. Checks the job against KNMI's own files.
# It builds one run into a folder, then reads 600 rainy cells back with watch_client.py and compares
# every value with one worked out straight from KNMI's files, using the standard projection library.
#   KNMI_KEY=... python3 check_against_knmi.py <folder> <YYYYMMDDHHMM>     (needs numpy, h5py, pyproj)
# KNMI's forecast files are kept in <folder>, so a second check of the same run asks KNMI for nothing.
import sys, os, io, json, time, resource, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np, h5py, job, watch_client
from datetime import datetime, timezone
from pyproj import Proj
raw = {}
orig = job.knmi_file
def keep(key, dataset, stamp):
    f = f'{sys.argv[1]}/knmi-{dataset[0]}-{stamp}'
    if os.path.exists(f): d = open(f, 'rb').read()
    else:
        d = orig(key, dataset, stamp)
        if d: open(f, 'wb').write(d)
    raw[(dataset[0], stamp)] = d; return d
job.knmi_file = keep

run = datetime.strptime(sys.argv[2], '%Y%m%d%H%M').replace(tzinfo=timezone.utc); out = sys.argv[1]; stamp = run.strftime('%Y%m%d%H%M')
t = time.perf_counter(); latest = job.build(run, os.environ['KNMI_KEY'], job.Folder(out))
print(f"build {time.perf_counter()-t:.1f} s, peak {resource.getrusage(resource.RUSAGE_SELF).ru_maxrss/2**30:.2f} GB, files asked of KNMI: {sorted(k[0][:8]+' '+k[1] for k in raw)}")
plain = h5py.File(io.BytesIO(raw[('radar_forecast', stamp)]))
blend = raw.get(('seamless_precipitation_ensemble_forecast_members', stamp)); blend = blend and h5py.File(io.BytesIO(blend))
p = Proj(plain['geographic/map_projection'].attrs['projection_proj4_params'].decode())
# wet squares -> candidate cells
sq = latest['squares']; wet_sq = [i for i, n in enumerate(sq) if n > 0]
import zlib
checked = wet = mismatch = 0; worst = 0; cells = []
off = 0
for i, n in enumerate(sq):
    if n > 0:
        h = min(32, 765 - (i // 22) * 32); w = min(32, 700 - (i % 22) * 32)
        t_ = np.frombuffer(zlib.decompress(open(f"{out}/{latest['pack']}", 'rb').read()[off:off + n], -15), np.uint8).reshape(h, w, 31)
        rr, cc = np.nonzero(((t_ > 0) & (t_ < 255)).any(2))
        cells += [((i // 22) * 32 + int(a), (i % 22) * 32 + int(b)) for a, b in zip(rr, cc)]
        off += n
random.seed(1); cells = random.sample(cells, min(600, len(cells)))
obs = [h5py.File(f"{out}/observed/{(run + job.timedelta(minutes=m)).strftime('%Y%m%d%H%M')}.h5")['image1/image_data'][()] for m in range(-30, 5, 5)]
steps = {}
if blend is not None:
    tl = list(blend['time'][:])
    for st in range(7, 25): steps[st] = blend['precip_intensity'][:, tl.index(st * 300)]
    bl, bo = blend['lat'][:], blend['lon'][:]
for r, c in cells:
    lon, lat = p(c + 0.5, -(r + 0.5 + 3650), inverse=True)
    assert watch_client.cell(lat, lon) == (r, c)
    _, _, series = watch_client.forecast(out, lat, lon)
    for k, (when, got) in enumerate(series):
        if k < 6: v = obs[k][r, c]; want = None if v >= 65534 else v * 0.12
        else:
            step = k - 6; v = plain[f'image{step+1}/image_data'][r, c]; want = v * 0.12
            if blend is not None and step >= 7:
                a, b = int(np.argmin(abs(bl - lat))), int(np.argmin(abs(bo - lon)))
                if bl.min() <= lat <= bl.max() and bo.min() <= lon <= bo.max():
                    m = steps[step][:, a, b]
                    if not (m == 65535).any():
                        m = m * 0.01; want = max(float(np.median(m)), 0.1) if (m >= 0.1).sum() >= 10 else 0.0
        if obs[6][r, c] == 65535: want = None
        if want is not None and want < 0.1: want = 0.0
        checked += 1
        if want is None or got is None: ok = want is None and got is None
        elif want == 0 or got == 0: ok = want == got
        else: ok = abs(got / want - 1) < 0.024; worst = max(worst, abs(got / want - 1)); wet += 1
        mismatch += not ok
        if not ok and mismatch < 6: print('MISMATCH', (r, c), k, want, got)
print(f"checked {checked} values at {len(cells)} cells with rain: {wet} wet, {mismatch} mismatches, largest rounding difference {worst*100:.2f}%")

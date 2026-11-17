# Written by AI on 2026.11.14 by model claude fable 5.2. The BuienWatch server job (server/DESIGN.md).
#
# Once per KNMI run it turns KNMI's files into two files a watch can read:
#   runs/<run>.bin  every 32 km square of the 2-hour forecast, compressed, back to back
#   latest          a small JSON list: the run, and the length of each square in the pack
#
# Run it:  KNMI_KEY=... python3 job.py <folder> [YYYYMMDDHHMM]
# It writes to a folder. Where the files are then served from (a bucket, a web server) is not decided
# here: build() only needs a store with get(name) and put(name, data, content_type, max_age).
import io, json, os, sys, time, urllib.error, urllib.request, zlib
from datetime import datetime, timedelta, timezone

import h5py
import numpy as np

KNMI = "https://api.dataplatform.knmi.nl/open-data/v1/datasets"
PLAIN = ("radar_forecast", "2.0", "RAD_NL25_RAC_FM_{}.h5")
OBSERVED = ("nl_rdr_data_rtcor_5m", "1.0", "RAD_NL25_RAC_RT_{}.h5")

ROWS, COLS = 765, 700        # KNMI's grid, 1 km cells
TILE = 32                    # km per square
PAST, AHEAD = 6, 25          # frames: -30..-5 min observed, 0..120 min forecast
WET = 0.1                    # mm/h; below this a cell is dry
NO_DATA = 255


# ---- KNMI ----

def knmi_file(key, dataset, stamp):
    """One file by name: a download link from KNMI's API, then the file. None if KNMI doesn't have it."""
    name, version, pattern = dataset
    url = f"{KNMI}/{name}/versions/{version}/files/{pattern.format(stamp)}/url"
    request = urllib.request.Request(url, headers={"Authorization": key, "User-Agent": "BuienWatch-server/1"})
    try:
        link = json.load(urllib.request.urlopen(request, timeout=20))["temporaryDownloadUrl"]
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None
        raise
    return urllib.request.urlopen(link, timeout=40).read()


# ---- where files go ----
# max_age is how long a cache may keep the file, in seconds; a folder has no use for it.

class Folder:
    def __init__(self, path):
        self.path = path

    def get(self, name):
        try:
            return open(os.path.join(self.path, name), "rb").read()
        except FileNotFoundError:
            return None

    def put(self, name, data, content_type, max_age):
        target = os.path.join(self.path, name)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        open(target, "wb").write(data)


# ---- the build ----

def build(run, key, store, log=print):
    """Builds and publishes one run. Returns the contents list. Raises if the plain forecast is missing."""
    stamp = run.strftime("%Y%m%d%H%M")
    calls = 0

    # Observed radar for the 30 minutes before the run and the run itself. Each file is kept in the
    # store, so KNMI is asked for a file only once.
    observed = []
    for minutes in range(-5 * PAST, 5, 5):
        name = "observed/" + (run + timedelta(minutes=minutes)).strftime("%Y%m%d%H%M") + ".h5"
        data = store.get(name)
        if data is None:
            data = knmi_file(key, OBSERVED, name[9:21]); calls += 1
            if data is not None:
                store.put(name, data, "application/x-hdf5", 86400)
        observed.append(None if data is None else h5py.File(io.BytesIO(data))["image1/image_data"][()])
    newest = next((frame for frame in reversed(observed) if frame is not None), None)
    if newest is None:
        raise RuntimeError(f"no observed radar for {stamp}: cannot tell where the radars reach")
    outside = newest == 65535            # the forecast files don't mark this, the observed ones do

    plain_file = knmi_file(key, PLAIN, stamp); calls += 1
    if plain_file is None:
        raise RuntimeError(f"KNMI has no plain forecast for {stamp} yet")
    plain = h5py.File(io.BytesIO(plain_file))
    raw = np.stack([np.full((ROWS, COLS), 65534, np.uint16) if frame is None else frame for frame in observed[:PAST]]
                   + [plain[f"image{i}/image_data"][()] for i in range(1, AHEAD + 1)])
    rate = raw.astype(np.float32) * 0.12         # 0.01 mm per 5 minutes -> mm/h
    no_data = (raw >= 65534) | outside
    wet = rate >= WET

    # One byte per value: 0 dry, 255 no data, 1..250 rain from 0.1 mm/h up, 50 steps per factor of ten.
    byte = np.where(wet, np.clip(1 + np.rint(50 * np.log10(np.maximum(rate, WET) / WET)), 1, 250), 0).astype(np.uint8)
    byte[no_data] = NO_DATA

    lengths, pack = [], bytearray()
    for top in range(0, ROWS, TILE):
        for left in range(0, COLS, TILE):
            square = byte[:, top:top + TILE, left:left + TILE]
            if not square.any():
                lengths.append(0)                                    # every cell has data and is dry
            elif (square == NO_DATA).all():
                lengths.append(-1)                                   # no radar coverage
            else:
                deflate = zlib.compressobj(9, zlib.DEFLATED, -15)    # raw DEFLATE: what Apple's Compression reads
                data = deflate.compress(np.ascontiguousarray(square.transpose(1, 2, 0)).tobytes()) + deflate.flush()
                lengths.append(len(data)); pack += data

    latest = {
        "version": 1,
        "run": run.strftime("%Y-%m-%dT%H:%MZ"),
        "blend": False,      # the blend is off: 210 to 265 MB a run in widespread rain (DESIGN.md)
        "first_frame_minutes": -5 * PAST, "frames": PAST + AHEAD, "step_minutes": 5,
        "square_km": TILE, "rows": -(-ROWS // TILE), "columns": -(-COLS // TILE),
        "pack": f"runs/{stamp}.bin",
        "squares": lengths,
    }
    store.put(latest["pack"], bytes(pack), "application/octet-stream", 86400)   # the pack first, so `latest`
    store.put("latest", json.dumps(latest, separators=(",", ":")).encode(), "application/json", 60)  # never points at nothing
    log(json.dumps({"run": latest["run"], "blend": latest["blend"], "knmi_calls": calls, "pack_bytes": len(pack),
                    "squares_with_rain": sum(n > 0 for n in lengths)}))
    return latest


def run_to_build(now):
    """The run measured 5 to 10 minutes ago: by then KNMI has published it (DESIGN.md, 'Why 5 minutes after')."""
    due = now - timedelta(minutes=5)
    return due.replace(minute=due.minute - due.minute % 5, second=0, microsecond=0)


if __name__ == "__main__":
    import resource
    folder = sys.argv[1]
    run = (datetime.strptime(sys.argv[2], "%Y%m%d%H%M").replace(tzinfo=timezone.utc) if len(sys.argv) > 2
           else run_to_build(datetime.now(timezone.utc)))
    store = Folder(folder)
    published = store.get("latest")
    if published and json.loads(published)["run"] == run.strftime("%Y-%m-%dT%H:%MZ"):
        print(f"{run:%Y-%m-%dT%H:%MZ} is already built; KNMI's rules say not to fetch it again")
        sys.exit(0)
    started = time.perf_counter()
    build(run, os.environ["KNMI_KEY"], store)
    peak = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / (2 ** 30 if sys.platform == "darwin" else 2 ** 20)
    print(f"{time.perf_counter() - started:.1f} s, peak memory {peak:.2f} GB")

# Written by AI on 2026.11.14 by model claude fable 5.2. The BuienWatch server job (server/DESIGN.md).
#
# Once per KNMI run it turns KNMI's files into two files a watch can read:
#   runs/<run>.bin  every 32 km square of the 2-hour forecast, compressed, back to back
#   latest          a small JSON list: the run, and the length of each square in the pack
#
# Run it:  KNMI_KEY=... python3 job.py <folder> [YYYYMMDDHHMM]
# It writes to a folder. Where the files are then served from (a bucket, a web server) is not decided
# here: build() only needs a store with get(name) and put(name, data, content_type, max_age).
import io, json, os, subprocess, sys, tempfile, time, urllib.error, urllib.request, zlib
from contextlib import contextmanager
from pathlib import Path
from datetime import datetime, timedelta, timezone

from probabilities import EXIT_STATUS, FIRST_STEP

KNMI = "https://api.dataplatform.knmi.nl/open-data/v1/datasets"
PLAIN = ("radar_forecast", "2.0", "RAD_NL25_RAC_FM_{}.h5")
OBSERVED = ("nl_rdr_data_rtcor_5m", "1.0", "RAD_NL25_RAC_RT_{}.h5")

ROWS, COLS = 765, 700        # KNMI's grid, 1 km cells
TILE = 32                    # km per square
PAST, AHEAD = 6, 25          # frames: -30..-5 min observed, 0..120 min forecast
WET = 0.1                    # mm/h; below this a cell is dry
NO_DATA = 255


# ---- KNMI ----

class FileTooLarge(ValueError):
    pass


def knmi_file(key, dataset, stamp, *, max_bytes=None):
    """One file by name: a download link from KNMI's API, then the file. None if KNMI doesn't have it."""
    name, version, pattern = dataset
    url = f"{KNMI}/{name}/versions/{version}/files/{pattern.format(stamp)}/url"
    request = urllib.request.Request(url, headers={"Authorization": key, "User-Agent": "BuienWatch-server/1"})
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            link = json.load(response)["temporaryDownloadUrl"]
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None
        raise
    download = urllib.request.Request(link, headers={"User-Agent": "BuienWatch-server/1"})
    with urllib.request.urlopen(download, timeout=40) as response:
        if max_bytes is None:
            return response.read()
        length = response.headers.get("Content-Length")
        if length is not None and int(length) > max_bytes:
            raise FileTooLarge
        data = response.read(max_bytes + 1)
        if len(data) > max_bytes:
            raise FileTooLarge
        return data


@contextmanager
def probability_attempt(folder, stamp, key):
    """Start one optional request. At the packing step, take a finished result or skip it."""
    attempt = Path(folder) / "observed" / f"probability-{stamp}.attempt"
    try:
        attempt.parent.mkdir(parents=True, exist_ok=True)
        attempt.touch(exist_ok=False)
    except FileExistsError:
        yield lambda: (None, "already attempted")
        return
    except OSError:
        yield lambda: (None, "could not record attempt")
        return

    try:
        output = tempfile.TemporaryFile()
    except OSError:
        yield lambda: (None, "could not open output")
        return
    with output:
        env = {k: v for k, v in os.environ.items()
               if k in {"PATH", "PYTHONPATH", "SSL_CERT_FILE", "SSL_CERT_DIR", "NIX_SSL_CERT_FILE"}}
        env.update(KNMI_KEY=key, OPENBLAS_NUM_THREADS="1", OMP_NUM_THREADS="1",
                   PYTHONDONTWRITEBYTECODE="1")
        try:
            worker = subprocess.Popen(
                [sys.executable, str(Path(__file__).with_name("probabilities.py")), stamp],
                stdout=output, env=env,
            )
        except OSError:
            yield lambda: (None, "could not start")
            return

        def ready():
            import numpy as np

            status = worker.poll()
            if status is None:
                return None, "not ready at packing"
            if status != 0:
                return None, EXIT_STATUS.get(status, "worker failed")
            try:
                expected = (AHEAD - FIRST_STEP) * ROWS * COLS
                if os.fstat(output.fileno()).st_size != expected:
                    return None, "invalid output"
                output.seek(0)
                return np.fromfile(output, np.uint8, count=expected).reshape(-1, ROWS, COLS), "used"
            except (OSError, ValueError):
                return None, "invalid output"

        try:
            yield ready
        finally:
            try:
                if worker.poll() is None:
                    worker.kill()
                worker.poll()  # do not wait on the optional process, even during shutdown
            except OSError:
                pass  # the child's own deadline still applies


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

def build(run, key, store, log=print, receive_blend=None):
    """Builds and publishes one run. Returns the contents list. Raises if the plain forecast is missing."""
    import h5py
    import numpy as np

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

    blend, blend_status = False, "not requested"
    if receive_blend is not None:
        overlay, blend_status = receive_blend()
        if overlay is not None:
            target = byte[PAST + FIRST_STEP:]
            use = (overlay != NO_DATA) & (target != NO_DATA)
            np.copyto(target, overlay, where=use)
            blend = bool(use.any())
            if not blend:
                blend_status = "no overlapping data"

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
        "blend": blend,
        "first_frame_minutes": -5 * PAST, "frames": PAST + AHEAD, "step_minutes": 5,
        "square_km": TILE, "rows": -(-ROWS // TILE), "columns": -(-COLS // TILE),
        "pack": f"runs/{stamp}.bin",
        "squares": lengths,
    }
    store.put(latest["pack"], bytes(pack), "application/octet-stream", 86400)   # the pack first, so `latest`
    store.put("latest", json.dumps(latest, separators=(",", ":")).encode(), "application/json", 60)  # never points at nothing
    log(json.dumps({"run": latest["run"], "blend": latest["blend"], "probabilities": blend_status,
                    "knmi_calls": calls, "pack_bytes": len(pack),
                    "squares_with_rain": sum(n > 0 for n in lengths)}))
    return latest


def run_to_build(now):
    """The run measured 5 to 10 minutes ago, by then KNMI publishes the plain forecast."""
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
    key = os.environ["KNMI_KEY"]
    with probability_attempt(folder, run.strftime("%Y%m%d%H%M"), key) as ready:
        build(run, key, store, receive_blend=ready)
    peak = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / (2 ** 30 if sys.platform == "darwin" else 2 ** 20)
    print(f"{time.perf_counter() - started:.1f} s, peak memory {peak:.2f} GB")

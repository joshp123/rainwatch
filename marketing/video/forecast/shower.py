"""Writes shower.json: one 1 km cell of one KNMI run, as the watch would receive it (server/job.py).
Run: uv run --with numpy --with h5py python -I shower.py <RAD_NL25_RAC_FM_<run>.h5> <observed day .tar>
Written by AI on 2026.11.18 by model claude opus 5.5. README.md says where the two KNMI files come from.
"""
import io, json, math, os, sys, tarfile
from datetime import datetime, timedelta, timezone
import h5py
import numpy as np

PLACE = {"name": "Arnhem", "latitude": 51.9819, "longitude": 5.9167}


def cell(latitude, longitude):
    """The watch's cell (Sources/RainGraph/KNMI.swift, server/watch_client.py)."""
    a, b = 6378.137, 6356.752
    e = math.sqrt(1 - (b / a) ** 2)
    def t(phi):
        return math.tan(math.pi / 4 - phi / 2) / ((1 - e * math.sin(phi)) / (1 + e * math.sin(phi))) ** (e / 2)
    north = math.radians(60)
    rho = a * math.cos(north) / math.sqrt(1 - (e * math.sin(north)) ** 2) * t(math.radians(latitude)) / t(north)
    return (math.floor(rho * math.cos(math.radians(longitude)) - 3650), math.floor(rho * math.sin(math.radians(longitude))))


def byte(raw, outside):
    """job.py's packing of one KNMI value: 0 dry, 255 no data, else 50 steps per factor of ten from 0.1 mm/h."""
    rate = raw * 0.12
    if raw >= 65534 or outside:
        return 255
    return 0 if rate < 0.1 else int(np.clip(1 + np.rint(50 * np.log10(rate / 0.1)), 1, 250))


def rate(value):
    """What the watch makes of a byte (KNMI.swift, data.py)."""
    return None if value == 255 else 0.0 if value == 0 else round(0.1 * 10 ** ((value - 1) / 50), 3)


forecast_path, tar_path = sys.argv[1:3]
stamp = os.path.basename(forecast_path)[16:28]
run = datetime.strptime(stamp, "%Y%m%d%H%M").replace(tzinfo=timezone.utc)
row, column = cell(PLACE["latitude"], PLACE["longitude"])

archive = tarfile.open(tar_path)
names = {name[-15:-3]: name for name in archive.getnames() if name.endswith(".h5")}
def observed(minutes):
    name = names[(run + timedelta(minutes=minutes)).strftime("%Y%m%d%H%M")]
    return h5py.File(io.BytesIO(archive.extractfile(name).read()))["image1/image_data"][row, column]
outside = observed(0) == 65535            # job.py takes the radars' reach from the run's own radar frame
raw = [observed(m) for m in range(-30, 0, 5)]
plain = h5py.File(forecast_path)
raw += [plain[f"image{i}/image_data"][row, column] for i in range(1, 26)]

json.dump({
    "run": run.strftime("%Y-%m-%dT%H:%MZ"),
    "knmiFile": os.path.basename(forecast_path),
    "observedArchive": os.path.basename(tar_path),
    "place": {**PLACE, "cell": [row, column]},
    "firstFrameMinutes": -30, "stepMinutes": 5,
    # mm/h in the place's 1 km cell: radar from -30 to -5 minutes, then KNMI's plain forecast from 0 to 120.
    "series": [rate(byte(int(value), outside)) for value in raw],
}, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "shower.json"), "w"), indent=1)

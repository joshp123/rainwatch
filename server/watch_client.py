# Written by AI on 2026.11.14 by model claude fable 5.2. Reads one place's forecast the way the watch
# will, to prove the server's files can be read: standard library only, no numpy, no projection library.
#   python3 watch_client.py <folder or https://address> <latitude> <longitude>
import json, math, sys, urllib.request, zlib
from datetime import datetime, timedelta


def cell(latitude, longitude):
    """Row and column of KNMI's 1 km grid: polar stereographic, true at 60 N, row 0 at y = -3650 km."""
    a, b = 6378.137, 6356.752
    e = math.sqrt(1 - (b / a) ** 2)
    def t(phi):
        return math.tan(math.pi / 4 - phi / 2) / ((1 - e * math.sin(phi)) / (1 + e * math.sin(phi))) ** (e / 2)
    north = math.radians(60)
    rho = a * math.cos(north) / math.sqrt(1 - (e * math.sin(north)) ** 2) * t(math.radians(latitude)) / t(north)
    return (math.floor(rho * math.cos(math.radians(longitude)) - 3650),
            math.floor(rho * math.sin(math.radians(longitude))))


def read(base, name, first=None, count=None):
    """The whole file, or `count` bytes from `first`: over HTTP that is one Range request."""
    if base.startswith("http"):
        request = urllib.request.Request(f"{base}/{name}")
        if first is not None:
            request.add_header("Range", f"bytes={first}-{first + count - 1}")
        return urllib.request.urlopen(request, timeout=20).read()
    with open(f"{base}/{name}", "rb") as file:
        if first is None:
            return file.read()
        file.seek(first)
        return file.read(count)


def forecast(base, latitude, longitude):
    """(run time, blend used, list of (time, mm/h or None for no data)); None outside KNMI's grid."""
    row, column = cell(latitude, longitude)
    latest = json.loads(read(base, "latest"))                       # request 1
    size, frames = latest["square_km"], latest["frames"]
    if not (0 <= row < 765 and 0 <= column < 700):
        return None
    index = (row // size) * latest["columns"] + column // size
    length = latest["squares"][index]
    if length == 0:
        values = [0] * frames                                       # dry: no second request
    elif length < 0:
        values = [255] * frames                                     # no radar coverage
    else:
        first = sum(max(n, 0) for n in latest["squares"][:index])
        square = zlib.decompress(read(base, latest["pack"], first, length), -15)     # request 2; raw DEFLATE
        width = min(size, 700 - (column // size) * size)
        at = ((row % size) * width + column % size) * frames
        values = list(square[at:at + frames])
    run = datetime.strptime(latest["run"], "%Y-%m-%dT%H:%MZ")
    return run, latest["blend"], [
        (run + timedelta(minutes=latest["first_frame_minutes"] + k * latest["step_minutes"]),
         None if v == 255 else 0.0 if v == 0 else 0.1 * 10 ** ((v - 1) / 50))
        for k, v in enumerate(values)]


if __name__ == "__main__":
    result = forecast(sys.argv[1], float(sys.argv[2]), float(sys.argv[3]))
    if result is None:
        sys.exit("outside KNMI's grid")
    run, blend, series = result
    print(f"cell {cell(float(sys.argv[2]), float(sys.argv[3]))}, run {run:%Y-%m-%d %H:%M} UTC, blend {'yes' if blend else 'no'}")
    for when, rate in series:
        print(f"{when:%H:%M}  {'no data' if rate is None else 'dry' if rate == 0 else f'{rate:.2f} mm/h'}")

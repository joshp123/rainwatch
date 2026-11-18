"""Picks the film's forecast: one place's rain from one real KNMI run, as the watch receives it.
Run: uv run --with numpy python data.py <out folder>
Written by AI on 2026.11.18 by model claude fable 5.2.

It writes <out>/forecast.json. The forecast is forecast/shower.json when that file exists (how it
was found is in forecast/README.md); otherwise it is the Afsluitdijk cell of the run the UI tests
use (App/RainUITests/Server, KNMI's forecast of 16 November 2026, 00:35 UTC).
"""
import json, os, sys, zlib
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
SERVER = f"{HERE}/../../App/RainUITests/Server"
STAND_IN = {"name": "Afsluitdijk", "cell": [327, 358], "latitude": 52.973, "longitude": 5.150}


def rate(byte):
    """mm/h from the server's byte (server/job.py); None is no data."""
    byte = int(byte)
    return None if byte == 255 else 0.0 if byte == 0 else round(0.1 * 10 ** ((byte - 1) / 50), 3)


def from_pack(place):
    latest = json.load(open(f"{SERVER}/latest"))
    pack = open(f"{SERVER}/{latest['pack']}", "rb").read()
    size, frames, columns = latest["square_km"], latest["frames"], latest["columns"]
    row, column = place["cell"]
    index, offset = (row // size) * columns + column // size, 0
    for length in latest["squares"][:index]:
        offset += max(0, length)
    length = latest["squares"][index]
    height, width = min(size, 765 - row // size * size), min(size, 700 - column // size * size)
    square = np.frombuffer(zlib.decompress(pack[offset:offset + length], -15), np.uint8).reshape(height, width, frames)
    return {"run": latest["run"], "firstFrameMinutes": latest["first_frame_minutes"], "stepMinutes": latest["step_minutes"],
            "series": [rate(b) for b in square[row % size, column % size]], "place": place}


def main(out):
    shower = f"{HERE}/forecast/shower.json"
    forecast = json.load(open(shower)) if os.path.exists(shower) else from_pack(STAND_IN)
    os.makedirs(out, exist_ok=True)
    json.dump(forecast, open(f"{out}/forecast.json", "w"))
    print(forecast["place"]["name"], forecast["run"], forecast["series"])


if __name__ == "__main__":
    main(sys.argv[1])

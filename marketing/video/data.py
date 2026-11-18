"""Makes the film's data from one real KNMI run: the forecast for one place, the radar over the
Netherlands frame by frame, and the coast and borders to draw under it.
Run: uv run --with numpy --with pillow python data.py
Written by AI on 2026.11.18 by model claude opus 5.5.

The run is the copy in the UI tests (App/RainUITests/Server): KNMI's plain forecast of 16 November
2026, 00:35 UTC, as the server packs it (server/job.py), with the 30 minutes of radar before it.
The radar is coloured with the app's own rules (App/Rain/RadarPage.swift, Painter.colour), drawn
on KNMI's own 1 km grid rather than on a map projection.
"""
import json, math, os, urllib.request, zlib
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SERVER = f"{HERE}/../../App/RainUITests/Server"
OUT = f"{HERE}/public/gen"
PLACE = {"name": "Middenmeer", "latitude": 52.815, "longitude": 5.012}
# The part of KNMI's grid the film shows (latitude and longitude of its corners), and pixels per km.
BOX = {"north": 53.75, "south": 50.65, "west": 2.9, "east": 7.35}
SCALE = 3
# Cells either side of the place's own in the close-up.
REACH = 6

# ---- KNMI's grid: polar stereographic, true at 60 N (server/watch_client.py, without the rounding) ----
A, B = 6378.137, 6356.752
E = math.sqrt(1 - (B / A) ** 2)
NORTH = math.radians(60)


def grid(latitude, longitude):
    """(row, column) on KNMI's grid, as floats: row 0 is the grid's top edge."""
    def t(phi):
        return math.tan(math.pi / 4 - phi / 2) / ((1 - E * math.sin(phi)) / (1 + E * math.sin(phi))) ** (E / 2)
    rho = A * math.cos(NORTH) / math.sqrt(1 - (E * math.sin(NORTH)) ** 2) * t(math.radians(latitude)) / t(NORTH)
    return rho * math.cos(math.radians(longitude)) - 3650, rho * math.sin(math.radians(longitude))


def load():
    latest = json.load(open(f"{SERVER}/latest"))
    pack = open(f"{SERVER}/{latest['pack']}", "rb").read()
    size, frames, columns = latest["square_km"], latest["frames"], latest["columns"]
    cells = np.zeros((frames, 765, 700), np.uint8)
    offset = 0
    for index, length in enumerate(latest["squares"]):
        top, left = (index // columns) * size, (index % columns) * size
        height, width = min(size, 765 - top), min(size, 700 - left)
        if length < 0:
            cells[:, top:top + height, left:left + width] = 255
        elif length > 0:
            square = np.frombuffer(zlib.decompress(pack[offset:offset + length], -15), np.uint8)
            cells[:, top:top + height, left:left + width] = square.reshape(height, width, frames).transpose(2, 0, 1)
            offset += length
    return latest, cells


def rate(byte):
    byte = int(byte)
    return None if byte == 255 else 0.0 if byte == 0 else round(0.1 * 10 ** ((byte - 1) / 50), 3)


# ---- the app's radar colours (RadarPage.swift), wide out: cells blended, dry fading out ----

def smoothstep(low, high, x):
    t = np.clip((x - low) / (high - low), 0, 1)
    return t * t * (3 - 2 * t)


def soften(a):
    a = a.copy()
    a[:, 1:-1] = (a[:, :-2] + 2 * a[:, 1:-1] + a[:, 2:]) / 4
    a[1:-1, :] = (a[:-2, :] + 2 * a[1:-1, :] + a[2:, :]) / 4
    return a


def colour(level, presence, missing):
    veil = np.array([0.55, 0.55, 0.6])
    veil_a = 0.4 * missing
    blue, light, white, red = (np.array(c) for c in ((0.35, 0.61, 0.83), (0.62, 0.82, 1), (0.93, 0.97, 1), (1, 0.3, 0.3)))
    def mix(a, b, t):
        return a + (b - a) * t[..., None]
    low, mid, high = level < 51, (level >= 51) & (level < 86), level >= 86
    rgb = np.where(low[..., None], mix(blue, light, smoothstep(1, 51, level)),
                   np.where(mid[..., None], mix(light, white, smoothstep(51, 86, level)), mix(white, red, smoothstep(91, 101, level))))
    opacity = np.where(low, 0.5 + 0.25 * smoothstep(1, 51, level),
                       np.where(mid, 0.75 + 0.2 * smoothstep(51, 86, level), 0.95 + 0.05 * smoothstep(91, 101, level)))
    a = np.where(presence > 0, presence * opacity, 0)
    total = a + veil_a * (1 - a)
    safe = np.where(total > 0, total, 1)
    rgb = (rgb * a[..., None] + veil * (veil_a * (1 - a))[..., None]) / safe[..., None]
    return np.dstack([rgb, total])


def radar(cells, crop):
    top, bottom, left, right = crop
    os.makedirs(f"{OUT}/radar", exist_ok=True)
    for frame in range(cells.shape[0]):
        byte = cells[frame, top:bottom, left:right].astype(np.float32)
        missing = soften((byte == 255).astype(np.float32))
        level = np.where((byte == 0) | (byte == 255), -10, byte)
        level = soften(level)
        # Up to SCALE pixels per cell, blended between cell centres.
        image = Image.fromarray(level.astype(np.float32), "F").resize(((right - left) * SCALE, (bottom - top) * SCALE), Image.BILINEAR)
        missing = Image.fromarray(missing, "F").resize(image.size, Image.BILINEAR)
        level = np.asarray(image)
        rgba = colour(level, smoothstep(-4, 3, level), np.asarray(missing))
        Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA").save(f"{OUT}/radar/{frame:02d}.png")


# ---- coast, lakes and borders from Natural Earth (public domain), as SVG paths on the crop ----

def lines(path, crop, keep=lambda properties: True):
    top, _, left, _ = crop
    out = []
    for feature in json.load(open(path))["features"]:
        if not keep(feature["properties"]):
            continue
        geometry = feature["geometry"]
        parts = geometry["coordinates"]
        if geometry["type"] in ("LineString",):
            parts = [parts]
        elif geometry["type"] == "Polygon":
            pass
        elif geometry["type"] == "MultiPolygon":
            parts = [ring for polygon in parts for ring in polygon]
        for part in parts:
            if not any(BOX["south"] - 1 < lat < BOX["north"] + 1 and BOX["west"] - 1 < lon < BOX["east"] + 1 for lon, lat in part):
                continue
            points = []
            for lon, lat in part:
                row, column = grid(lat, lon)
                points.append(f"{(column - left) * SCALE:.1f} {(row - top) * SCALE:.1f}")
            out.append("M" + " L".join(points))
    return " ".join(out)


def natural_earth():
    """Natural Earth's 1:10m coast, lakes and land borders, downloaded once into a cache."""
    folder = os.path.expanduser("~/.cache/rainwatch-video/natural-earth")
    os.makedirs(folder, exist_ok=True)
    for name in ("ne_10m_coastline", "ne_10m_lakes", "ne_10m_admin_0_boundary_lines_land"):
        path = f"{folder}/{name}.geojson"
        if not os.path.exists(path):
            url = f"https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/{name}.geojson"
            urllib.request.urlretrieve(url, path)
    return folder


def main():
    latest, cells = load()
    corners = [grid(BOX[a], BOX[b]) for a in ("north", "south") for b in ("west", "east")]
    top = max(0, int(min(r for r, _ in corners))); bottom = min(765, int(max(r for r, _ in corners)) + 1)
    left = max(0, int(min(c for _, c in corners))); right = min(700, int(max(c for _, c in corners)) + 1)
    crop = (top, bottom, left, right)
    os.makedirs(OUT, exist_ok=True)
    radar(cells, crop)

    row, column = grid(PLACE["latitude"], PLACE["longitude"])
    series = [rate(b) for b in cells[:, int(row), int(column)]]
    ne = natural_earth()
    json.dump({
        "run": latest["run"],
        "firstFrameMinutes": latest["first_frame_minutes"],
        "stepMinutes": latest["step_minutes"],
        "place": {**PLACE, "x": (column - left) * SCALE, "y": (row - top) * SCALE, "cell": [int(row), int(column)]},
        # Rain in mm/h in the place's 1 km cell, every frame from 30 minutes before the run; None is no data.
        "series": series,
        # KNMI's bytes for the cells round it, every frame: [frame][row][column], the place in the middle.
        "cells": cells[:, int(row) - REACH:int(row) + REACH + 1, int(column) - REACH:int(column) + REACH + 1].tolist(),
        "reach": REACH,
        "width": (right - left) * SCALE, "height": (bottom - top) * SCALE, "kmPerPixel": 1 / SCALE,
        "frames": int(cells.shape[0]),
        "coast": lines(f"{ne}/ne_10m_coastline.geojson", crop),
        "lakes": lines(f"{ne}/ne_10m_lakes.geojson", crop, lambda p: (p.get("scalerank") or 0) <= 10),
        "borders": lines(f"{ne}/ne_10m_admin_0_boundary_lines_land.geojson", crop),
    }, open(f"{OUT}/map.json", "w"))
    print("place series", [round(r, 2) if r is not None else None for r in series])


if __name__ == "__main__":
    main()

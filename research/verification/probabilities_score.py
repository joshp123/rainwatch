#!/usr/bin/env python3
# Written by AI on 2026.11.18 by model gpt-6.2-sol.
"""Compare KNMI probabilities against the saved season forecasts and radar truth."""

import argparse
from collections import Counter, defaultdict
import csv
from datetime import datetime
import gzip
import json
from pathlib import Path

import h5py
import numpy as np

from probabilities_fetch import HERE, PROB
from season_analyse import BANDS, LEADS, WET, boot_idx, counts, metrics


def verify_axes(file):
    np.testing.assert_array_equal(file["threshold"][:], [0.1, 0.3, 1, 3, 10, 30])
    np.testing.assert_array_equal(file["time"][:], np.arange(1, 73) * 300)
    assert file["exceedance_probability"].dtype == np.uint8


def nearest(file, places):
    lat, lon = file["lat"][:], file["lon"][:]
    if lat.ndim == 1:
        return np.array([(np.abs(lat - a).argmin(), np.abs(lon - o).argmin()) for a, o in places]).T
    # Match season.py's distance rule for the older curvilinear radar grid.
    points = []
    for a, o in places:
        distance = (lat - a) ** 2 + ((lon - o) * np.cos(np.radians(a))) ** 2
        points.append(np.unravel_index(distance.argmin(), lat.shape))
    return np.array(points).T


def read_case(path, rows):
    places = sorted({(float(r["lat"]), float(r["lon"])) for r in rows})
    place_index = {p: i for i, p in enumerate(places)}
    assert len(places) == 48
    row_index = [(int(r["lead"]) // 5 - 1, place_index[(float(r["lat"]), float(r["lon"]))]) for r in rows]
    assert len(row_index) == len(set(row_index)) == 48 * len(LEADS)
    with h5py.File(path) as file:
        verify_axes(file)
        issue = rows[0]["issue"]
        units = file["time"].attrs["units"].decode()
        assert datetime.fromisoformat(units.removeprefix("seconds since ")).strftime("%Y%m%d%H%M") == issue
        field = file["exceedance_probability"]
        i, j = nearest(file, places)
        sample = field[0, :len(LEADS)][:, i, j]
        grid = field.shape[-2:]
    valid = sample != 255
    assert np.all(sample[valid] <= 100) and np.all(sample[valid] % 5 == 0)
    return sample[tuple(np.array(row_index).T)], grid


def score(cases, sample, label):
    days = sorted(cases)
    if not days:
        print(f"\n{label}: no downloaded cases")
        return
    points = defaultdict(list)
    for ci, day in enumerate(days):
        for row, p in sample[day]:
            points["c"].append(ci)
            points["l"].append(int(row["lead"]) // 5 - 1)
            points["prob"].append(p)
            for col in ("obs", "det", "bmean", "nwet"):
                points[col].append(float(row[col]))
    a = {key: np.array(vals) for key, vals in points.items()}
    # Keep the original common mask and apply the probability mask to every forecast.
    valid = np.isfinite(a["obs"]) & np.isfinite(a["det"]) & np.isfinite(a["bmean"]) & (a["prob"] != 255)
    fields = {key: val[valid] for key, val in a.items()}
    det = fields["det"] >= WET
    blend = fields["nwet"] >= 10
    prob = fields["prob"] >= 50
    print(f"\n{label}: {len(days)} days, {valid.sum()}/{len(valid)} comparable cells")
    delta = fields["prob"] // 5 - fields["nwet"]
    print("Prob minus archived member count:", dict(sorted(Counter(delta.astype(int).tolist()).items())))
    print("Wet-mask differences (prob drier/wetter):", (blend & ~prob).sum(), (~blend & prob).sum())
    cs = {name: counts(fields, len(days), wet)
          for name, wet in (("plain", det), ("members", blend), ("probabilities", prob))}
    bands = {**BANDS, "5–120 min": (5, 120)}
    idx = boot_idx(len(days), np.random.default_rng(1))
    leads = np.array(LEADS)
    for band, (lo, hi) in bands.items():
        print(band)
        mask = (lo <= leads) & (leads <= hi)
        forecasts = {name: c[:, mask] for name, c in cs.items()}
        if lo == 5 and hi == 120:
            for name in ("members", "probabilities"):
                forecasts[f"plain to 30, then {name}"] = np.where((leads <= 30)[None, :, None], cs["plain"], cs[name])
        ref = metrics(forecasts["plain"][idx].sum(axis=(1, 2)))[0]
        for name, by_day in forecasts.items():
            hmf = by_day.sum(axis=(0, 1)).astype(int)
            csi, caught, dry = metrics(hmf)
            boots = metrics(by_day[idx].sum(axis=(1, 2)))[0]
            low, high = np.nanpercentile(boots - ref, [2.5, 97.5])
            print(f"  {name:31} CSI {csi:.5f}, caught {caught:.3%}, dry {dry:.3%},"
                  f" H/M/F {list(map(int, hmf))}, 95% delta CI vs plain [{low:+.5f}, {high:+.5f}]")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("work", type=Path)
    args = p.parse_args()
    meta = json.loads((HERE / "season_cases.json").read_text())
    rows = defaultdict(list)
    with gzip.open(HERE / "season_cells.csv.gz", "rt") as f:
        for row in csv.DictReader(f):
            rows[row["day"]].append(row)
    cases = {day: case for day, case in meta.items() if case["status"] == "scored"}
    assert cases.keys() == rows.keys()
    samples = {}
    grids = Counter()
    for day, case in cases.items():
        stamp = case["issue"]
        assert {row["issue"] for row in rows[day]} == {stamp}
        path = args.work / PROB[2].format(stamp)
        if not path.exists() or path.stat().st_size == 0:
            print(f"No local data for {day} (issue {stamp})")
            continue
        values, grid = read_case(path, rows[day])
        grids[grid] += 1
        samples[day] = list(zip(rows[day], values, strict=True))
    print("Cases by grid:", dict(grids))
    score([day for day in samples if not cases[day].get("extra")], samples, "Seasonal sample")
    score([day for day in samples if cases[day]["issue"] >= "202608300000"], samples, "Current layout, including extras")


if __name__ == "__main__":
    main()

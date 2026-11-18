# Written by AI on 2026.11.14 by model claude fable 5.2. Updated 2026.11.18 by gpt-6.2-sol.
# KNMI_KEY=... python3 check_against_knmi.py <folder> <YYYYMMDDHHMM> [--offline]
# Requires NumPy, h5py and pyproj. <folder> retains each KNMI file, including misses.
import argparse
from datetime import datetime, timedelta, timezone
import io
import math
import os
from pathlib import Path
import random

import h5py
import numpy as np
from pyproj import Proj

import job
import probabilities
import watch_client


def probability_rate(p, thresholds):
    """Independent scalar reference for wet/dry and the estimated 50% crossing."""
    if any(value == 255 for value in p):
        return None
    if p[0] < 50:
        return 0.0
    for low in range(len(p) - 1):
        high = low + 1
        if p[high] < 50:
            weight = (float(p[low]) - 50) / (float(p[low]) - float(p[high]))
            return math.exp((1 - weight) * math.log(thresholds[low]) + weight * math.log(thresholds[high]))
    return float(thresholds[-1])


def check(folder, stamp, offline):
    original_fetch = job.knmi_file
    run = datetime.strptime(stamp, "%Y%m%d%H%M").replace(tzinfo=timezone.utc)
    folder.mkdir(parents=True, exist_ok=True)
    key = os.environ.get("KNMI_KEY", "")

    def cached(key, dataset, stamp, **limits):
        path = folder / f"knmi-{dataset[0]}-{stamp}"
        if not path.exists():
            if offline:
                raise FileNotFoundError(path)
            data = original_fetch(key, dataset, stamp, **limits)
            path.write_bytes(data or b"")
        return path.read_bytes() or None

    job.knmi_file = cached
    try:
        compact = cached(key, probabilities.PRODUCT, stamp, max_bytes=probabilities.MAX_BYTES)
        overlay = (probabilities.read_overlay(compact, stamp, job.ROWS, job.COLS, job.AHEAD)
                   if compact is not None else None)
        result = job.build(run, key, job.Folder(folder), receive_blend=lambda: (overlay, "archive"))
    finally:
        job.knmi_file = original_fetch
    assert result["blend"] == (compact is not None)

    observed = []
    for lead in range(-30, 5, 5):
        path = folder / "observed" / f"{run + timedelta(minutes=lead):%Y%m%d%H%M}.h5"
        if path.exists():
            with h5py.File(path) as file:
                observed.append(file["image1/image_data"][:])
        else:
            observed.append(None)
    outside = next(frame for frame in reversed(observed) if frame is not None) == 65535
    with h5py.File(io.BytesIO(cached(key, job.PLAIN, stamp))) as plain:
        projection = Proj(plain["geographic/map_projection"].attrs["projection_proj4_params"].decode())
        deterministic = np.stack([plain[f"image{step}/image_data"][:] for step in range(1, 26)])
    if compact is not None:
        with h5py.File(io.BytesIO(compact)) as file:
            thresholds = file["threshold"][:]
            lat_axis, lon_axis = file["lat"][:], file["lon"][:]
            field = file["exceedance_probability"][:, 6:24]

    # Sample uniformly plus cells that are rainy in the plain forecast, and cells outside radar.
    rng = random.Random(1)
    rainy = np.argwhere(((deterministic > 0) & (deterministic < 65534)).any(axis=0) & ~outside)
    uncovered = np.argwhere(outside)
    cells = [(rng.randrange(job.ROWS), rng.randrange(job.COLS)) for _ in range(300)]
    for candidates, count in ((rainy, 250), (uncovered, 50)):
        cells += [tuple(candidates[i]) for i in rng.sample(range(len(candidates)), min(count, len(candidates)))]
    checked = wet = changed = blended = 0
    worst = 0.0
    for row, col in cells:
        lon, lat = projection(col + 0.5, -(row + 0.5 + 3650), inverse=True)
        assert watch_client.cell(lat, lon) == (row, col)
        got_run, flag, series = watch_client.forecast(str(folder), lat, lon)
        assert got_run.replace(tzinfo=timezone.utc) == run and flag == result["blend"]
        if compact is not None:
            i = int(np.argmin(abs(lat_axis - lat)))
            j = int(np.argmin(abs(lon_axis - lon)))
            covered = (lat_axis[0] - .0045 <= lat <= lat_axis[-1] + .0045
                       and lon_axis[0] - .00725 <= lon <= lon_axis[-1] + .00725)
        assert len(series) == 31
        for index, (when, got) in enumerate(series):
            lead = (index - 6) * 5
            assert when.replace(tzinfo=timezone.utc) == run + timedelta(minutes=lead)
            frame = observed[index] if lead < 0 else deterministic[index - 6]
            value = 65534 if frame is None else frame[row, col]
            want = None if outside[row, col] or value >= 65534 else value * 0.12
            if want is not None and lead > 30 and compact is not None and covered:
                estimated = probability_rate(field[:, lead // 5 - 7, i, j], thresholds)
                if estimated is not None:
                    blended += 1
                    changed += (estimated > 0) != (want > 0)
                    want = estimated
            if want is None or got is None or want == 0 or got == 0:
                assert got == want, (row, col, lead, want, got)
            else:
                error = abs(got / want - 1)
                assert error < 0.024, (row, col, lead, want, got)
                wet += 1
                worst = max(worst, error)
            checked += 1
    print(f"{checked} values at {len(cells)} cells, {wet} wet, {blended} blended, "
          f"{changed} changed wet/dry votes, largest rounding difference {worst:.2%}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Check the watch's decoded pack against saved KNMI inputs.")
    parser.add_argument("folder", type=Path)
    parser.add_argument("stamp")
    parser.add_argument("--offline", action="store_true")
    args = parser.parse_args()
    check(args.folder, args.stamp, args.offline)

#!/usr/bin/env python3
# Written by AI on 2026.11.18 by model gpt-6.2-sol.
"""Report catalogue lag or time decoding and regridding in a fresh process."""

import argparse
from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path
import resource
import sys
import time

import h5py
import numpy as np


def creation_lags(files):
    return {
        stamp: (datetime.fromisoformat(row["created"]) -
                datetime.strptime(stamp, "%Y%m%d%H%M").replace(tzinfo=timezone.utc)).total_seconds()
        for stamp, row in files.items()
    }


def summarize(snapshot):
    data = json.loads(snapshot.read_text())
    expected = set(data["expected"])
    lags = {}
    for label in ("plain", "prob", "members"):
        files = data[label]["files"]
        lag = lags[label] = creation_lags(files)
        ages = np.array(list(lag.values()))
        sizes = np.array([row["size"] for row in files.values()]) / 1e6
        late = ages[ages > 320] - 320
        print(f"{label}: {len(files)}/{len(expected)} files, {data[label]['requests']} catalogue requests")
        print("  missing:", sorted(expected - files.keys()))
        print("  min / median / p90 / p95 / p99 / max age (s):", np.percentile(ages, [0, 50, 90, 95, 99, 100]))
        print("  after 5:20 / 5:25 / 5:30:", [int((ages > t).sum()) for t in (320, 325, 330)])
        if late.size:
            print("  median and max wait after 5:20 (s):", np.median(late), late.max())
        print("  min / median / max size (MB):", sizes.min(), np.median(sizes), sizes.max())
        print("  30 days at the sample mean (GB):", sizes.mean() * 8.640)
    paired = lags["prob"].keys() & lags["members"].keys()
    print("Paired files within 1 second:",
          sum(abs(lags["prob"][s] - lags["members"][s]) <= 1 for s in paired), "/", len(paired))


def peak_mib():
    scale = 2 ** 20 if sys.platform == "darwin" else 2 ** 10
    return resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / scale


def measure(path, old_job):
    baseline_mib = peak_mib()
    started = time.perf_counter()
    with h5py.File(path) as file:
        field = file["exceedance_probability"]
        assert file["threshold"][0] == 0.1
        np.testing.assert_array_equal(file["time"][:], np.arange(1, 73) * 300)
        lat, lon = file["lat"][:], file["lon"][:]
        assert lat.ndim == lon.ndim == 1
        cell_lon, cell_lat = old_job.cell_centres()
        i = np.rint((cell_lat - lat[0]) / (lat[1] - lat[0])).astype(int)
        j = np.rint((cell_lon - lon[0]) / (lon[1] - lon[0])).astype(int)
        inside = (i >= 0) & (i < len(lat)) & (j >= 0) & (j < len(lon))
        i, j = np.clip(i, 0, len(lat) - 1), np.clip(j, 0, len(lon) - 1)
        result = np.empty((18, *inside.shape), dtype=np.uint8)
        for index, step in enumerate(range(7, 25)):
            frame = field[0, step - 1][i, j]
            # 0 dry, 1 wet, 255 use plain (outside this product or missing).
            result[index] = np.where(inside & (frame <= 100), frame >= 50, 255)
    elapsed = time.perf_counter() - started
    peak = peak_mib()
    # The coverage numbers characterize the input file for the timing comparison.
    valid = result <= 1
    return {"file": path.name, "bytes": path.stat().st_size, "process_s": elapsed,
            "baseline_mib": baseline_mib, "peak_mib": peak, "wet_fraction": float((result == 1).sum() / valid.sum())}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("file", type=Path)
    p.add_argument("old_job", nargs="?", type=Path,
                   help="server/job.py from 788d167^, required to benchmark a NetCDF file")
    args = p.parse_args()
    if args.old_job is None:
        summarize(args.file)
        return
    spec = importlib.util.spec_from_file_location("old_job", args.old_job)
    old_job = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(old_job)
    print(json.dumps(measure(args.file, old_job)))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
# Written by AI on 2026.11.18 by model gpt-6.2-sol.
"""Score the previous issue at the target run's valid times, using the season data."""
from collections import defaultdict
import csv
from datetime import datetime, timedelta
import gzip
import json
from pathlib import Path
import sys

import numpy as np

from probabilities_fetch import PROB, HERE
from probabilities_score import read_case
from season_analyse import boot_idx, counts, LEADS, metrics, WET


def previous(stamp):
    return (datetime.strptime(stamp, "%Y%m%d%H%M") - timedelta(minutes=5)).strftime("%Y%m%d%H%M")


def collect(folder, meta):
    rows = defaultdict(list)
    with gzip.open(HERE / "season_cells.csv.gz", "rt") as file:
        for row in csv.DictReader(file):
            rows[row["day"]].append(row)
    samples = {}
    for day, case in meta.items():
        issue = previous(case["issue"])
        path = folder / PROB[2].format(issue)
        if not path.exists():
            print(f"Unavailable: {day}, previous issue {issue}")
            continue
        votes, _ = read_case(path, rows[day], issue=issue, age_steps=1)
        samples[day] = list(zip(rows[day], votes, strict=True))
    return samples


def report(label, days, samples):
    points = defaultdict(list)
    for index, day in enumerate(days):
        for row, vote in samples[day]:
            points["c"].append(index)
            points["l"].append(int(row["lead"]) // 5 - 1)
            points["previous"].append(vote)
            for col in ("obs", "det", "bmean", "nwet"):
                points[col].append(float(row[col]))
    data = {key: np.array(value) for key, value in points.items()}
    mask = (data["previous"] != 255) & np.isfinite(data["obs"]) & np.isfinite(data["det"]) & np.isfinite(data["bmean"])
    print(f"{label}: {len(days)} days, {mask.sum()}/{len(mask)} comparable place-times")
    data = {key: value[mask] for key, value in data.items()}
    votes = {"plain": data["det"] >= WET, "same issue": data["nwet"] >= 10, "previous issue": data["previous"] >= 50}
    all_counts = {label: counts(data, len(days), wet) for label, wet in votes.items()}
    idx = boot_idx(len(days), np.random.default_rng(1))
    for lo, hi in ((35, 60), (65, 120)):
        print(f"  +{lo} to +{hi} minutes")
        band = (np.array(LEADS) >= lo) & (np.array(LEADS) <= hi)
        by_day = {label: values[:, band].sum(axis=1) for label, values in all_counts.items()}
        boot = {label: metrics(values[idx].sum(axis=1))[0] for label, values in by_day.items()}
        for name, values in by_day.items():
            csi, caught, dry = metrics(values.sum(axis=0))
            print(f"    {name:14} CSI {csi:.4f}, rain caught {caught*20:.2f}/20, dry warnings {dry*20:.2f}/20")
        for reference in ("plain", "same issue"):
            low, high = np.nanpercentile(boot["previous issue"] - boot[reference], (2.5, 97.5))
            print(f"    95% paired CSI interval, previous minus {reference}: [{low:+.4f}, {high:+.4f}]")


if __name__ == "__main__":
    source = json.loads((HERE / "season_cases.json").read_text())
    meta = {day: case for day, case in source.items() if case["status"] == "scored"}
    if sys.argv[1] == "--stamps":
        print(" ".join(sorted({previous(case["issue"]) for case in meta.values()})))
        sys.exit(0)
    samples = collect(Path(sys.argv[1]), meta)
    season = sorted(day for day in samples if not meta[day].get("extra"))
    report("Season", season, samples)
    report("Widespread, ≥20% wet in Dutch radar box",
           [day for day in season if meta[day]["box_wet_share"] >= .2], samples)
    report("Current grid",
           sorted(day for day in samples if meta[day]["issue"] >= "202608300000"), samples)

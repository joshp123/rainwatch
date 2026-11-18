#!/usr/bin/env python3
# Written by AI on 2026.11.18 by model gpt-6.2-sol.
"""Fetch each probability file once, keeping the files for offline verification."""

import argparse
from datetime import date, datetime, time as clock_time, timedelta, timezone
import json
import os
from pathlib import Path
import shutil
import time
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


BASE = "https://api.dataplatform.knmi.nl/open-data/v1/datasets"
AGENT = "RainWatch-forecast-verification/1"
PROB = ("seamless_precipitation_ensemble_forecast_probabilities", "1.0", "KNMI_PYSTEPS_BLEND_PROB_{}.nc")
MEMBERS = ("seamless_precipitation_ensemble_forecast_members", "1.0", "KNMI_PYSTEPS_BLEND_ENS_{}.nc")
PLAIN = ("radar_forecast", "2.0", "RAD_NL25_RAC_FM_{}.h5")
HERE = Path(__file__).resolve().parent


def api(dataset, suffix=""):
    name, version, _ = dataset
    url = f"{BASE}/{name}/versions/{version}/files{suffix}"
    request = Request(url, headers={"Authorization": os.environ["KNMI_API_KEY"], "User-Agent": AGENT})
    with urlopen(request, timeout=40) as response:
        return json.load(response)


def fetch(work, stamp):
    name = PROB[2].format(stamp)
    path = work / name
    if path.exists():
        raise RuntimeError(f"{name} was already attempted in {work}")
    started = time.perf_counter()
    try:
        link = api(PROB, f"/{name}/url")["temporaryDownloadUrl"]
    except HTTPError as error:
        if error.code == 404:
            return {"stamp": stamp, "status": "absent"}
        raise
    lookup = time.perf_counter() - started

    # Keep the attempted file, even if incomplete. Do not retry a body transfer.
    try:
        with path.open("xb") as out, urlopen(Request(link, headers={"User-Agent": AGENT}), timeout=90) as response:
            size = int(response.headers["Content-Length"])
            shutil.copyfileobj(response, out, length=256 * 1024)
        if path.stat().st_size != size:
            return {"stamp": stamp, "status": "incomplete", "bytes": path.stat().st_size, "expected": size}
    except OSError as error:
        # Avoid printing a presigned URL in an exception.
        return {"stamp": stamp, "status": "transfer error", "error": type(error).__name__}
    return {"stamp": stamp, "status": "ok", "bytes": size, "lookup_s": lookup,
            "download_s": time.perf_counter() - started - lookup}


def sequence(start, days):
    return [(start + i * timedelta(minutes=5)).strftime("%Y%m%d%H%M") for i in range(288 * days)]


def snapshot(dataset, stamps):
    _, _, pattern = dataset
    wanted = {pattern.format(stamp): stamp for stamp in stamps}
    query = {"maxKeys": min(1000, len(stamps)), "orderBy": "filename",
             "begin": pattern.format(stamps[0]), "end": pattern.format(stamps[-1])}
    files = {}
    calls = 0
    while True:
        page = api(dataset, "?" + urlencode(query))
        calls += 1
        for file in page["files"]:
            name = file["filename"]
            if name in wanted:
                files[wanted[name]] = file
        if not page["isTruncated"] or page["files"][-1]["filename"] >= pattern.format(stamps[-1]):
            return {"requests": calls, "files": files}
        query["nextPageToken"] = page["nextPageToken"]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("work", type=Path, help="scratch directory on the external SSD")
    p.add_argument("mode", choices=("season", "recent"))
    p.add_argument("--start", type=date.fromisoformat,
                   help="start of the recent sample in UTC, e.g. 2026-11-15")
    p.add_argument("--days", type=int, default=3)
    p.add_argument("--skip", default="", help="comma-separated stamps already recorded in another run")
    p.add_argument("--only", nargs="+", help="fetch just these issue times, without listing anything")
    args = p.parse_args()
    work = args.work
    if args.only:
        stamps = args.only
    elif args.mode == "season":
        cases = json.loads((HERE / "season_cases.json").read_text())
        stamps = [case["issue"] for case in cases.values() if case["status"] == "scored"]
    else:
        if args.start is None or args.days < 1:
            p.error("recent mode needs --start and a positive --days")
        catalogue = work / "catalogue.json"
        if catalogue.exists():
            p.error("a snapshot already exists in this directory")
        expected = sequence(datetime.combine(args.start, clock_time(), tzinfo=timezone.utc), args.days)
        datasets = {label: snapshot(dataset, expected)
                    for label, dataset in (("prob", PROB), ("members", MEMBERS), ("plain", PLAIN))}
        with catalogue.open("x") as f:
            json.dump({"expected": expected, **datasets}, f)
        return
    skip = set(args.skip.split(","))
    for stamp in dict.fromkeys(stamps):
        if stamp not in skip:
            print(json.dumps(fetch(work, stamp)), flush=True)


if __name__ == "__main__":
    main()

# Written by AI on 2026.11.18 by model gpt-6.2-sol.
"""Decode KNMI's compact forecast in the optional worker, away from the publisher."""

from datetime import datetime
import io
import math
import os
import resource
import signal
import sys
from urllib.error import HTTPError

PRODUCT = (
    "seamless_precipitation_ensemble_forecast_probabilities",
    "1.0",
    "KNMI_PYSTEPS_BLEND_PROB_{}.nc",
)
MAX_BYTES = 40_000_000
FIRST_STEP = 7  # +35 minutes, leaving plain through +30
THRESHOLDS = (0.1, 0.3, 1.0, 3.0, 10.0, 30.0)
UNAVAILABLE, OVERSIZED, INVALID = 2, 3, 4
EXIT_STATUS = {UNAVAILABLE: "unavailable", OVERSIZED: "oversized", INVALID: "invalid"}

def cell_centres(rows, cols):
    """The latitude and longitude at the centre of each radar cell."""
    import numpy as np

    a, b = 6378.137, 6356.752
    e2 = 1 - (b / a) ** 2
    e = math.sqrt(e2)

    def t(phi):
        s = e * np.sin(phi)
        return np.tan(np.pi / 4 - phi / 2) / ((1 - s) / (1 + s)) ** (e / 2)

    north = math.radians(60)
    scale = a * math.cos(north) / math.sqrt(1 - (e * math.sin(north)) ** 2) / t(north)
    x = np.arange(cols)[None, :] + 0.5
    y = -(np.arange(rows)[:, None] + 0.5 + 3650)
    chi = np.pi / 2 - 2 * np.arctan(np.hypot(x, y) / scale)
    # Conformal to geodetic latitude, through eccentricity to the eighth
    # power. This selects the same source cell as iteration across this grid.
    phi = (chi + (e2 / 2 + 5 * e2**2 / 24 + e2**3 / 12 + 13 * e2**4 / 360) * np.sin(2 * chi)
           + (7 * e2**2 / 48 + 29 * e2**3 / 240 + 811 * e2**4 / 11520) * np.sin(4 * chi)
           + (7 * e2**3 / 120 + 81 * e2**4 / 1120) * np.sin(6 * chi)
           + (4279 * e2**4 / 161280) * np.sin(8 * chi))
    return np.degrees(phi), np.degrees(np.arctan2(x, -y))


def encode_rate(rate):
    """RainWatch's one-byte rate, with zero reserved for dry."""
    import numpy as np

    return np.clip(1 + np.rint(50 * np.log10(np.maximum(rate, 0.1) / 0.1)), 1, 250).astype(np.uint8)


def median_codes():
    """Interpolate log rate at 50% between adjacent thresholds."""
    import numpy as np

    lo = np.arange(101)[:, None]
    hi = np.arange(101)[None, :]
    fraction = np.clip((lo - 50) / np.maximum(1, lo - hi), 0, 1)
    tables = np.zeros((7, 101, 101), dtype=np.uint8)
    for i, (a, b) in enumerate(zip(THRESHOLDS, THRESHOLDS[1:]), 1):
        tables[i] = encode_rate(a * (b / a) ** fraction)
    tables[6] = encode_rate(THRESHOLDS[-1])
    return tables


def codes_at_time(p, tables):
    """Turn six survival probabilities into display rates. 255 leaves the plain value."""
    import numpy as np

    missing = (p == 255).any(axis=0)
    if ((p > 100) & (p != 255)).any() or ((p[1:] > p[:-1]) & ~missing).any():
        raise ValueError("invalid exceedance probabilities")
    wet = (p[0] >= 50) & ~missing
    # Search for the crossing only in wet cells.
    wet_probabilities = p.reshape(len(THRESHOLDS), -1)[:, np.flatnonzero(wet)]
    bound = (wet_probabilities >= 50).sum(axis=0, dtype=np.uint8)
    low = np.take_along_axis(wet_probabilities, (bound - 1)[None], axis=0)[0]
    high = np.take_along_axis(wet_probabilities, np.minimum(bound, 5)[None], axis=0)[0]
    codes = np.zeros(p.shape[1:], dtype=np.uint8)
    codes[wet] = tables[bound, low, high]
    codes[missing] = 255
    return codes


def read_overlay(data, stamp, rows, cols, ahead):
    """Read one complete grid of optional codes for +35…120 minutes."""
    import h5py
    import numpy as np

    with h5py.File(io.BytesIO(data), "r") as file:
        field = file["exceedance_probability"]
        if (field.shape != (6, 72, 780, 780) or field.dtype != np.uint8
                or field.chunks != (1, 1, 780, 780) or field.compression != "gzip"
                or field.is_virtual or field.external):
            raise ValueError("unsupported probability field")
        time = file["time"]
        units = time.attrs["units"].decode()
        if (units != f"seconds since {datetime.strptime(stamp, '%Y%m%d%H%M')}"
                or time.shape != (72,) or not np.array_equal(time[:], np.arange(1, 73) * 300)):
            raise ValueError("unexpected probability run or leads")
        threshold = file["threshold"]
        if threshold.shape != (6,) or not np.array_equal(threshold[:], THRESHOLDS):
            raise ValueError("unexpected rain thresholds")
        indices = []
        inside = np.ones((rows, cols), dtype=bool)
        for name, centres, spacing, first in zip(
            ("lat", "lon"), cell_centres(rows, cols), (0.009, 0.0145), (48.9955, -0.00725)
        ):
            coordinate = file[name]
            if coordinate.shape != (780,) or not np.allclose(
                coordinate[:], first + spacing * np.arange(780), rtol=0, atol=1e-6
            ):
                raise ValueError("unsupported probability grid")
            i = np.rint((centres - first) / spacing).astype(int)
            inside &= (i >= 0) & (i < 780)
            indices.append(np.clip(i, 0, 779))
        index_map = indices[0] * 780 + indices[1]

        tables = median_codes()
        overlay = np.empty((ahead - FIRST_STEP, rows, cols), dtype=np.uint8)
        for index, step in enumerate(range(FIRST_STEP, ahead)):
            overlay[index] = codes_at_time(field[:, step - 1], tables).take(index_map)
        overlay[:, ~inside] = 255
        return overlay


def worker(stamp):
    # A damaged input can take down HDF5, so only this child opens it. Bound its
    # address space beneath the service's 1 GiB limit, including room for the plain build.
    if sys.platform == "linux":
        limit = 512 * 1024**2
        resource.setrlimit(resource.RLIMIT_AS, (limit, limit))
    signal.alarm(5)
    from job import AHEAD, COLS, ROWS, knmi_file, FileTooLarge
    try:
        data = knmi_file(os.environ["KNMI_KEY"], PRODUCT, stamp, max_bytes=MAX_BYTES)
        if data is None:
            return UNAVAILABLE
        overlay = read_overlay(data, stamp, ROWS, COLS, AHEAD)
        sys.stdout.buffer.write(overlay.tobytes())
        return 0
    except FileTooLarge:
        return OVERSIZED
    except HTTPError:
        return UNAVAILABLE
    except Exception:
        # Don't put a presigned download URL or credential in the journal.
        return INVALID


if __name__ == "__main__":
    sys.exit(worker(sys.argv[1]))

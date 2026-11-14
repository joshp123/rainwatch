#!/usr/bin/env python3
# Written by AI on 2026.11.14 by model claude sonnet 5.5. Reads season_cells.csv.gz and season_cases.json from season.py
# and prints the tables for season.md. Confidence intervals resample whole days (cases), 4,000 times, seed 1.
#   python -I season_analyse.py season_cells.csv.gz season_cases.json [WIDESPREAD_SHARE] [new]
# Default: the 66-day seasonal sample. "new": every case issued from 30 Aug 2026 (newest blend file layout), extras included.
import csv, gzip, json, sys
import numpy as np

LEADS = list(range(5, 125, 5)); NL = len(LEADS)
BANDS = {"5–30 min": (5, 30), "35–60 min": (35, 60), "65–120 min": (65, 120)}
B = 4000
WET = 0.1
SEASON = {12: "winter", 1: "winter", 2: "winter", 3: "spring", 4: "spring", 5: "spring", 6: "summer", 7: "summer", 8: "summer", 9: "autumn", 10: "autumn", 11: "autumn"}

def load(cells_path, cases_path, wide_share, new=False):
    meta = json.load(open(cases_path))
    days = sorted(d for d, v in meta.items() if v["status"] == "scored" and ((v["issue"] >= "202608300000") if new else not v.get("extra")))
    ci = {d: i for i, d in enumerate(days)}
    cols = {k: [] for k in ("c", "l", "obs", "pers", "det", "nwet", "bmean", "bmed")}
    with gzip.open(cells_path, "rt") as fh:
        r = csv.reader(fh); next(r)
        for row in r:
            if row[0] not in ci: continue
            cols["c"].append(ci[row[0]]); cols["l"].append(int(row[4]) // 5 - 1)
            for k, j in (("obs", 5), ("pers", 6), ("det", 7), ("nwet", 8), ("bmean", 9), ("bmed", 10)): cols[k].append(float(row[j]))
    a = {k: np.array(v) for k, v in cols.items()}
    cls = np.array(["widespread" if meta[d]["box_wet_share"] >= wide_share else "showery" for d in days])
    season = np.array([SEASON[int(d[4:6])] for d in days])
    return meta, days, a, cls, season

def counts(a, ncase, wet_fc):
    """(case, lead, 3) hits, misses, false alarms for a boolean forecast-wet array."""
    ok = ~np.isnan(a["obs"]) & ~np.isnan(a["det"]) & ~np.isnan(a["bmean"])
    ow = a["obs"] >= WET; out = np.zeros((ncase, NL, 3))
    key = a["c"].astype(int) * NL + a["l"].astype(int)
    for j, m in enumerate((ow & wet_fc & ok, ow & ~wet_fc & ok, ~ow & wet_fc & ok)):
        out[:, :, j] = np.bincount(key[m], minlength=ncase * NL).reshape(ncase, NL)
    return out

def metrics(s):
    h, m, f = s[..., 0], s[..., 1], s[..., 2]
    with np.errstate(all="ignore"): return h / (h + m + f), h / (h + m), f / (h + f)  # CSI, caught, false-alarm share

def boot_idx(n, rng): return rng.integers(0, n, (B, n))

def fmt(x, lo, hi, pct=False):
    if np.isnan(x): return "n/a"
    return f"{x*100:.0f}% ({lo*100:.0f}–{hi*100:.0f})" if pct else f"{x:.2f} ({lo:.2f}–{hi:.2f})"

def main():
    cells, cases, wide = sys.argv[1], sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 0.2
    new = len(sys.argv) > 4 and sys.argv[4] == "new"
    meta, days, a, cls, season = load(cells, cases, wide, new); n = len(days); rng = np.random.default_rng(1)
    thr = {"30%": 6, "50%": 10, "70%": 14}
    V = {"KNMI plain": a["det"] >= WET}
    for k, t in thr.items(): V[f"Blend, rain if ≥{k} of versions"] = a["nwet"] >= t
    V["Persistence (rain now stays)"] = a["pers"] >= WET
    C = {k: counts(a, n, v) for k, v in V.items()}
    lead = np.array(LEADS)
    def band(lo, hi): return (lead >= lo) & (lead <= hi)
    groups = {"All cases": np.ones(n, bool), "Showery": cls == "showery", "Widespread": cls == "widespread",
              "Heavy cells (peak 50 mm/h or more)": np.array([meta[d]["box_max_mmh"] >= 50 for d in days]), "Summer (Jun–Aug)": season == "summer", "Autumn (Sep–Nov)": season == "autumn", "Winter (Dec–Feb)": season == "winter", "Spring (Mar–May)": season == "spring"}
    P = print
    if new: groups = {"All cases from 30 Aug 2026": np.ones(n, bool), "Showery": cls == "showery", "Widespread": cls == "widespread"}
    P(f"Cases: {n}. Showery {int((cls=='showery').sum())}, widespread {int((cls=='widespread').sum())} (split: mean wet share of the Dutch radar box over the 2 hours, {wide:.0%}).")
    P("By season: " + ", ".join(f"{s} {int((season==s).sum())}" for s in ("spring", "summer", "autumn", "winter")) + ".\n")
    base = "KNMI plain"; blends = [k for k in V if k.startswith("Blend")]
    for gname, gm in groups.items():
        gi = np.where(gm)[0]
        if len(gi) < 4: continue
        idx = gi[boot_idx(len(gi), rng)]
        P(f"### {gname} ({len(gi)} days)\n")
        P("| Forecast | " + " | ".join(f"{b}: CSI" for b in BANDS) + " |\n|---|" + "---|" * len(BANDS))
        rows2 = []
        for k in V:
            cs, c2 = [], []
            for bn, (lo, hi) in BANDS.items():
                bm = band(lo, hi); pt = C[k][gi][:, bm].sum(axis=(0, 1)); bs = C[k][idx][:, :, bm].sum(axis=(1, 2))
                est, boot = metrics(pt), metrics(bs)
                cs.append(fmt(est[0], *np.nanpercentile(boot[0], [2.5, 97.5])))
                c2.append(f"{fmt(est[1], *np.nanpercentile(boot[1], [2.5, 97.5]), pct=True)} / {fmt(est[2], *np.nanpercentile(boot[2], [2.5, 97.5]), pct=True)}")
            P(f"| {k} | " + " | ".join(cs) + " |"); rows2.append(f"| {k} | " + " | ".join(c2) + " |")
        P("\nRain caught / forecast rain that stayed dry:\n\n| Forecast | " + " | ".join(BANDS) + " |\n|---|" + "---|" * len(BANDS)); P("\n".join(rows2))
        P("\nCSI difference from KNMI plain (positive means better than plain), with share of days where it was better:\n")
        P("| Forecast | " + " | ".join(BANDS) + " |\n|---|" + "---|" * len(BANDS))
        for k in blends + ["Persistence (rain now stays)"]:
            cs = []
            for bn, (lo, hi) in BANDS.items():
                bm = band(lo, hi)
                d_pt = metrics(C[k][gi][:, bm].sum(axis=(0, 1)))[0] - metrics(C[base][gi][:, bm].sum(axis=(0, 1)))[0]
                d_b = metrics(C[k][idx][:, :, bm].sum(axis=(1, 2)))[0] - metrics(C[base][idx][:, :, bm].sum(axis=(1, 2)))[0]
                ca, cb = metrics(C[k][gi][:, bm].sum(axis=1))[0], metrics(C[base][gi][:, bm].sum(axis=1))[0]
                valid = ~np.isnan(ca) & ~np.isnan(cb); win = (ca[valid] > cb[valid]).mean() if valid.any() else np.nan
                lo_, hi_ = np.nanpercentile(d_b, [2.5, 97.5])
                cs.append(f"{d_pt:+.3f} ({lo_:+.3f} to {hi_:+.3f}); better on {win*100:.0f}% of days")
            P(f"| {k} | " + " | ".join(cs) + " |")
        P("")
    # per lead, all cases
    gi = np.arange(n); idx = boot_idx(n, rng)
    P("### CSI by lead time, all cases (95% interval for the blend minus plain difference)\n")
    P("| Lead (min) | KNMI plain | Blend ≥30% | Blend ≥50% | Blend ≥70% | Persistence | Blend ≥50% minus plain | Blend ≥30% minus plain |\n|---|---|---|---|---|---|---|---|")
    keys = list(V)
    for li, L in enumerate(LEADS):
        vals = [metrics(C[k][:, li].sum(axis=0))[0] for k in keys]
        def dif(k):
            d = metrics(C[k][idx][:, :, li].sum(axis=1))[0] - metrics(C[base][idx][:, :, li].sum(axis=1))[0]
            lo, hi = np.nanpercentile(d, [2.5, 97.5]); return f"{vals[keys.index(k)] - vals[0]:+.3f} ({lo:+.3f} to {hi:+.3f})"
        P(f"| {L} | " + " | ".join(f"{v:.3f}" for v in vals) + f" | {dif(keys[2])} | {dif(keys[1])} |")
    P("")
    # hybrid: plain up to a switch lead, blend after
    P("### One forecast for the whole two hours, or a switch? CSI over all 5–120 min leads, all cases\n")
    P("| Show | CSI | Difference from plain only |\n|---|---|---|")
    ref = metrics(C[base].sum(axis=(0, 1)))[0]
    for bk in (keys[1], keys[2]):
        for sw in (120, 30, 15, 5, 0):
            comb = np.concatenate([C[base][:, lead <= sw], C[bk][:, lead > sw]], axis=1)
            tot = metrics(comb.sum(axis=(0, 1)))[0]
            bs = metrics(comb[idx].sum(axis=(1, 2)))[0] - metrics(C[base][idx].sum(axis=(1, 2)))[0]
            lo, hi = np.nanpercentile(bs, [2.5, 97.5]); name = "plain only" if sw == 120 else (f"{bk} only" if sw == 0 else f"plain to {sw} min, then {bk}")
            P(f"| {name} | {tot:.3f} | {tot-ref:+.3f} ({lo:+.3f} to {hi:+.3f}) |")
    P("")
    # intensity error
    ok = ~np.isnan(a["obs"]) & ~np.isnan(a["det"]) & ~np.isnan(a["bmean"])
    P("### Rain amount error (mm/h at the 48 places; mean bias, mean absolute error), all cases\n")
    P("| Forecast | " + " | ".join(BANDS) + " |\n|---|" + "---|" * len(BANDS))
    for name, f in (("KNMI plain", a["det"]), ("Blend, mean of versions", a["bmean"]), ("Blend, median of versions", a["bmed"])):
        cs = []
        for bn, (lo, hi) in BANDS.items():
            m = ok & (a["l"] >= lo // 5 - 1) & (a["l"] <= hi // 5 - 1); e = f[m] - a["obs"][m]
            cs.append(f"bias {e.mean():+.3f}, error {np.abs(e).mean():.3f}")
        P(f"| {name} | " + " | ".join(cs) + " |")
    m = ok; P(f"\nObserved mean {a['obs'][m].mean():.3f} mm/h; share of place-lead cells wet {np.mean(a['obs'][m] >= WET):.1%} observed, {np.mean(a['det'][m] >= WET):.1%} plain, {np.mean(a['nwet'][m] >= 10):.1%} blend ≥50%.\n")
    P("### Cases\n\n| Day | Issue (UTC) | Class | Wet cells of 1152 | Dutch box wet share | Peak mm/h in box |\n|---|---|---|---|---|---|")
    for i, d in enumerate(days):
        v = meta[d]; P(f"| {d} | {v['issue'][8:10]}:{v['issue'][10:12]} | {cls[i]} | {v['wet_cells']} | {v['box_wet_share']:.2f} | {v['box_max_mmh']:.0f} |")

if __name__ == "__main__": main()

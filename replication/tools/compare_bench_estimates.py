"""Compares the estimates of the benchmark models (R/06_benchmark_estimates.R, stata/06_benchmark_estimates.do).
For each model and term: mean estimate over the seeds in each program and the difference of the means in units of
ergm's mean standard error, and the ratio of the mean standard errors (nwergm / ergm). Run from the folder replication/:  python3 tools/compare_bench_estimates.py"""
import csv, collections, statistics as st

def load(path):
    d = collections.defaultdict(lambda: collections.defaultdict(list))
    for r in csv.DictReader(open(path)):
        d[r["model"]][int(r["term"])].append((float(r["b"]), float(r["se"])))
    return d

R, S = load("results/bench_est_ergm.csv"), load("results/bench_est_nwergm.csv")
print(f"{'model':7} {'term':>4} {'ergm mean':>11} {'nwergm mean':>12} {'ergm se':>9} {'diff/se':>8} {'sd ergm':>8} {'sd nwergm':>9} {'se ratio':>8}")
worst = 0; sers = []
for m in R:
    for k in sorted(R[m]):
        r, s = R[m][k], S[m][k]
        mr, ms = st.mean(x[0] for x in r), st.mean(x[0] for x in s)
        se = st.mean(x[1] for x in r)
        z = (ms - mr) / se
        ser = st.mean(x[1] for x in s) / se
        worst = max(worst, abs(z)); sers.append(ser)
        print(f"{m:7} {k:4d} {mr:11.4f} {ms:12.4f} {se:9.4f} {z:8.3f} {st.stdev(x[0] for x in r):8.4f} {st.stdev(x[0] for x in s):9.4f} {ser:8.3f}")
print(f"largest difference of the means: {worst:.3f} standard errors")
print(f"standard errors, nwergm / ergm: {min(sers):.3f} to {max(sers):.3f}")

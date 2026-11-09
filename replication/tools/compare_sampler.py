"""Compares the statistics sampled by ergm and nwergm at the same coefficients (R/05_sampler_check.R,
stata/05_sampler_check.do). For each statistic: the mean and standard deviation over the five runs in each program,
and t = difference of the means / its standard error from the run-to-run spread. Values of |t| up to about 2 are
what independent runs of one sampler give. From the 1,000 draws of the first run in each program: the standard
deviation and the lag-1 autocorrelation of each statistic. Equal autocorrelations at the same interval mean that
the two samplers mix equally fast per proposal.   python3 tools/compare_sampler.py Lazega
With --runs20 the t-values are computed from the 20 further runs of R/05b_sampler20.R and stata/05b_sampler20.do
(results/sampler20_*.csv) instead:   python3 tools/compare_sampler.py --runs20 B4"""
import csv, sys, collections, statistics as st

def load(path):
    d = collections.defaultdict(list)
    for r in csv.DictReader(open(path)):
        d[int(r["stat"])].append(float(r["mean"]))
    return d

def draws(path):
    rows = [[float(x) for x in l.split(",")] for l in open(path) if l.strip()]
    return list(zip(*rows))

def lag1(x):
    m = st.mean(x)
    return sum((a - m) * (b - m) for a, b in zip(x[1:], x[:-1])) / sum((a - m) ** 2 for a in x)

args = sys.argv[1:]
runs20 = "--runs20" in args
args = [a for a in args if a != "--runs20"]
pre = "sampler20" if runs20 else "sampler"
for m in args or ["Lazega"]:
    R, S = load(f"results/{pre}_ergm_{m}.csv"), load(f"results/{pre}_nwergm_{m}.csv")
    print(m + (" (20 further runs)" if runs20 else ""))
    for j in sorted(R):
        r, s = R[j], S[j]
        se = (st.variance(r) / len(r) + st.variance(s) / len(s)) ** 0.5
        print(f"  statistic {j}: ergm {st.mean(r):11.3f} (sd {st.stdev(r):6.3f})   nwergm {st.mean(s):11.3f} "
              f"(sd {st.stdev(s):6.3f})   t = {(st.mean(s) - st.mean(r)) / se:6.2f}")
    if runs20:
        continue
    DR, DS = draws(f"results/draws_ergm_{m}.csv"), draws(f"results/draws_nwergm_{m}.csv")
    for j in range(len(DR)):
        print(f"  statistic {j + 1}, draws of one run: sd ergm {st.stdev(DR[j]):9.3f}  nwergm {st.stdev(DS[j]):9.3f}   "
              f"lag-1 autocorrelation ergm {lag1(DR[j]):6.3f}  nwergm {lag1(DS[j]):6.3f}")

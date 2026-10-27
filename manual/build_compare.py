#!/usr/bin/env python3
"""Builds gen_compare.tex (the numerical comparison with ergm of the chapter on validation) from the estimates written by
ex/ex91_compare_stata.do (ex/r/stata_fits.csv, ex/r/stata_stats.csv) and ex/r/compare.R (ex/r/r_fits.csv, ex/r/r_stats.csv)."""
import csv, os, statistics, collections
here = os.path.dirname(os.path.abspath(__file__))
d = os.path.join(here, "ex", "r")
def rd(f):
    return list(csv.DictReader(open(os.path.join(d, f))))
sf, rf = rd("stata_fits.csv"), rd("r_fits.csv")
ss, rs = rd("stata_stats.csv"), rd("r_stats.csv")
def by(rows):
    o = collections.OrderedDict()
    for x in rows:
        o.setdefault(x["fit"], []).append((x["term"].strip(), float(x["est"]), float(x["se"])))
    return o
S, R = by(sf), by(rf)
def tx(s): return s.replace("\\", "").replace("_", "\\_").replace("%", "\\%")
def tt(s): return "\\opt{" + tx(s) + "}"
out = []
# ---- observed statistics
out.append("\\begin{table}[ht]\\centering\\small\\caption{Observed statistics of the Lazega friendship network: nwergm (the first row of the model block of \\texttt{estat gof}) and \\texttt{summary()} of ergm.}\\label{tab:cmpstat}")
out.append("\\begin{tabular}{@{}lrrr@{}}\\toprule\nterm & nwergm & ergm & difference\\\\\\midrule")
mx = 0
for a, b in zip(ss, rs):
    x, y = float(a["obs"]), float(b["obs"])
    mx = max(mx, abs(x - y))
    out.append("%s & %.7g & %.7g & %.1e\\\\" % (tt(a["term"]), x, y, abs(x - y)))
out.append("\\bottomrule\\end{tabular}\\end{table}")
statmax = mx
# ---- MPLE
out.append("\\begin{table}[ht]\\centering\\small\\caption{Pseudolikelihood estimates: nwergm (\\texttt{estimate(mple)}) and ergm (\\texttt{estimate=\"MPLE\"}) on the same data.}\\label{tab:cmpmple}")
out.append("\\begin{tabular}{@{}llrrrrr@{}}\\toprule\nfit and term & & nwergm & ergm & $|\\Delta|$ & SE nwergm & SE ergm\\\\\\midrule")
names = {"flo_mple": "Florentine marriages", "laz_mple": "Lazega friendship", "clubs_mple": "simulated two-mode network, model 1", "clubs_mple2": "simulated two-mode network, model 2"}
dmax = 0; semax = 0
for k in ("flo_mple", "laz_mple", "clubs_mple", "clubs_mple2"):
    out.append("\\multicolumn{7}{@{}l}{\\emph{%s}}\\\\" % names[k])
    assert len(S[k]) == len(R[k]), k
    for (n1, e1, s1), (n2, e2, s2) in zip(S[k], R[k]):
        dmax = max(dmax, abs(e1 - e2)); semax = max(semax, abs(s1 - s2) / s2)
        out.append("& %s & %.5f & %.5f & %.1e & %.5f & %.5f\\\\" % (tt(n1), e1, e2, abs(e1 - e2), s1, s2))
out.append("\\bottomrule\\end{tabular}\\end{table}")
# ---- MCMLE
def seeds(P, prefix):
    return [P[k] for k in P if k.startswith(prefix)]
nw, nl, rr = seeds(S, "laz_mcmle_"), seeds(S, "laz_mcmleO_"), seeds(R, "laz_mcmle_")
out.append("\\begin{table}[ht]\\centering\\small\\caption{Monte Carlo maximum likelihood, Lazega friendship network, five seeds each: mean and (in parentheses) standard deviation over the seeds of the coefficients, and mean standard error. nwergm with its default settings (adaptive sample), nwergm with a short fixed chain (fixed-size samples, \\texttt{mcmleeffectivesize(0) mcmcburnin(3000) mcmcinterval(50)}: 3000 draws per iteration), and ergm with its default settings.}\\label{tab:cmpmcmle}")
out.append("\\begin{tabular}{@{}lrrrrrr@{}}\\toprule\n & \\multicolumn{2}{c}{nwergm, default} & \\multicolumn{2}{c}{nwergm, short fixed chain} & \\multicolumn{2}{c}{ergm}\\\\\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}\\cmidrule(lr){6-7}\nterm & mean (sd) & SE & mean (sd) & SE & mean (sd) & SE\\\\\\midrule")
maxdiffsd = 0
for j, (n1, _, _) in enumerate(nw[0]):
    cells = []
    for grp in (nw, nl, rr):
        e = [g[j][1] for g in grp]; s = [g[j][2] for g in grp]
        cells.append((statistics.mean(e), statistics.stdev(e), statistics.mean(s)))
    out.append("%s & %.3f (%.3f) & %.3f & %.3f (%.3f) & %.3f & %.3f (%.3f) & %.3f\\\\" % (
        tt(n1), cells[0][0], cells[0][1], cells[0][2], cells[1][0], cells[1][1], cells[1][2], cells[2][0], cells[2][1], cells[2][2]))
    maxdiffsd = max(maxdiffsd, abs(cells[0][0] - cells[2][0]) / cells[2][2])
out.append("\\bottomrule\\end{tabular}\\end{table}")
# ---- simulation at given coefficients (three chains of 4000 draws each, nwergm seeds 21-23, R seeds 21-23)
import glob
def draws(prefix):
    cols = None
    for f in sorted(glob.glob(os.path.join(d, prefix + "2?.csv"))):
        rows_ = list(csv.reader(open(f)))
        data = [[float(v) for v in r] for r in rows_[1:]]
        cols = cols or [[] for _ in data[0]]
        for r in data:
            for k, v in enumerate(r): cols[k].append(v)
    return cols
cn, cr = draws("stata_sim_"), draws("r_sim_")
out.append("\\begin{table}[ht]\\centering\\small\\caption{Simulation at given coefficients (the coefficients of the Lazega fit): mean and standard deviation of the model statistics over three chains of 4000 draws, nwergm (\\texttt{nwergm simulate} at the fitted coefficients with \\texttt{burnin(20000) interval(1000)}) and ergm (\\texttt{simulate()} with its default burn-in 16384 and interval 1024).}\\label{tab:cmpsim}")
out.append("\\begin{tabular}{@{}lrrrr@{}}\\toprule\nterm & mean nwergm & mean ergm & sd nwergm & sd ergm\\\\\\midrule")
simrel = 0
for nm, a, b in zip(("edges", "mutual", "nodematch\\_prac", "nodeicov\\_seniority", "gwesp\\_0.5"), cn, cr):
    ma, mb, sa, sb = statistics.mean(a), statistics.mean(b), statistics.stdev(a), statistics.stdev(b)
    simrel = max(simrel, abs(ma - mb) / sb, abs(sa - sb) / sb)
    out.append("%s & %.1f & %.1f & %.1f & %.1f\\\\" % (tt(nm), ma, mb, sa, sb))
out.append("\\bottomrule\\end{tabular}\\end{table}")
open(os.path.join(here, "gen_compare.tex"), "w").write("\n".join(out) + "\n")
with open(os.path.join(here, "gen_compare_nums.tex"), "w") as f:
    f.write("\\newcommand{\\cmpStatMax}{%.1e}\\newcommand{\\cmpMpleMax}{%.1e}\\newcommand{\\cmpSeRel}{%.1e}\\newcommand{\\cmpMcmleSd}{%.2f}\\newcommand{\\cmpSimRel}{%.2f}\n" % (statmax, dmax, semax, maxdiffsd, simrel))
print("stat max diff %.2e, mple max coef diff %.2e, max rel SE diff %.2e, max mcmle diff in SE units %.2f" % (statmax, dmax, semax, maxdiffsd))

# ---- run times of the Lazega model (ex9a_timing.do, r/timing.R)
tm, rt = rd("timing.csv"), rd("r_timing.csv")
lines = ["\\begin{tabular}{@{}>{\\raggedright\\arraybackslash}p{7.4cm}rrrr@{}}\\toprule\nsetting & runs & median & range & iterations\\\\\\midrule"]
for lab, k, src in (("nwergm, default settings", "default", tm), ("nwergm, fixed 3000 draws (\\texttt{mcmleeffectivesize(0)})", "fixed", tm), ("nwergm, fixed 3000 draws, burn-in 3000, interval 50", "old", tm),
                    ("nwergm, Mata sampler (\\texttt{nonative}, default settings)", "default nonative", tm), ("R \\texttt{ergm()}, default settings", "ergm default", rt)):
    v = [float(r["seconds"]) for r in src if r["setting"] == k]
    it = [float(r["iterations"]) for r in src if r["setting"] == k]
    lines.append("%s & %d & %.1f & %.1f--%.1f & %d--%d\\\\" % (lab, len(v), statistics.median(v), min(v), max(v), min(it), max(it)))
lines.append("\\bottomrule\\end{tabular}")
open(os.path.join(here, "gen_timing.tex"), "w").write("\n".join(lines) + "\n")

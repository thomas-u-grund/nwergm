# Replication files for "nwergm: Exponential-family random graph models in Stata"

This folder lets a reader check every comparison of the article between `nwergm` (Stata) and `ergm` (R) on their own
computer. Both programs read the same data, the R scripts are plain `ergm` calls with default settings, and each
Stata do-file fits the same models with `nwergm`. The results of our own runs are in `results/`, so that a reader
can compare a fresh run with what the article reports.

All commands below are run from this folder, the folder that holds this README.

## Software

| Program | Version used | How to install |
|---|---|---|
| R | 4.6.0 | <https://cran.r-project.org> |
| ergm | 4.12.0 (with network 1.20.0, statnet.common 4.13.0) | `Rscript R/00_install.R` |
| Stata | 18 (BE); also tested with 17 and 19 | |
| nwcommands | 3.17.2 | see below |
| nwergm | 1.5.5 (Tables 2 and 3, Figure 6: 1.5.4, with the same estimation code) | see below |

The versions used in the article are installed in Stata from their release tags on GitHub:

```
. net install nwcommands, replace from(https://raw.githubusercontent.com/thomas-u-grund/nwcommands/v3.17.2/)
. nwinstall, all from(https://raw.githubusercontent.com/thomas-u-grund/nwcommands/v3.17.2)
. nwinstall, modelpkg(nwergm) release(v1.5.5)
```

`ergm` 4.12.0 is the version that `nwergm` was compared with, and on 8 November 2026 it was also the newest
release on CRAN. We also ran all R scripts with the development version of `ergm` from the statnet repository on
r-universe (4.13.0-8272, with network 1.20.0-784 and statnet.common 4.14.0-526). The results did not change in
substance: the mean estimates of Table 2 moved by at most 0.12 of `ergm`'s standard errors and differed from those
of `nwergm` by at most 0.10; the effective sample sizes of `R/02_effective_size.R` were 180 to 440; and the
per-node model again agreed with `nwergm` to 1.44e-6. We did not time the development version under the controlled conditions of Table 3.

## What reproduces what

| Article | R | Stata | Result files | What to expect |
|---|---|---|---|---|
| Table 2, estimates of both programs | `R/01_compare_estimates.R` | `stata/01_compare_estimates.do` | `results/cmp_ergm.csv`, `results/cmp_nwergm.csv`, `results/tab_compare.tex` | see below |
| Effective sample size (Sections 7.2 and 9.3) | `R/02_effective_size.R` | `article/gen_logs.do` (listing of `estat mcmcdiag`) | | about 215 to 315 for `nwergm`, 240 to 500 for `ergm` |
| Table 3 and Figure 6, speed | `R/03_benchmark_fit.R` | `stata/03_benchmark_fit.do` | `results/benchmark_raw.txt`, `results/tab_bench.tex`, `results/fig_speed_bench.csv` | ratios of the medians 2.1 to 4.1 on our machine |
| Models with one coefficient per node (Section 9.3) | `R/04_per_node.R` | `stata/04_per_node.do` | `results/per_node_ergm.csv`, `results/per_node_nwergm.csv` | identical estimates up to about 1e-6 |
| All listings and figures of the article | | `article/gen_logs.do`, `article/plot_networks.do`, `article/fig_speed.do` | | identical output on the same platform |
| Manual, Appendix C: proposals per fit | `R/08_count_proposals.R` | (counter, see below) | `results/proposal_counts.txt` | |
| Manual, Appendix C: time for a fixed amount of work | `R/07_fixed_workload.R` | `stata/07_fixed_workload.do` | `results/fixed_workload.txt` | `nwergm` 2.1 to 4.4 times faster per proposal |
| Manual, Appendix C: estimates of the benchmark models | `R/06_benchmark_estimates.R` | `stata/06_benchmark_estimates.do` | `results/bench_est_ergm.csv`, `results/bench_est_nwergm.csv` | differences below 0.1 standard errors (`tools/compare_bench_estimates.py`) |
| Manual, Appendix C: samplers at given coefficients | `R/05_sampler_check.R` | `stata/05_sampler_check.do` | `results/sampler_*.csv`, `results/draws_*.csv`, `results/sampler_check.txt` | \|t\| at most 2.35; the one value above 2 is checked in the next row (`tools/compare_sampler.py`) |
| Manual, Appendix C: 20 further runs for B4 | `R/05b_sampler20.R` | `stata/05b_sampler20.do` | `results/sampler20_*.csv` | \|t\| below 1 (`tools/compare_sampler.py --runs20 B4`) |

To run the comparison of the estimates and build Table 2:

```
stata -e do stata/01_compare_estimates.do      # a few minutes; "stata" is your Stata executable
Rscript R/01_compare_estimates.R               # about 10 minutes
python3 tools/make_tables.py                   # writes results/tab_compare.tex and results/tab_bench.tex
```

To run the speed comparison (about 45 minutes; it alternates the two programs, one fit per process, seven seeds):

```
STATA="/Applications/Stata/StataBE.app/Contents/MacOS/StataBE" tools/run_benchmark.sh
python3 tools/make_tables.py
```

To run the per-node comparison, run the Stata side first, because it writes the network that R then reads:

```
stata -e do stata/04_per_node.do
Rscript R/04_per_node.R
```

For the per-node comparison the article reports 573 seconds for `ergm` and 1.0 second for `nwergm`; on an idle
machine we measured 370 and 0.61 seconds, a ratio of about 600 against about 570 in the article. Seconds depend
on the machine and its load.

The checks of Appendix C of the manual run per model; for example, for the samplers at given coefficients:

```
Rscript R/05_sampler_check.R Lazega
stata -e do stata/05_sampler_check.do Lazega
python3 tools/compare_sampler.py Lazega
```

The listings of the article are produced in the folder `article/` (`cd article`, then `stata -e do gen_logs.do`);
`article/hdr_local.do` explains how it finds the packages.

## How close the numbers should be

Fits that do not simulate agree to the last digits. The pseudolikelihood fits (Florentine and Lazega, MPLE in
Table 2) differ by less than 1e-7 in the coefficients and 1e-5 in the standard errors, and the 799 coefficients of
the per-node model by about 1e-6. The observed statistics of every term agree to 1e-6 or better.

Fits by Monte Carlo maximum likelihood cannot agree to the digit, because the two programs use different random
number generators. For these, Table 2 reports the mean over several seeds for each program and the difference of the
means in units of `ergm`'s standard error. The differences are at most 0.09 standard errors, and the seed-to-seed
spread of each program is of the same order. A fresh run with other seeds should give differences of the same size.
`tools/make_tables.py` also prints each difference in units of the Monte Carlo error of the two means; three of the 23
coefficients fitted with several seeds in both programs differ by more than two such errors (see the article, Section 9.2).

Timings depend on the machine and its load. The ratios between the programs are more stable than the seconds;
`results/load.txt` records the load average before each of our fits.

## Data

`data/` holds the networks as adjacency matrices (CSV without header) and the node attributes. They are exports of
the data sets distributed with `nwcommands` (Florentine families, Lazega law firm, Southern women, Faux Mesa High)
and of the synthetic benchmark networks; `stata/00_export_data.do` shows how they were written. The 400-node
network of the per-node comparison (`data/net400_edges.csv`) is written by `stata/04_per_node.do`.

## Where the speed comes from

Appendix C of the manual of `nwergm`, "Comparison with ergm: the same estimator, and where the speed comes from",
explains with these measurements why `nwergm` is faster than `ergm` although it runs the same algorithm with the
same defaults. The manual is archived at Zenodo, <https://doi.org/10.5281/zenodo.23661331> (all versions),
and is also in the `nwergm` repository:
<https://github.com/thomas-u-grund/nwergm/blob/main/manual/nwergm_manual.pdf>.

The released `nwergm` does not report its number of proposals. For `results/proposal_counts.txt` we used a copy of
`nwergm` in which a few lines were added before the call of the sampler, adding `burn-in + sample size × interval` of
each call to a global macro; nothing else was changed, and the copy gives the same fits as the released version.
Without it, the counts can be followed in the `verbose` trace, which prints the size and interval of each adaptive
run. For the fixed workload the counts follow from the settings and `e(mcmc_interval_final)`, as
`stata/07_fixed_workload.do` computes them.

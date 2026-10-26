# NOTICE

<!--version-->**Version 1.3.1** (released 26 October 2026)<!--/version-->

nwergm is Copyright (C) 2026 Thomas U. Grund and is distributed under the GNU General Public License, version 3 (file `LICENSE`).

## What this package is derived from

`nwergm` implements the exponential-family random graph model and was developed from the statnet R package `ergm` (term definitions and change statistics, MPLE/MCMLE estimation, MCMC diagnostics), whose license is GPL-3 (+ file LICENSE); `nwergm` is therefore distributed under the GNU General Public License version 3.
* **ergm (statnet)** (R package, version compared: 4.12.0 (4.13 development version for the Firth penalised MPLE)). Authors: Mark S. Handcock, David R. Hunter, Carter T. Butts, Steven M. Goodreau, Pavel N. Krivitsky, Martina Morris and contributors. License: GPL-3 (+ file LICENSE).
  https://cran.r-project.org/package=ergm
  Reference: Handcock, M. S., Hunter, D. R., Butts, C. T., Goodreau, S. M. and Morris, M. (2008). statnet: Software tools for the representation, visualization, analysis and simulation of network data. Journal of Statistical Software 24(1); Hunter, D. R., Handcock, M. S., Butts, C. T., Goodreau, S. M. and Morris, M. (2008). ergm: A package to fit, simulate and diagnose exponential-family models for networks. Journal of Statistical Software 24(3).

## Validation

Estimates, standard errors, log-likelihoods, simulated statistics, goodness-of-fit tables and MCMC diagnostics were compared with `ergm` 4.12.0 (and the 4.13 development version for the Firth penalised MPLE) on the statnet example networks and on simulated networks; the R scripts and data are in `dev/` and the regression tests in `cscripts/test_nwergm_*.do`. `docs/VALIDATED_AGAINST_R.md` lists what is validated and how; `docs/ERGM_COMPARISON.md` and `docs/ERGM_TERMS_INVENTORY.csv` document the term-by-term comparison with R, including what is not implemented.

## AI assistance

The software was developed with Claude Code (Anthropic), an AI coding assistant, working under the author's direction. It helped port algorithms from ergm into Stata, Mata and C and helped write the tests. The author specified the scope, reviewed the code, and is responsible for the package. Its correctness rests on validation, not on the assistant: the results are compared numerically with ergm, and the test suite reruns these comparisons.

## How to cite

Grund, T. U. (2026). nwergm: a Stata package (version 1.3.1). GitHub. https://github.com/thomas-u-grund/nwergm
Please also cite the core package (Grund, T. U., nwcommands) and the work this package is derived from (see above).

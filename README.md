# nwergm

<!--version-->**Version 1.3.4** (released 28 October 2026)<!--/version-->

`nwergm` fits exponential-family random graph models (ERGM) to a network declared with `nwset`: maximum pseudolikelihood and Monte Carlo maximum likelihood estimation (with a native MCMC plugin), dyad-independent and dyad-dependent terms (structural, nodal and dyadic covariate, curved, bipartite terms, and the operator terms of ergm such as `Sum`, `S`, `F`, `Symmetrize` and `Project`), sampling constraints, missing data, simulation from a fit, goodness of fit and MCMC diagnostics (`estat gof`, `estat mcmcdiag`). A comparison with the R package `ergm` is in `docs/ERGM_COMPARISON.md`.

Part of the nwcommands family of Stata packages for network analysis. nwergm is a separate package with its
own repository; it needs the core package nwcommands but no other model package.

## Manual

The user manual is `manual/nwergm_manual.pdf` (about 100 pages; LaTeX source, the do-files of all examples and the scripts that generate the term tables are in `manual/`). It describes the model and the estimators, every option, every term of ergm 4.12.0 with its status and validation, diagnostics and goodness of fit, worked examples with output, the comparison with R's ergm, the limits of the package, and a translation table from ergm to nwergm. Build it with `make -C manual pdf`. The manual is also on Zenodo (all versions: https://doi.org/10.5281/zenodo.23661331); cite it by that address together with the package version printed by `nwergm version`.

## Install

1. Install the core package first (Stata): `net install nwcommands, from(https://nwcommands.org/net/) replace`
   (alternative: `from(https://raw.githubusercontent.com/thomas-u-grund/nwcommands/main/)`). Required: nwcommands (core), version 3.6.0 or later.
2. Install this package from the core: `nwinstall, modelpkg(nwergm)`.
   `nwinstall, everything` installs the core and all four model packages in one step; `nwinstall, all` installs the core only and `nwinstall, models` adds the model packages to it.

`nwinstall` installs the latest release (the state of the main branch). Without `nwinstall`, the package can be installed directly from GitHub:

       net install nwergm, from(https://raw.githubusercontent.com/thomas-u-grund/nwergm/main/) replace

To install a specific version, point `from()` at the release tag (GitHub serves every tag under its own raw URL), for example version 1.3.1:

       net install nwergm, from(https://raw.githubusercontent.com/thomas-u-grund/nwergm/v1.3.4/) replace

`net describe nwergm` shows the version and distribution date, `nwergm version` the package, core and plugin versions, and `e(version)`
holds the package version in the stored results. Release history: `CHANGELOG.md`; how releases are made: `RELEASING.md`.


## MCMC defaults

The Monte Carlo defaults follow R's `ergm` (4.12.0). The sample is adaptive: each MCMLE iteration draws a base sample of
max(256, 32 p) draws for p parameters (`mcmcsamplesize()`) and keeps sampling until the effective sample size of the
estimating equations reaches 64 (`mcmleeffectivesize()`, R's `MCMLE.effectiveSize`), thinning the chain further when the
sample has doubled; the next iteration starts from half the interval that was needed. The interval starts at 1,024 proposals between recorded draws (`MCMLE.interval`) and the
burn-in at 16 times the interval, 16,384 (`MCMLE.burnin`); `nwergm simulate` uses the same interval and burn-in (R's
`simulate()`). An `mcmcinterval()` given alone also sets the burn-in to 16 times its value, as in R. `estat mcmcdiag` and
`e(mcmc_interval_final)` report the interval at which the final sample was actually recorded. `mcmleeffectivesize(0)` asks for
fixed-size samples (3,000 draws unless `mcmcsamplesize()` says otherwise), the algorithm of nwergm 1.2.3. Versions before 1.2.0
used an interval of 50 and a burn-in of 3,000; these much faster, much less reliable settings are still available:
`mcmcburnin(3000) mcmcinterval(50)`.

## Requirements

* Stata 17 or later. Tested with Stata 17 and Stata 18 (Stata/BE is enough). The Mata libraries are built with Stata 17, the oldest tested version, because a library built by a newer Stata is ignored by older ones; Stata 16 and older have not been tested and are not expected to work.
* The core nwcommands package (see above), including its Mata library `lnwcommands.mlib`.
* Platform plugins are shipped for macOS, Linux and Windows.

## Tests

The tests run against an installed or checked-out core. Point the environment variable NWCORE to the
directory of the nwcommands (core) package (the directory that contains `unw_core.do` and the core `.ado`
files) and run, from the root of this repository:

    NWCORE=/path/to/nwcommands cscripts/run_tests.sh

Each test is a do-file in `cscripts/` that prints `PASS` or `ALL OK` lines; the runner prints the number of PASS
lines and any Stata error per test. Stata is run with `-e`. Validation scripts that compare with the R
reference implementation are in `dev/`.

## Native plugin

The package ships a native Stata plugin (ergm_mcmc.c) for macOS (universal), Linux and Windows (built by the GitHub Actions workflow `.github/workflows/build-plugins.yml`; the macOS build can be reproduced with `make -C native macos`). Platform without a plugin: see the help file.

## Rebuilding the Mata library

`lib/build.do` rebuilds `lib/lnwergm.mlib` from `unw_ergm.do` (run it from the repository root: `NWCORE=/path/to/nwcommands StataBE -e do lib/build.do`).

## License

GNU General Public License version 3 (see `LICENSE`); see `NOTICE.md` for what the package is derived from and
how to cite it.

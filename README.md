# nwergm

<!--version-->**Version 1.2.2** (released 26 October 2026)<!--/version-->

`nwergm` fits exponential-family random graph models (ERGM) to a network declared with `nwset`: maximum pseudolikelihood and Monte Carlo maximum likelihood estimation (with a native MCMC plugin), dyad-independent and dyad-dependent terms (structural, nodal and dyadic covariate, curved, bipartite terms, and the operator terms of ergm such as `Sum`, `S`, `F`, `Symmetrize` and `Project`), sampling constraints, missing data, simulation from a fit, goodness of fit and MCMC diagnostics (`estat gof`, `estat mcmcdiag`). A comparison with the R package `ergm` is in `docs/ERGM_COMPARISON.md`.

Part of the nwcommands family of Stata packages for network analysis. nwergm is a separate package with its
own repository; it needs the core package nwcommands but no other model package.

## Install

1. Install the core package first (Stata): `net install nwcommands, from(<URL of the nwcommands distribution>)`
   then run `nwinstall, everything` (the core and all four model packages in one step) or `nwinstall, all` (core only). Required: nwcommands (core), version 3.6.0 or later.
2. Install this package:

       net install nwergm, from(https://raw.githubusercontent.com/thomas-u-grund/nwergm/main/) replace

`net install nwergm` installs the latest release (the state of the main branch). To install a specific version, point `from()` at the
release tag (GitHub serves every tag under its own raw URL), for example version 1.0.0:

       net install nwergm, from(https://raw.githubusercontent.com/thomas-u-grund/nwergm/v1.2.2/) replace

`net describe nwergm` shows the version and distribution date, `nwergm version` the package, core and plugin versions, and `e(version)`
holds the package version in the stored results. Release history: `CHANGELOG.md`; how releases are made: `RELEASING.md`.


## MCMC defaults

The Monte Carlo defaults follow R's `ergm` (4.12.0): an interval of 1,024 proposals between recorded draws
(`MCMLE.interval`) and a burn-in of 16 times the interval, 16,384 (`MCMLE.burnin`), at every MCMLE iteration; `nwergm
simulate` uses the same values (R's `simulate()`). An `mcmcinterval()` given alone also sets the burn-in to 16 times
its value, as in R. Versions before 1.2.0 used an interval of 50 and a burn-in of 3,000; these much faster, much less
reliable settings are still available: `mcmcburnin(3000) mcmcinterval(50)`.

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

# Changelog

All notable changes to nwergm are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the
project uses [Semantic Versioning](https://semver.org/).

## [1.0.1] - 2026-10-24

### Changed
- The help file documents the `nwergm version` subcommand and the stored results `r(version)`, `r(date)`, `r(core)`, `r(license)` and `e(version)`.

## [1.0.0] - 2026-10-24

First release of nwergm as a package of its own.

### Added
- Exponential random graph models (ERGM) for networks declared with `nwset`, directed, undirected and bipartite.
- About 110 of the 139 ergm terms: structural, nodal and dyadic covariate, degree, triad and curved (geometrically weighted) terms, bipartite terms.
- Missing data (NA ties), fit statistics (log-likelihood, deviance, AIC, BIC) and `predict`.
- Sampling and observation constraints (`constraints()`, `obsconstraints()`) and MCMC proposal hints.
- Estimation methods: maximum pseudolikelihood (incl. variants) and Monte Carlo maximum likelihood with a native MCMC plugin (macOS, Linux, Windows).
- Simulation from a fit (`nwergm simulate`), goodness of fit (`estat gof`) and MCMC diagnostics.
- `nwergm version`: package, core and plugin versions; `e(version)` in the results.
- Compared with and validated against R ergm 4.12.0.

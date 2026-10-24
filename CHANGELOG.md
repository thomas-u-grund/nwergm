# Changelog

All notable changes to nwergm are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the
project uses [Semantic Versioning](https://semver.org/).

## [1.1.0] - 2026-10-24

### Added
- Option `operators()`: the operator terms of R's ergm. `Sum`, `Prod`, `S`, `F`, `NodematchFilter`, `Symmetrize`, `Project` (`Proj1`, `Proj2`), `I`, `For`, `Label`, `Log`, `Exp` and `Offset`, with the arguments of R
  (`label`, `filter`, `attrs`, `rule`, `mode`, `pos`, `log0`, `coef`, `which`); operators can be nested. Help: `help nwergm_operators`.
- The native plugin evaluates composite columns and the networks derived by the operators (filtered, symmetrized, induced subgraph, one-mode projection); the macOS binary is rebuilt, the Linux and Windows binaries have to be rebuilt before a release.
- Tests `test_nwergm_ops` (statistics, MPLE and MCMLE against R ergm 4.12.0 on random and real undirected, directed and two-mode networks) and `test_nwergm_ops_native` (plugin against brute-force differences), generator `dev/gen_test_ops.R`.
- Operator `Curve()` (and `Parametrise()`, `Parametrize()`) with linear maps, `map(rep)` and `map(matrix(name))`.
- Term `balance` (`structural(balance)`): balanced triads, undirected and directed.
- `altkstar` without `fixed` (R's default, estimated lambda) in `structural()`, for `method(mple)` with starting values from `init()`; `init()` for the other curved terms with `method(mple)`.
- Tests against R ergm 4.12.0: `test_nwergm_balance`, `test_nwergm_altkstar`, `test_nwergm_bipcurved` (curved two-mode terms `gwb1degree`, `gwb2degree`, `gwb1dsp`, `gwb2dsp`), `test_nwergm_curveddeg`; generators in `dev/`.

### Fixed
- Maximum likelihood with a curved degree term (`bgwdegreefree1/2()`, `gwdegreefree()`, `gwodegreefree()`, `gwidegreefree()`) counted the nodes only up to the maximum degree of the observed network plus one, so a sampled network with a larger degree changed the model and the fit could run away; the counts now run over all possible degrees for `method(mcmle)` (the pseudolikelihood keeps the shorter range).
- `seed()` did not reproduce a fit across sessions: the edge order of the starting network, which steers the MCMC, followed the order in which the core returns the neighbors of a node, and that differs once another network has been loaded (`edges` -3.375 in one script, -3.325 in another with the same data and seed). The neighbors are now read in sorted order, so the same call with the same `seed()` gives identical coefficients; the help of `seed()` states what is reproducible. Test `test_nwergm_seedrepro`.
- The help gave 20 as the default of `mcmleiterations()`; it is 60 as in R. Test `test_nwergm_maxit` checks that MCMLE stops at `mcmleiterations()` with a warning and `e(converged)` = 0. (A fit of a degenerate model can still take long: once the Monte Carlo sample does not mix, the thinning interval grows to 20000 and every iteration costs about a minute, so 60 iterations take about 20 minutes; lower `mcmleiterations()` for such a model.)
- The display names of the curved two-mode terms are `gwb1degree_weight`, `gwb1degree_decay` and so on (they were labelled as gwesp).

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

# Changelog

All notable changes to nwergm are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the
project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Results that change (read before you re-run old analyses)
- **The MCMLE sample size is adaptive, as in R's `ergm`.** Each MCMLE iteration now draws a base sample of max(256, 32 times the number of parameters) and keeps sampling until the effective sample size of the estimating equations reaches 64 (`mcmleeffectivesize()`, R's `MCMLE.effectiveSize`), discarding a burn-in estimated from the sample itself and thinning the chain by two whenever the sample has doubled; the next iteration starts from half the interval that was needed (R: `MCMLE.effectiveSize.interval_drop`). Before, every iteration recorded exactly 3,000 draws at the full interval and the interval was enlarged when the effective size was below max(200, 64 p). The coefficients of a fit are therefore different draws from the same distribution: they agree with R's within 0.2 standard errors on the benchmark models (10 seeds), and they scatter between seeds like R's (the effective sample size of the final sample is about 64 or more, not several hundred). `e(mcmc_samplesize)` is the number of draws actually kept. The old behaviour is `mcmleeffectivesize(0)` (fixed 3,000 draws, `mcmcsamplesize()` to change it); the sample size given in `mcmcsamplesize()` is the base size of the adaptive sample.
- **The default convergence test is R's.** With the adaptive sample the fit stops when, with 99% confidence, the estimating equations at the updated coefficients lie inside R's tolerance region (`MCMLE.MCMC.precision = 0.1`; `MCMLE.termination="confidence"`); a test that fails raises the target effective size and the base sample size by the factor R uses (at most 2, sample size with the square root of the factor). The earlier test (a Hotelling test that the mean estimating equation is zero) accepted small samples too easily: with an effective size of 64 it stopped after one iteration with coefficients that scattered 2 to 4 times more between seeds than R's. Fits with `mcmleeffectivesize(0)` keep the earlier test. The number of iterations is now like R's (Lazega advice 4 to 12, R 6 to 8).
- The covariance matrix of a converged fit is computed from the sample of the last MCMLE iteration, as in R, instead of from one further sample at the final point (a further sample is drawn only when the iterations ran out before convergence).
- The log-likelihood by bridge sampling uses, as in R, the sample size, the interval and the burn-in of the fit's own last iteration (16 bridges, about 300 draws each) instead of 3,000 draws per bridge; its Monte Carlo standard error `e(ll_se)` is somewhat larger.
- The starting values of large models (more than 20,000 dyads) differ in the ninth digit or later: the pseudolikelihood is maximized by the built-in iteration instead of falling back to Stata's `logit` (the likelihood-decrease check was an absolute 1e-9, which rounding errors exceed when the log-likelihood is in the tens of thousands).

### Changed
- Speed. On the eight benchmark models of the article (median of five fits, same networks and defaults) `nwergm` is now faster than R's `ergm` 4.12.0 on all eight (see the table in the article inputs). The main reason was the sample size policy above; in addition the C kernels are faster per proposal than before (adjacency bit matrix instead of hash lookups, tabulated GW kernel, constant-time uniform dyad draw), the frame handed to the plugin is sized to the network (not to the number of dyads), consecutive native runs hand the network on as a tie list (Mata rebuilds its graph once per fit, not after every run), the full statistics are carried from run to run, and the MPLE and dyad-independent likelihoods of large models are computed on the distinct rows of the design matrix.
- New option `mcmleeffectivesize(#)` (default 64; `0` = fixed-size samples) is now documented and drives the adaptive sample.

### Fixed
- Nothing in the estimates changes when `mcmleeffectivesize(0)` is given with explicit sample sizes: the statistics, the estimates and the log-likelihood of such a fit are identical to 1.2.3 (up to the starting values of large models noted above).

## [1.2.3] - 2026-10-26

Patch release. Works with nwcommands 3.6.0 and later; no change of the Mata library.

### Results that change (read before you re-run old analyses)
- **A valued network is now fitted as the binary graph, with one note.** With nwcommands 3.6.0 a network made with a value variable is flagged valued (also when every value is 1), and `nwergm` refused every valued network. It now fits the graph in which a tie is present when its value is not zero, as R's ergm does without `response=`; one note says that the tie values are ignored (no note when every value is 1). Fits of networks that are not flagged valued are unchanged.

### Fixed
- `edgecov()` with a two-mode covariate network on a two-mode model stopped with "has missing dyads" (the node-by-node matrix of a two-mode network is missing between nodes of the same mode); only the cells between the modes are read.
- A network whose ties are all 1 is accepted (it was refused as valued).

## [1.2.2] - 2026-10-26

### Changed
- Rebuilt for nwcommands (core) 3.6.0: the Mata library is compiled against the core library of 3.6.0 (built with Stata 17) and the package needs nwcommands 3.6.0 or later. No change in results.
- Install lines and the README: `nwinstall, everything` installs the core and the four model packages in one step. Supported Stata versions: 17 or later, tested with Stata 17 and 18.

## [1.2.1] - 2026-10-25

### Fixed
- The Mata library was built with Stata 18 and could not be used in Stata 17; it is now built with Stata 17 (works in Stata 17 and 18). Needs nwcommands 3.5.1 or later.

### Changed
- Requirements stated plainly: Stata 17 or later; tested with Stata 17 and Stata 18.


## [1.2.0] - 2026-10-25

### Results that change (read before you re-run old fits)
- The default MCMC settings are those of R's `ergm`: `mcmcinterval()` 1024 (was 50) and `mcmcburnin()` 16384 (was 3000). A fit that used the defaults gives different numbers than in 1.1.x (same seed, different chain, better mixing); fits that gave both options explicitly are unchanged.

### Changed (results change!)
- The default MCMC settings are now those of R's `ergm` 4.12.0. `mcmcinterval()` defaults to 1024 (was 50; R: `MCMLE.interval`) and `mcmcburnin()` to 16 times the interval, 16384 (was 3000; R: `MCMLE.burnin = MCMLE.interval * 16`), at every MCMLE iteration. An `mcmcinterval()` given without `mcmcburnin()` now also sets the burn-in to 16 times its value, as in R; before, the burn-in stayed at 3000. The same new defaults apply to `nwergm simulate` (R: `control.simulate`: interval 1024, burn-in 16 times the interval). Explicit `mcmcburnin()` and `mcmcinterval()` are used as given.
- Why: with an interval of 50 the chain of a dyad-dependent fit was strongly autocorrelated. On the Lazega advice model with `mutual` the effective sample size of the final sample was 21 to 29 out of 3000 draws (R: 246 to 308); with the new defaults it is 340 to 410. On the Mesa model with `gwesp(.25)` it rose from 10 to 20 to 321 to 367 (R: 158 to 184). Coefficients now agree with R within Monte Carlo error; with the old defaults single fits were off by up to two thirds of a standard error (Mesa race match 0.21 against R 0.29, se 0.12). The price is run time: a fit takes about 2 to 30 times longer than before (Lazega with `gwesp(.5)` 6 s to 20 s, Mesa 0.4 s to 13 s; R: 17 s and 4 s). The old settings are reachable with `mcmcburnin(3000) mcmcinterval(50)`.
- Fits that used the defaults give different numbers than in 1.1.x (same seed, different chain). Fits that gave both options explicitly are unchanged. Results printed in the manual, the help examples and the book for default-setting fits must be regenerated.
- Help file, dialogs (the hints next to `mcmcburnin()` and `mcmcinterval()`) and README state the new defaults; the help of `estat gof` quotes the right values for fits by pseudolikelihood. Test `test_nwergm_rdefaults` checks that the documented defaults are what runs.
- Not changed, on purpose: `mcmcsamplesize()` stays 3000 recorded draws (R adapts the number of draws to an effective size of 64, with at least 256 draws), and the adaptive interval and sample growth keep their floor of max(200, 64 times the number of parameters) effective draws, which is stricter than R's 64.

## [1.1.4] - 2026-10-25

### Changed
- Rebuilt for nwcommands 3.4.0; requires core 3.4.0 or later.

### Fixed
- When the MCMLE sampler does not mix, `nwergm` now stops with the message "Unconstrained MCMC sampling did not mix at all" and r(498) only. Before, the message was followed by a Mata traceback (`ErgmMCMLE(): 498 Stata returned error`). The Mata library `lib/lnwergm.mlib` is rebuilt for this change.

## [1.1.3] - 2026-10-25

### Fixed
- Works right after a fresh install: the Mata library is indexed automatically. Before, the first call in a new Stata session could stop with r(3499) "... not found" (or, for nwergm, "class ErgmGraph undefined") until `mata mlib index` was run by hand.

## [1.1.2] - 2026-10-25

### Fixed
- `estat gof` after a two-mode fit showed the observed value 0 for the mode-specific terms (for example `nodemix()`, `bdegree1()`, `bgwdegree2()`) in the model-statistics block: the graph that holds the observed network was not marked two-mode. The same fix applies to the R-style sample diagnostics (`estat mcmcdiag`). Test `test_nwergm_gofmodelbip`.
- A fit with a shared-partner term on a network of 5000 nodes (12.5 million dyads) stopped with r(198) "observation number out of range": the number of rows of the pseudolikelihood data was passed to a Stata macro with `strofreal()`, which writes large numbers in scientific notation (`1.12e+07`). All counts and sizes passed to macros are now formatted as integers. Tested with 2,000 and 5,000 nodes (`test_nwergm_bigdyads`).
- `nwergm simulate` from a two-mode fit with `output(network)` created one-mode undirected networks; it now creates two-mode networks, as R's `simulate()` does. Test `test_nwergm_simbip`.
- Help files: removed the outdated statements that degree and egocentric constraints are not supported (they are available through `constraints()`), brought the description of the two-mode terms up to date, and corrected the affiliation of the author to RWTH Aachen University in all files. Test `test_nwergm_helptext`.

### Changed
- Rebuilt for nwcommands 3.3.0; nwergm now requires core 3.3.0 or later; a clear message if the core and nwergm libraries do not match: the Mata library of nwergm contains the core class definitions it was compiled against, so a core of a different build made Mata stop with r(3021) "class compiled at different times". nwergm now checks this at the start of `nwergm`, `nwergm simulate` and prints how to reinstall (test `test_nwergm_libcheck`).
- A run that uses the Mata fallback instead of the compiled plugin (plugin missing for the platform, option `nonative`, or a model outside the capacity of the plugin) now prints one warning line before a Monte Carlo fit, `estat gof` and `nwergm simulate` from a fit, saying that it is much slower and what to do; the help file explains this. No warning is printed when the plugin is used. Test `test_nwergm_slowwarn`.

## [1.1.1] - 2026-10-25

### Fixed
- `estat gof, gof(b1degree)` and `gof(b2degree)` after a two-mode fit treated the fit as one-mode and stopped with "needs a two-mode network" (the two-mode test counted the mode-2 nodes that equal 0, which is always none); the number of first-mode nodes is now read from the network. The observed distributions equal those of R's `gof(fit, GOF = ~ b1degree + b2degree)`. Test `test_nwergm_gofbip`.
- `obsconstraints(b1degrees)` and `obsconstraints(b2degrees)` on a two-mode network crashed Stata (exit 139): the graph that carries the observation constraints was not marked two-mode, so the plugin received a two-mode model without a mode table and read outside its arrays. Test `test_nwergm_obsbdeg` (checks the coefficients against R's `obs.constraints`).
- `obsconstraints(observed)` stopped with a conformability error (r(3200)) on a network with missing dyads (the missing-dyad filter of the pseudolikelihood start ran after the dyad mask had been reset). `constraints(observed)` gave "no observations"; as in R it frees only the missing dyads, which R cannot fit as a main constraint (it stops with an internal error), so nwergm now stops with a plain message and points to `obsconstraints(observed)`. On a network without missing dyads R drops the empty constraint and fits without it; nwergm does the same and prints a note. Test `test_nwergm_observed`.
- `mcmletermination(none)` failed with "subscript invalid" (r(3301)) for about one seed in six: the sample-size boost used `Fstat/Fcrit`, which is below 1 when the test would pass (without a convergence test this is reached), and cut the sample to one draw. The boost is never smaller than 1 now. Test `test_nwergm_termnone` (seeds 1 to 30).
### Changed
- Dialog boxes brought up to date: `db nwergm` now sets every term and option of `nwergm` (the dyadic, curved, two-mode, `structural()` and `operators()` terms, constraints and observation constraints, estimation methods, MCMC, stochastic-approximation and bridge-sampling settings, `offset()`, `coeflabel()`), and there are new dialogs `db nwergm_simulate` and `db nwergm_estat` (`estat gof`, `estat mcmcdiag`, `estat ic`, `nwergm simulate` from a fit). The dialogs are generated from one specification (`dlg/`).
- The version is shown at the bottom of each help file.

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

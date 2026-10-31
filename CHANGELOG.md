# Changelog

All notable changes to nwergm are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the
project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- The C source of the native plugin (`native/*.c`, `native/*.h`, the `Makefile`, StataCorp's plugin interface files and a build note `ergm_native_readme.txt`) is listed in `nwergm.pkg` as ancillary files: `net get nwergm, from(...)` copies it; `net install` still installs the compiled plugins only.
- If the shipped plugin does not work on a computer, `nwinstall, buildplugin(nwergm)` (nwcommands 3.13.0 or later) fetches the source, compiles it there and installs the plugin (macOS and Linux).

## [1.3.5] - 2026-10-28

Patch release (dialogs only; includes the changes listed under 1.3.4, which was not released separately). The Mata libraries and the plugin are unchanged.

### Changed
- The simulate dialog starts with the choice "Use the model of the last nwergm fit". It is on when the last estimation was nwergm; the command is then `nwergm simulate, nsim() ...` and all model fields (nodes, terms, theta) are greyed out. Untick it to specify the model yourself.
- New drop-down "Type" (auto / undirected / directed / two-mode) in the nwergm dialog and "Network type" in the simulate dialog. It is set automatically when a network is chosen. Terms that do not apply to the type are greyed out (never hidden); "auto" switches everything on again.
- New helper `_nwergm_dlgprep.ado` fills the network list and the types when a dialog opens (works with core 3.12.1).

## [1.3.4] - 2026-10-28

Not released separately: these changes are part of 1.3.5. The Mata libraries and the plugin are unchanged.

### Changed

- Dialogs (nwergm and nwergm simulate): the geometrically weighted terms are easier to find. gwesp(), gwdsp(), gwnsp(), their decay-estimated versions gwespfree(), gwdspfree(), gwnspfree() and the type() box for directed shared partners moved from the Curved tab to the Triads tab. gwdegree(), gwodegree(), gwidegree() and their decay-estimated versions moved to the Degree tab. The Curved tab is gone because nothing was left on it. The commands the dialogs build are unchanged.
- Dialogs: the 'Simulate networks...' and 'Postestimation...' buttons gave the Stata message 'Wait until Stata has completed the current command...'. They now queue the db command instead of running it at once, so the related dialog opens.
- Dialogs: the command built by the dialogs no longer has a blank before a closing bracket (nodecov(wealth) instead of nodecov(wealth )), and the terms are always separated by one blank. With sub-options a blank can remain before the comma.

## [1.3.3] - 2026-10-28

Patch release. The Mata libraries and the plugin are unchanged.

### Changed
- **Dialog box.** The main dialog (`db nwergm`) has two buttons on its first tab, "Simulate networks..." and "Postestimation and goodness of fit...", that open the matching dialogs. The commands the dialogs build are unchanged.

## [1.3.2] - 2026-10-27

### Changed
- README: the manual is on Zenodo; the all-versions address is https://doi.org/10.5281/zenodo.23661331. Cite the manual by that address together with the package version printed by `nwergm version`.
- Development script `dev/ergm_benchmark_usair/01_prep_network.do` no longer reaches into the internal network registry of the core package (its name changes between core versions). It reads the network with `nwtomata`; the exported edge list is identical to the earlier one. No change to the package itself (same code and plugins as 1.3.1; core 3.6.0 or later).

## [1.3.1] - 2026-10-26

### Fixed
- `quietly estat mcmcdiag` printed the row of a statistic flagged by Geweke's test (and the FAILED row of the Heidelberger-Welch table and the warning about a fit that did not converge), because those lines were written in the error colour, which `quietly` does not silence. It now prints nothing.
- `estat mcmcdiag` printed the requested thinning interval (for example 1024) although the final sample was recorded at the interval the adaptive sampler arrived at, `e(mcmc_interval_final)` (for example 4096; 6400 with `mcmcinterval(50)`). The header now shows the interval of the final sample, as the report of R's `mcmc.diagnostics()` does, and a second line names the requested interval when the two differ. The autocorrelation lags of the report were already computed from the interval of the final sample.
- The closing note of `estat mcmcdiag` advised raising `mcmcsamplesize()`. It now advises raising `mcmleeffectivesize()` (the target effective sample size of the adaptive default) and, for fits with fixed-size samples (`mcmleeffectivesize(0)`), `mcmcsamplesize()` or `mcmcinterval()`.
- README: the section on the MCMC defaults describes the adaptive sample of 1.3 (base size max(256, 32 p), target effective sample size 64, interval halved from one iteration to the next; `mcmleeffectivesize(0)` is the algorithm of 1.2.3) and the install-by-tag example uses `v1.3.1`. The hint next to `mcmcsamplesize()` in the dialog no longer says "default 3000".

### Corrected
- The notes of 1.3.0 said "2.4 to 7.7 times faster than R; 1.2.3 slower on seven of the eight" benchmark models. Re-measured on an idle machine (median of seven interleaved fits): nwergm 1.3.0 is 2.9 to 9.4 times faster than R's `ergm` 4.12.0, and 1.2.3 is slower than R on six of the eight models, about equal on one and faster on one (details: the benchmark section of the manual). The 1.3.0 section below is left as it was published.

### Changed
### Changed
- Manual brought to the 1.3 series ("Manual for version 1.3", `manual/nwergm_manual.pdf`, 104 pages): it now describes the sampling of 1.3.0 (adaptive sample size, `mcmleeffectivesize()` and its interplay with `mcmcsamplesize()`, `mcmcburnin()` and `mcmcinterval()`, R's convergence test, covariance and bridge from the fit's own sample), the speed comparison with R (eight benchmark models), and the new correspondences in the translation table. Every listing, comparison table and run-time table was regenerated with nwergm 1.3.0 and nwcommands 3.10.0 (ergm 4.12.0 for the comparisons); `manual/ZENODO.md` carries the metadata of the Zenodo record for the series 1.3.
- Test `test_nwergm_estat` checks that `quietly estat mcmcdiag` prints nothing, that the printed interval equals `e(mcmc_interval_final)` and the end note.

## [1.3.0] - 2026-10-26

### Results that change (read before you re-run old analyses)
- **The MCMLE sample size is adaptive, as in R's `ergm`.** Each MCMLE iteration now draws a base sample of max(256, 32 times the number of parameters) and keeps sampling until the effective sample size of the estimating equations reaches 64 (`mcmleeffectivesize()`, R's `MCMLE.effectiveSize`), discarding a burn-in estimated from the sample itself and thinning the chain by two whenever the sample has doubled; the next iteration starts from half the interval that was needed (R: `MCMLE.effectiveSize.interval_drop`). Before, every iteration recorded exactly 3,000 draws at the full interval and the interval was enlarged when the effective size was below max(200, 64 p). The coefficients of a fit are therefore different draws from the same distribution: the mean of 20 fits agrees with the mean of 20 R fits within 0.04 standard errors on five models (Florentine, Lazega, Mesa, and two simulated networks), the reported standard errors agree within 3%, and the estimates scatter between seeds like R's (the effective sample size of the final sample is about 64 or more, not several hundred). `e(mcmc_samplesize)` is the number of draws actually kept. The old behaviour is `mcmleeffectivesize(0)` (fixed 3,000 draws, `mcmcsamplesize()` to change it); the sample size given in `mcmcsamplesize()` is the base size of the adaptive sample.
- **The default convergence test is R's.** With the adaptive sample the fit stops when, with 99% confidence, the estimating equations at the updated coefficients lie inside R's tolerance region (`MCMLE.MCMC.precision = 0.1`; `MCMLE.termination="confidence"`); a test that fails raises the target effective size and the base sample size by the factor R uses (at most 2, sample size with the square root of the factor). The earlier test (a Hotelling test that the mean estimating equation is zero) accepted small samples too easily: with an effective size of 64 it stopped after one iteration with coefficients that scattered 2 to 4 times more between seeds than R's. Fits with `mcmleeffectivesize(0)` keep the earlier test. The number of iterations is now like R's (Lazega advice 4 to 12, R 6 to 8).
- The covariance matrix of a converged fit is computed from the sample of the last MCMLE iteration, as in R, instead of from one further sample at the final point (a further sample is drawn only when the iterations ran out before convergence).
- The log-likelihood by bridge sampling uses, as in R, the sample size, the interval and the burn-in of the fit's own last iteration (16 bridges, about 300 draws each) instead of 3,000 draws per bridge; its Monte Carlo standard error `e(ll_se)` is somewhat larger.
- The starting values of large models (more than 20,000 dyads) differ in the ninth digit or later: the pseudolikelihood is maximized by the built-in iteration instead of falling back to Stata's `logit` (the likelihood-decrease check was an absolute 1e-9, which rounding errors exceed when the log-likelihood is in the tens of thousands).

### Changed
- Speed. On the eight benchmark models of the article (median of five fits, same networks and defaults, run at the same time as R) `nwergm` is now 2.4 to 7.7 times faster than R's `ergm` 4.12.0; 1.2.3 was slower than R on seven of the eight. The main reason was the sample size policy above; in addition the C kernels are faster per proposal than before (adjacency bit matrix instead of hash lookups, tabulated GW kernel, constant-time uniform dyad draw), the frame handed to the plugin is sized to the network (not to the number of dyads), consecutive native runs hand the network on as a tie list (Mata rebuilds its graph once per fit, not after every run), the full statistics are carried from run to run, and the MPLE and dyad-independent likelihoods of large models are computed on the distinct rows of the design matrix.
- New option `mcmleeffectivesize(#)` (default 64; `0` = fixed-size samples) is now documented and drives the adaptive sample.

### Fixed
- Nothing in the estimates changes when `mcmleeffectivesize(0)` is given with explicit sample sizes: the statistics, the estimates and the log-likelihood of such a fit are identical to 1.2.3 (up to the starting values of large models noted above).

### Added
- Manual brought to the 1.2 series ("Manual for version 1.2", `manual/nwergm_manual.pdf`, LaTeX source in `manual/`): the model and the estimators, the complete syntax, the reference of the terms (generated from the term inventory by `manual/build_terms.py`), diagnostics and goodness of fit, worked examples with real output, the validation against ergm 4.12.0, the limits, and a translation table from R's ergm. Every listing, comparison table and run-time table was regenerated with nwergm 1.2.3 and nwcommands 3.9.1 (ergm 4.12.0 for the comparisons). The do-files that produce every listing are in `manual/ex`; `manual/run_examples.sh` reruns them. The manual states the 1.2.x behaviour: the defaults of the Markov chain follow R's `control.ergm`, a valued network is fitted as the binary graph, `edgecov()` with a two-mode network, the installation with `nwinstall`.

## [1.2.4] - 2026-10-26

Patch release. Works with nwcommands 3.6.0 and later; no change of the Mata library.

### Changed
- Help text corrected: the description no longer says that the package is a fully native Stata/Mata implementation or that Mata is always the reference (the sampler, the change statistics and the pseudolikelihood design matrix run in the compiled plugin; the Mata implementation is a slow fallback for tests and comparison); valued networks are described as fitted to the binary graph with one note (not rejected); the speed ratios of an earlier benchmark are removed (speed relative to R depends on the model); Windows and Linux plugins are described as built by the continuous-integration workflow; the page range of Geyer and Thompson (1992) is 657-683; the provenance line says that the package was developed from ergm and is distributed under the GPL-3; the README install lines start with nwinstall. No change in code or results; the Mata library is unchanged.

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

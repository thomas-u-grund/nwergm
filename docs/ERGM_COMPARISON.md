# nwergm compared with R statnet `ergm`

Date of analysis: 2026-10-23. Analysis only: nothing in the repository was changed.

- nwergm code: `develop` worktree (`.../scratchpad/dev`), help file version 2.0.0, `native/ergm_mcmc.c`, 31 certification scripts `cscripts/test_nwergm_*.do`.
- R side: ergm **4.12.0** (R 4.6), tergm 4.2.2, ergm.count 4.1.3, ergm.multi (installed).
- Newest ergm: CRAN's newest release is **4.12.0** (checked with `available.packages()`, same as installed, so nothing was installed). GitHub master is the development version 4.13.0-8251 (2026-10-20). Changes planned for 4.13.0 (from `inst/NEWS.Rd`): `nodemix()`/`mm()` argument handling for `levels2=`; `I()` constraint accepts character input; valued proposal supports arbitrary dyadic constraints; Firth-penalised MPLE works again; MPLE existence check with lpSolve or Rglpk; MCMLE metric settings moved to a sublist of `control.ergm()`; `%d%` operator for dyadic covariates; vector-valued nodal attributes in multi-attribute terms; rewritten R-side adaptive-MCMC and convergence detection (`spectrum0.mvar`, `approx.hotelling.diff.test`), "confidence" criterion more powerful, lognormal-metric gradient/Hessian more accurate; Nelder-Mead fallback removed; **fix to `gwesp`/`esp` with `type="RTP"`** (relevant below); `enformulate.curved()` defunct; `base=`/`keep=` term arguments now warn.
- Companion files in this folder: `ERGM_TERMS_INVENTORY.csv` (171 rows), `xval/` (cross-validation data and results), `timing/`, `cscript_results.csv`, `cscript_summary.csv`, `nwergm_type_matrix.csv`.

## (a) Counts

All counts below come from scripts (listed at the end), not from memory.

**R side.** `ergm:::ergmTermCache("ergmTerm")` returns 171 documented terms: ergm 139, tergm 15, ergm.multi 15, ergm.count 2.
The 139 terms of package ergm split into 15 operators (`Curve`, `Exp`, `F`, `For`, `I`, `Label`, `Log`, `NodematchFilter`, `Offset`, `Prod`, `Project`, `S`, `Sum`, `Symmetrize`, `B`), 13 valued-only terms, and **111 binary model terms**. Of the 111 (R's own `is.dyad.independent()` / `is.curved()` on an example call): 32 dyad-independent, 79 dyad-dependent, 9 curved by default.

**nwergm side.** The syntax line of `nwergm.ado` has 56 term options (plus three paired `*to()` modifiers). Several options map to one R term (`nodematchdiff`, six `*free` forms, `type()`), so they cover **51 distinct ergm terms** (43 implemented, 8 partial).

| Denominator | Terms | nwergm implemented | + partial | Share (implemented + partial) |
|---|---|---|---|---|
| all 139 ergm-package terms | 139 | 43 | 51 | 36.7% (30.9% fully) |
| 111 binary model terms (excluding operators, valued-only) | 111 | 43 | 50 | 45.0% (38.7% fully) |
| all 171 documented terms incl. tergm, ergm.multi, ergm.count | 171 | 43 | 51 | 29.8% |

Status counts for the 139 ergm terms: IMPLEMENTED 43, PARTIAL 8, NOT IMPLEMENTED 72, NOT PLANNED 16 (13 valued-only, `B`, `Curve`, `balance`). tergm (15) and ergm.count (2) terms: NOT PLANNED. ergm.multi (15): NOT IMPLEMENTED.

By network type (a term "applies" if R's `summary()` accepts it on that type, tested with candidate arguments; R is lenient, e.g. it accepts `gwesp` on a bipartite graph without error):

| Type | R accepts | nwergm implements and accepts on this type | Share |
|---|---|---|---|
| undirected (111 binary terms) | 51 | 20 | 39% |
| directed | 64 | 31 | 48% |
| bipartite-only terms (accepted only on bipartite networks) | 29 | 12 | 41% |
| doc-tagged "bipartite" (R help tag) | 35 | 12 | 34% |

By R's dyad class: dyad-independent 32, nwergm 18 (56%); dyad-dependent 79, nwergm 32 (41%); curved by default 9, nwergm 8 (89%; only `altkstar` is missing).

By category (implemented or partial / total): nodal-attribute covariates 17/34; dyadic covariates 1/3; degree and stars 15/35; curved (GW/alternating) 8/11; shared partners (esp/dsp/nsp, binary) 2/5 (the GW forms are in the curved row); triads/cycles/paths 4/18; dyad-level (edges, mutual, hamming, density, meandeg) 3/5.

Binary model terms not implemented (60, plus `balance`, which is a signed-network term and not planned): `absdiffcat altkstar asymmetric attrcov b1/b2concurrent b1/b2covrange b1/b2degrange b1/b2dsp b1/b2factordistinct b1/b2mindegree b1/b2sociality b1/b2starmix b1/b2twostar coincidence concurrentties cycle degcor degcrossprod degree1.5 density diff dyadcov gwb1dsp gwb2dsp idegree1.5 intransitive isolatededges localtriangle m2star meandeg mm nearsimmelian nodecovrange nodefactordistinct nodeicovrange nodeifactordistinct nodeocovrange nodeofactordistinct nsp odegree1.5 opentriad simmelian simmelianties smalldiff sociality threetrail transitive triadcensus tripercent ttriple twopath`.

The 12 operators not implemented are listed in the CSV. R's `Offset()` is covered functionally by nwergm's `offset(coefname #)` option.

A real nwergm network-type matrix (every term option run on one undirected, one directed, one two-mode network, `nwergm_type_matrix.csv`) agrees with the help text: mode-specific terms are rejected with error 198 on a wrong network type. Differences from R: nwergm rejects `triangle` on a directed network and `transitiveties`/`cyclicalties` on an undirected one, which R accepts (see CSV notes); nwergm accepts `gwdegree` on a directed network, which R refuses.

## (b) Features

| Feature | R ergm 4.12.0 | nwergm (develop) |
|---|---|---|
| MPLE | `estimate="MPLE"`; `MPLE.type` glm / penalized (Firth) / logitreg; existence check via LP (`MPLE.check`); handles curved terms | Yes, via Stata `logit` on a native-built design matrix, also for curved terms (Newton in C). No Firth, no separation check; collinear columns are dropped by `logit` (reported as 0 with SE 0). Dyad-independent models are detected and reported as MLE. |
| MCMLE (Geyer-Thompson) | Default; Hummel et al. 2012 step length, lognormal/`logtaylor`/naive metrics, Hotelling "confidence" and "Hummel" termination, `MCMLE.maxit`, `MCMLE.confidence`, auto-adaptive sample sizes | Yes. Hummel step length (ported and checked against R to <1e-7), joint Hotelling convergence test, adaptive MCMC interval until an effective-sample-size floor is met, `mcmleiterations()`. Newton step on the naive surrogate (no metric options). Starts from MPLE only (no `init`). |
| Stochastic approximation | `main.method="Stochastic-Approximation"` | No |
| Contrastive divergence | `estimate="CD"` | No |
| Non-convergence handling | warnings, `MCMLE.maxit`, fallbacks, `force.main` | `e(converged)`, `e(mcmle_iterations)`; missing e(V) guarded; fits that fail are reported as non-converged rather than silently |
| Variance | Fisher information, MC-corrected (`MCMC.addto.se`), sandwich | MC-corrected inverse covariance with AR spectral (coda-style) correction |
| Simulation | `simulate()` from a fit, formula, or coef, with `constraints`, `basis`, `output=` (network/edgelist/stats), `nsim`, `sequential` | `nwergm simulate N, <terms> theta()` draws `nsim` networks as nw objects from fixed coefficients; full term library; no constraints, no stats-only output, not from a stored fit |
| GOF | `gof()`: degree, ESP, DSP, geodesic, triad census, model statistics, p-values, plots | `estat gof`: mean degree, mean geodesic distance, full triad census, optional degree and geodesic boxplots; no ESP/DSP panel, no model-statistics GOF, no p-values |
| MCMC diagnostics | `mcmc.diagnostics()`: trace/density plots, Geweke, Heidelberger-Welch, ESS | `estat mcmcdiag`: mean, SD, lag-1 autocorrelation, ESS (checked vs coda), Geweke, Heidelberger-Welch, acceptance rate, trace+density plot |
| Constraints | 21 (`edges`, `degrees`, `odegrees`, `idegrees`, `b1degrees`, `b2degrees`, `bd`, `blocks`, `blockdiag`, `fixallbut`, `fixedas`, `observed`, `hamming`, `dyadnoise`, `egocentric`, `degreedist` family, `Dyads`, `ChangeStats`, `I`) | 3: `freedyads(net)` (= `fixallbut`), `blockdiag(var)`, `fixdensity` (= `edges`); one at a time |
| MH proposals | 25 (TNT, randomtoggle, ConstantEdges, CondDegree family, BDStratTNT, SPDyad, HammingTNT, dyadnoise, ...) and `hints` (`sparse`, `strat`, `triadic`) | 2 (uniform, TNT) each with a masked variant, plus a tie/non-tie swap move for `fixdensity`; no hints |
| Sample-size controls | 145 `control.ergm()` arguments | `mcmcburnin`, `mcmcinterval`, `mcmcsamplesize`, `mcmleiterations`, `seed`; adaptive interval |
| Offset / fixed coefficients | `offset()` term wrapper, `offset.coef` | `offset(coefname #)`; not allowed on a curved term's weight/decay |
| Curved ERGMs | `gwesp/gwdsp/gwnsp/gwdegree/gwodegree/gwidegree` curved by default (`fixed=FALSE`), `altkstar`, `gwb1degree/gwb2degree/gwb1dsp/gwb2dsp`; generic `Curve()`; `fixed=TRUE` fixes decay | Fixed decay: `gwesp()` etc. (opposite default to R). Free decay: `gwespfree()`, `gwdspfree()`, `gwnspfree()`, `gwdegreefree()`, `gwodegreefree()`, `gwidegreefree()`, `bgwdegreefree1/2()`, `bgwdspfree1/2()` with MPLE and MCMLE; `structural(altkstar)` (estimated lambda) with `method(mple)` and `init()`; `Curve()` with linear maps (`operators()`) |
| Dyad-independent exact estimation | MPLE = MLE | Same (automatic) |
| Missing data | Missing dyads via `observed` constraint and MCMLE imputation; `obs.*` controls | **None, and silent**: a missing tie in the matrix is treated as no tie and still counted among the dyads; a missing covariate value is treated as 0 (both checked, same coefficients as an explicit 0). No warning. |
| Valued ERGM (ergm.count) | CMP/CMB, Poisson, geometric, `sum`, `nonzero`, ... | Rejected with an explicit error; not planned |
| Temporal (tergm/STERGM) | `tergm()`, `stergm()`, `Form/Diss/Persist/Cross/Change`, edge-age terms | Rejected with an explicit error; not planned. The package has other commands for dynamic data: `nwrem` (relational event model) and `nwdynam`/`nwsaom` (actor-oriented models), which are not ERGMs |
| Model comparison | `logLik` (bridge sampling for dyad-dependent), `AIC`, `BIC`, `anova`, `logLikNull` | **None**: no `e(ll)`; `estat ic` is refused. Wald tests (`test`, `lincom`) work on `e(b)`/`e(V)`. |
| Prediction | `predict()` (conditional tie probabilities, change statistics) | None |
| Convergence/identifiability checks | MPLE existence, nonidentifiability checks (`MPLE.nonident`), `ergm_ignore` | Stata collinearity dropping only |
| Parallel | `parallel=` via snow/PSOCK | None (single thread; native C plugin) |
| Network edits / helpers | `san()`, `ergm.godfather()`, `ergm_state`, `%ergmlhs%`, `network` objects | None; networks come from `nwset`; terms read Stata variables and loaded networks |
| Covariates | any vertex/edge attribute, vector attributes, NA handled by terms | numeric Stata variables only (encode strings first), exact match for categoricals; `edgecov()`/`hamming()` take a loaded network, not a matrix |
| Network types | undirected, directed, bipartite, valued, temporal | undirected, directed, two-mode (undirected, 12-term family); binary only |

**Stata-side extras.** `nwergm` integrates with the `nw*` data model (`nwset`, `nwwebuse`, edge covariates taken from other loaded networks); `e(b)`/`e(V)` support `test` and `lincom`; a dialog box (`nwergm.dlg`); native C MCMC plugin (macOS, Linux, Windows builds in the repo) with a pure-Mata fallback that is always the reference (`nonative` option; `e(native)`); the full range of directed shared-partner definitions (`type(OTP|ITP|OSP|ISP|RTP)`, also available for esp/dsp); `spcache` option; `nomcmcsample`; `estat gof` re-uses `nwgeodesic`/`nwtriads`; a tutorial page in the web documentation.

## (c) Validation status

**Repo certification suite.** All 31 `cscripts/test_nwergm_*.do` files were run from a scratch copy of the develop tree. 30 passed outright; `test_nwergm_ess.do` failed only because the scratch copy has no compiled Mata library and the script starts with `clear all` (missing helper `nw_rows_aligned()`); with `clear all` replaced by `clear` it printed "ALL TESTS PASSED". No assertion failed anywhere. Coverage by file:

- Compared with R-generated constants: `statistics` (observed statistics of edges, mutual, nodematch, nodecov, nodeicov/ocov, edgecov, gwesp, gwdegree/gwodegree/gwidegree on two 5-node networks), `mple` (R MPLE), `mcmle` (R MCMLE on edges+mutual), `ado` (curved MPLE for gwesp with all five directed types, gwdegree, gwdsp, gwodegree/gwidegree), `bipartite` (R MPLE for bcov/bfactor, R MCMLE sign/convergence for bdegree/bstar, R `summary()` for bnodematch/bgwdegree), `constraints` (R `fixallbut` MPLE and MCMLE, `blockdiag` MPLE, `edges` constraint), `curved` (decay map taken from ergm's internal object), `variance` (Statnet reference SEs), `ess` and `estat` (coda ESS, Geweke, Heidelberger-Welch), and a step-length cross-check of the Hummel routine against `ergm:::.Hummel.steplength`.
- Self-consistency only (brute-force change-statistic identity: for every dyad change = difference of full recomputation): `changestat`, `termexpansion1-9`, `demoterm`, `elist`, `spcache`; exact-enumeration check of the sampler on a 3-node graph (`exact_enum`); Binomial check of the sampler (`mcmc`); Mata vs native C equivalence (`native`); `adaptive_interval`, `gof`, `simulate`, `sptype`, `mple_scale`.
- So most term families only have brute-force and a few R-sourced numbers, not a systematic R comparison. This analysis closes that gap for MPLE (below).

**New systematic comparison done here (MPLE on identical data, 78 models).** Three random networks (undirected n=30, directed n=25, bipartite 12 x 10) were generated in R, fitted with `ergm(..., estimate="MPLE")`, and fitted in Stata with `nwergm ..., method(mple)` for 78 single- and multi-term models covering every term option nwergm has (scripts in `xval/`). Results:

- **70 of 78 models agree** (217 coefficients, max |coefficient difference| 4.0e-6, max |SE difference| 5.7e-5); 1 more is within 1.1e-4 (`gwodegreefree`).
- **Differences found:**
  1. `nodemix` on a directed network: nwergm pools (a,b) and (b,a) (6 cells for 3 levels), R keeps ordered pairs (9 cells). Different model, not just a different reference cell. On undirected networks the two are equivalent after re-referencing (nwergm reports 7 columns, one aliased to 0 with SE 0; R drops the first cell).
  2. `gwdegree` is accepted on a directed network by nwergm; R refuses it. No R counterpart to compare with.
  3. Curved (free decay) MPLE on weakly identified data: `gwespfree` (directed OTP), `gwidegreefree`, `gwdspfree`, `gwnspfree` give different end points than R. In each case both sides end at a boundary solution (R decay about 1e-12, nwergm at its lower bound 1e-6), so the likelihood surface is flat and the two optimisers disagree. Where the data identify the curve (`gwespfree`, `gwdegreefree` undirected) the fits agree to 2e-8 and 4e-6.
  4. RTP: R 4.12.0 returns wrong `gwesp(type="RTP")` values by default (statnet issue #656, fixed in 4.13); nwergm matches R when R is run with `term.options=list(cache.sp=FALSE)` (agrees to <1e-7). The repo test comments already record this.
  5. Perfectly separated or empty levels: R reports `-Inf`/`NA`, nwergm reports 0 with SE 0 (`idegree`, `sender`).
- **MCMLE (3 models, 3 seeds each, same data, `timing/se_*.csv`)**: nwergm and R agree on coefficients within Monte Carlo noise (means over 3 seeds, nwergm vs R, directed edges+mutual+nodematch: edges -3.245 vs -3.255, mutual -0.44 vs -0.44, nodematch 0.645 vs 0.65) and on SEs to about 10% (gwesp SE, nwergm vs R: 0.095 vs 0.096 at n=100; 0.060 vs 0.055 at n=400). nwergm needed 1-2 iterations where R needed 1-6 (up to 6 at n=400).
- **Curved MCMLE (gwespfree vs `gwesp(fixed=FALSE)`, n=400, 3 seeds)**: coefficients agree within noise (edges -4.87/-4.88, nodematch 0.39-0.43, gwesp weight 0.53-0.56); decay 0.49-0.79 in nwergm vs 0.48-0.57 in R (R's own SE for the decay is about 0.85). R needed 4-44 iterations (4-52 s); nwergm 1-2 iterations (0.8-2.8 s).

**Gaps in validation.** Directed `esp/dsp` forms are only checked for OTP in the new comparison (other types only for gwesp); no R comparison of `estat gof`; no R comparison of MCMLE for constrained models beyond the one small network in the repo; no R comparison for `offset()` in this analysis; no R-based check of `nwergm simulate` distributions; large-network MCMLE SE accuracy is only compared on the three models above.

## (d) What is missing, by priority, with difficulty

Priority is my judgement of how much a user of ERGMs would be stopped by the gap.

| # | Item | Difficulty | One-line reason |
|---|---|---|---|
| 1 | Missing-data handling: error/warning for missing ties and covariates | easy | Detect in the bridge and stop or drop; today it is silent |
| 2 | Log-likelihood, AIC, BIC, LR tests for dyad-independent fits | easy | The `logit` log-likelihood already exists; post `e(ll)`, `e(ll_0)` so `estat ic` works |
| 3 | Log-likelihood for dyad-dependent models (bridge sampling) | medium | Needs path sampling from the null model with the existing sampler plus a log-likelihood accumulator |
| 4 | Fix directed `nodemix` (ordered pairs) and add `mm()` | easy-medium | Change statistic needs an ordered cell index; reference-cell choice as in R |
| 5 | Directed `triangle` and other terms R accepts on both types (`transitiveties`, `cyclicalties` on undirected) | easy | Same change statistic with a type switch |
| 6 | Cheap missing terms: `density`, `meandeg`, `twopath`, `sociality`, `nsp(d)`, `nodefactordistinct`/`*covrange`, `diff`, `smalldiff`, `absdiffcat`, `asymmetric`, `transitive`, `intransitive`, `ttriple`, `opentriad`, `threetrail`, `concurrentties`, `degree1.5` family | easy | Closed-form or local change statistics on structures that already exist |
| 7 | `altkstar` and `gwb1dsp`/`gwb2dsp`, curved bipartite terms | medium | Same curved-map machinery as the gw*free terms, new change statistic |
| 8 | `predict` (conditional tie probabilities) | easy-medium | Reuse the MPLE design-matrix builder |
| 9 | Richer GOF (ESP/DSP, model-statistics GOF, p-values, `estat gof` by term) | easy-medium | Statistics exist in the term library; add summaries |
| 10 | `simulate` from a fitted model; constraints in `simulate`; statistics-only output | medium | Reuse the fit's stored model and constraint masks |
| 11 | Degree constraints (`degrees`, `odegrees`, `idegrees`, `b1/b2degrees`, `bd`) | hard | New compound-move proposals (CondDegree family) in Mata and C |
| 12 | Combined constraints (e.g. `blockdiag` with `fixdensity`) | medium | Compose masks with the swap proposal |
| 13 | Simmelian/local-triangle/triad-census/`degcor` terms | medium-hard | Larger neighbourhood update rules, plus C ports |
| 14 | Separation/non-existence check and Firth-penalised MPLE | medium | LP-based existence check or penalised likelihood in the MPLE step |
| 15 | Contrastive divergence; stochastic approximation | medium | New estimator loops on top of the sampler; R's versions are the reference |
| 16 | `init`/starting values and `target.stats` | easy | Pass through to the Newton loop |
| 17 | Parallel chains | medium | Needs multi-threaded plugin; Stata has no process-level parallelism |
| 18 | Missing-data estimation as in R (`observed` constraint plus imputing MCMLE) | hard | New estimator branch and proposals restricted to unobserved dyads |
| 19 | Curved MCMLE parity (convergence/test agreement with R) | medium | Works in practice (see above); formal agreement not yet shown |
| 20 | `by=`/`levels=`/`attr=` arguments on degree, star, nodematch, triangle terms | medium | Per-level sub-statistics; many terms |
| 21 | Valued/count ERGM (ergm.count) | hard | A different statistical framework; documented as not planned |
| 22 | Temporal ERGM (tergm/STERGM) | hard | Separate framework; documented as not planned |

## (e) Speed

Machine: 18 cores, load average between 2.2 and 4.5 during all runs (other jobs, one Stata and one R process at about 100% CPU each, were running throughout); a quiet-machine claim cannot be made. Single thread on both sides; R: default `ergm()` controls (MCMC interval 1024, 1024 draws), `system.time` around the `ergm()` call, 3 runs; Stata: `timer` around `nwergm` with defaults (interval 50, 3000 draws, native C plugin in use for all four), 3 runs. Same networks and covariates (edge lists in `timing/`), network setup excluded on both sides.

| Model | R median (runs) | nwergm median (runs) | Comment |
|---|---|---|---|
| T1 directed n=100, edges+mutual+nodematch, MCMLE (465 ties) | 0.90 s (0.62-1.82) | 2.39 s (2.30-2.84; later re-run 1.5-2.3) | R faster here; nwergm needed 1 iteration |
| T2 undirected n=100, edges+nodematch+gwesp(.5), MCMLE (212 ties) | 1.00 s (0.50-1.13) | 0.46 s (0.46-0.46) | nwergm about 2x faster |
| T3 undirected n=300, edges+nodematch+nodecov, dyad-independent | 0.06 s | 0.087 s | both effectively instant; R slightly faster |
| T4 undirected n=400, edges+nodematch+gwesp(.5), MCMLE (820 ties) | 2.66 s (1.91-4.21) | 0.64 s (0.59-0.88) | nwergm about 4x faster |
| Curved gwesp, n=400 (see (c)) | 3.9-52 s | 0.8-2.8 s | R needed 4-44 iterations |

Caveats: the settings differ (R's longer chains vs nwergm's shorter ones with adaptive thinning), nwergm usually stops after one iteration and applies its own convergence rule, run-to-run variation is large on a loaded machine (R's own timings spread 3x), and three or four runs are not a benchmark. The help text of nwergm states ratios (for example 0.62x of R for a 100-node directed edges+mutual+nodematch model); this analysis did not reproduce that ratio for T1 (nwergm was slower here, with `nonative` it was 3.3-6.0 s). Treat all of this as indicative.

## Scripts and how each number was produced

- Term list and classes: `r_terms.R` / `r_term_types.R` / `r_term_class.R` (R: `ergm:::ergmTermCache`, `summary()` on test networks, `ergm_model()` + `is.dyad.independent()`/`is.curved()`), `r_dyadind.R`.
- R feature lists (constraints, proposals, controls, hints): `r_features.R`.
- nwergm network-type matrix: `typematrix.do` (55 term-option calls x 3 networks).
- Inventory and percentages: `build_inventory.py`, `count_terms.py` (output `term_counts.txt`).
- Cross-validation: `xval/xval_gen.R`, `xval/xval_run.do`, `xval/xval_compare.R`, driver `run_xval.sh`; results `xval/xval_summary.csv`.
- Certification suite: `run_cscripts.sh` (logs in `cscript_logs/`, tallies in `cscript_summary.csv`).
- Timing and MCMLE/SE comparison: `timing/time_gen.R`, `time_r.R`, `time_stata.do`, `se_r.R`, `se_stata.do`, `curved_r.R`, `curved_stata.do`.
- Misc checks (missing data, `estat ic`, `predict`, unsupported options): inline Stata runs, logs not kept.


## (f) Update (branch `operators`): operators, balance, altkstar, curved two-mode terms

Recount with `dev/update_inventory.py` (it rewrites `ERGM_TERMS_INVENTORY.csv` from the option names in `nwergm.ado` and the tests in `cscripts/`): of the 139 ergm terms,
**123 IMPLEMENTED, 2 PARTIAL (`altkstar`: estimated lambda for `method(mple)` with `init()` only; `Curve`: linear maps only), 0 NOT IMPLEMENTED, 14 NOT PLANNED = 125 of 139 (89.9%)**.
The 14 are `B` and the 13 valued-only terms (`atleast atmost cdf cyclicalweights equalto greaterthan ininterval nodecovar nodeicovar nodeocovar smallerthan sum transitiveweights`),
which R itself refuses on a binary network: of the 126 terms that can be used on a binary network, 125 are covered (99.2%). Sections (a) to (e) above describe the state of 2026-10-23.

What was added and how it was checked against R ergm 4.12.0 (generators in `dev/`, tests in `cscripts/`):
- Operators `Sum Prod S F NodematchFilter Symmetrize Project (Proj1 Proj2) I For Label Log Exp Offset Curve` (option `operators()`, `help nwergm_operators`): `test_nwergm_ops` (94 comparisons: observed
  statistics, MPLE coefficients and standard errors, MCMLE for six models, on random and real undirected, directed and two-mode networks) and `test_nwergm_ops_native` (plugin change statistics against brute force).
- `balance`: `test_nwergm_balance` (statistic, MPLE, MCMLE).
- Curved two-mode terms `gwb1degree gwb2degree gwb1dsp gwb2dsp` (fixed = FALSE): `test_nwergm_bipcurved` (MPLE to 1e-6, MCMLE for the degree terms; the degree counts of the MCMLE now run over all possible degrees).
- `altkstar` with an estimated lambda: `test_nwergm_altkstar` (map and gradient; MPLE from given starting values on four networks, four starting values each, to 1e-5); `init()` for the other curved terms is checked too.

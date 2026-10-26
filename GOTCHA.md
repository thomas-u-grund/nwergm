# Gotchas of nwergm

Known, already diagnosed pitfalls. Entries copied from the nwcommands notes at the time of the split; some mention the core package.

## Mata libraries must be built with the OLDEST supported Stata (Stata 17), never a newer one

The 2026-10-25 releases (core 3.5.0, nwsaom 1.0.7, nwergm 1.2.0, nwdynam 1.1.0, nwrem 1.0.5) shipped `.mlib` files built with Stata 18.
A Stata 17 user got `nwwebuse florentine` -> `<istmt>: 3499 nws_create() not found`, even from a clean install: Stata 17 lists the
library (`mata mlib query`, `mata describe using lnwcommands` work) but silently ignores its contents. The only trace is
`mata which nws_create()`: "(nws_create() in lnwcommands, compiled by Stata 18.0, is too new to be run by this version of Stata and so
was ignored)". The reverse is fine: Stata 18 reads libraries built by Stata 17. So build with the oldest supported Stata (currently 17).
`lib/build.do` of every package stops when `c(stata_version)` is higher than 17 (`NW_ALLOW_NEWER_STATA=1` overrides, for libraries that
are never released). The only reliable check of a release candidate is to run a
command in Stata 17 against the built library. The core has `_nwlibcheck.ado` (called by `unw_defs` and the commands that do not call it) which turns the
failure into a readable message with exit 3499. An OLD library in the user's PLUS folder (for example from a Sep 2026 install) shadows
the new one and gives r(3021) or other class errors; the message tells the user to `ado uninstall nwcommands` first.

## Attaching a covariate to an `eventtime()`-declared network needs `_nwnode`, not a fresh merge

After `nwset sender receiver, eventtime(t) name(netname)` declares an event network (found while
building the `socialevolution` example dataset, 2026-09-12), the dataset left in memory is **not**
the original sender/receiver/t rows anymore — it's one row per actor who appears in at least one
event, with columns `_nwnode` (the actor's own label) and `_nwinclude`. A `merge 1:1 label using
covariates.dta` fails outright (`variable label not found`) because there is no `label` variable to
merge on at that point; the actor identifier is `_nwnode`.

The fix is a rename-merge-rename:

```
rename _nwnode label
merge 1:1 label using covariates.dta, keep(master match) nogen
rename label _nwnode
```

This is unrelated to how covariates work on an already-`nwsave()`d panel dataset (`glasgow`, `s50`,
etc.), where attributes like `smoke1`/`alcohol1` are baked into the saved network file itself and
just show up as ordinary variables on load — no merge needed there at all. The rename-merge-rename
dance is specific to attaching a covariate *after the fact* onto a freshly `nwset`-declared event
network built from a plain, not-pre-declared dataset.

## `nwergm` MCMLE standard errors: the autocorrelation factor goes on the Monte Carlo error, not the information (fixed 2026-09-30)

`ErgmMCMLE()` (unw_ergm.do) estimates the Fisher information as `V = variance(samp)`, the covariance
of the statistics simulated at the final theta. It used to multiply `V`'s diagonal by the AR(p)
spectral inflation factors (`infl`) and then report `invsym(V)`. Inflating the *information*
shrinks every standard error by `sqrt(infl)`, and the worse the chain mixes, the larger `infl`
gets, so the SEs shrank most exactly where they should be widest. On the 5-node certification network
in `test_nwergm_mcmle.do` the chain mixes almost perfectly (`infl` about 1), so it passed and the
bug went unnoticed. On real models it was drastic. Checked against R `ergm` 4.12:

| model | nwergm before | nwergm after | R ergm |
|---|---|---|---|
| florentine `edges gwesp(.5) nodematch(seat)`, edges SE | .181 | .450 | .45-.48 |
| glasgow1 `edges mutual nodematch(smoke1)`, edges SE | .0067 | .199 | .206 |
| mesa `edges gwesp(.25) nodematch(grade race)`, edges SE | .0012 | .176 | .155 |

Now `vcov = Vinv + Vinv*(S/n)*Vinv` with `S = D*V*D`, `D = diag(sqrt(infl))`: the model variance plus
the MCMC error of the estimate, as R `ergm` reports by default. **Lesson:** a certification test on a
network where a correction factor is about 1 cannot detect that the factor is applied in the wrong
place. Validate variance code on at least one sticky, realistic chain.

## `nwergm` node-attribute terms silently mis-read string variables (fixed 2026-09-30)

Every node-attribute term reads its variable with Mata's `st_data()`, which returns missing values
for a string variable, with no error. For `nodematch()`, missing == missing for every pair, so the
term became an exact copy of `edges` (coefficient 0, a "rank k-1 of k" warning every iteration,
and a meaningless fit). All 32 attribute-read sites (estimation and `simulate`) now go through
`_nwergm_numvar`, which stops with r(109) and suggests `encode`. Proper string support (with
readable level names in `nodefactor`/`nodemix` coefficient names) would be a feature, not a fix.

## `lib/build.do` and `deploy_nw_build.do` hardcode the checkout path

Both `cd` into `/Users/tgrund/FILES_NEW/SOFTWARE/nwcommands` by absolute path. Run from a git
worktree or any other copy, they silently rebuild the *main checkout's* mlib instead of the one
you are working on. From a worktree, build with a copy of `lib/build.do` whose paths point at the
worktree.

## `nwergm` estat mcmcdiag ESS was overstated; estat gof chains too short (changed 2026-10-01)

`estat mcmcdiag` computed ESS as n(1-rho1)/(1+rho1), which assumes geometric decay of the
autocorrelation. ERGM chains on sparse networks decay much more slowly (Faux Mesa High: lag-1 0.86,
lag-10 still 0.62), so ESS was overstated severalfold (472-539 reported, 262-318 true). It is now
coda's `effectiveSize()`, n*var(x)/spectrum0.ar(x) via `ergm_spec0_scalar()`, and is returned as
`r(ess)` (checked against coda in `cscripts/test_nwergm_ess.do`). `estat gof` used a fixed
3000/50 burn-in/interval and 50 draws regardless of the fit; on slowly mixing models its simulated
averages then drifted with the seed (mean degree 2.25-2.41 vs observed 1.98). Defaults now follow
R's `gof.ergm()`: 100 draws and the fit's `e(mcmc_burnin)`/`e(mcmc_interval_final)`. Even so, such
models vary from seed to seed in R too (same theta: mean degree 1.97-2.12 over 4 seeds).

## A stale installed plugin in PLUS shadows the repo's freshly built native plugin

`findfile()` finds `saom_sim_macos.plugin` (and the other native plugins) in the user's
`~/Library/Application Support/Stata/ado/plus/s/` ahead of `lib/plugins/<platform>/`. After
`make macos-saom_sim` a Stata test can keep running the OLD binary. Don't overwrite the user's
installed copy; copy the new plugin into a scratch dir and `adopath ++ <that dir>` at the top of the
test do-file. `lib/plugins/unix` and `lib/plugins/windows` are built by CI and are stale locally
until it runs.

## A Mata `external` declaration CREATES the external

`external real scalar x` at the top of a function creates `x` (missing) if it does not exist, so a following `findexternal("x") == NULL` test is never true. To test for an optional
external use `pointer(real scalar) scalar p; p = findexternal("x")` without a declaration. (2026-10-23: `SaomBatchSlotTag()` declared `__saom_bslot`, returned "." and every
batch setup sent `BATCHSETUP.|...`, which the plugin sent to its legacy parser: the whole co-evolution suite hung at 100% CPU.) A struct used in a function must be defined EARLIER in the file.

## Copying a rebuilt plugin over a loaded one kills Stata with no message (macOS)

Symptom: `cp new.plugin scratch/lib/plugins/macos/saom_sim_macos.plugin` over an existing copy, then the next
Stata run simply ends in the middle of a command - no error, no `end of do-file` in the log. The crash report
in `~/Library/Logs/DiagnosticReports/StataBE-*.ips` says `SIGKILL (Code Signature Invalid)`.
Cause: macOS caches the code signature of the file; overwriting it in place leaves a stale signature.
Fix: `rm` the old file first, then `cp` (or `cp` to a new name and `mv`). Applies to every scratch directory used for testing.
This is a deliberate
divergence, decided 2026-10-01: the RSiena default looks like a bug (introduced in 1.6.1, commit
1155e31, which moved only outPop/inAct to default 1 and left outPop.c, outPopSqrt, outPopMore,
outPopSqrtMore, outPopThreshold, inAct.c, inActSqrt at 0) and was reported as
https://github.com/stocnet/rsiena/issues/151. Do NOT "fix" nwsaom to match RSiena's default; when
validating against RSiena, set parameter = 1 for these effects. Revisit if the issue is resolved.

## Mata functions and programs defined inside an .ado file are private to that file

`mata: nwergm_estat_bridge_from_netobj(...)` called from a *different* .ado file fails with "not found" (3499): functions
(and `program`s) defined in an .ado are namespaced `file.name` and only callable from programs of the same file. Anything two
helper files need (observed-network bridge, summary functions) belongs in `unw_ergm.do` (the Mata library), as
`ergm_bridge_obs()`. Likewise `estat gof` plots call `_nwergm_gofplot`, a file of its own.

## Stata `syntax` flag options that start with "no" lose the prefix

`syntax [, NOMPLECHECK]` creates the local `mplecheck`, not `nomplecheck`; testing `"`nomplecheck'" == ""` is then always true.
Use a string option (`mplecheck(on|off)`) or a name that does not start with "no".

## R ergm 4.12.0 and the development 4.13 differ in `spectrum0.mvar()` (mcmc.diagnostics, Hotelling tests)

4.12.0 fits a multivariate Yule-Walker AR (`ar()`), 4.13 an OLS VAR (`fit_var_ols_multi`); the Hotelling omnibus p-values and the
joint Geweke p-value differ in the 2nd-3rd digit between the two. `unw_ergm.do` follows 4.12.0 (`ergm_spec0_mvar()`, checked to 1e-8
against 4.12.0 on a fixed sample in `cscripts/test_nwergm_est.do`). Also: in 4.12.0 `MPLE.type="penalized"` stops with "'length = 3' in
coercion to 'logical(1)'" (R >= 4.3); fixed in 4.13 (`anyNA(start)`), which `ergm_pen_glm()` reproduces.

## `nwergm ... , simulate` must be recognised before the comma

`nwergm simulate, nsim(5)` has `simulate,` as its first blank-delimited token; the dispatcher compares the first token parsed with
`parse(" ,")`. Testing `"`1'" == "simulate"` never matched when a comma follows directly.


## Operators: R ergm 4.12.0 builds the symmetrized network of `Symmetrize(rule="weak")` without the reciprocated pairs when it starts a fit (found 2026-11-01)

`summary(nw ~ Symmetrize(~triangle+kstar(2), rule="weak"))` is right, because R adds the arcs one by one through the update function. `ergm()` and
`ergmMPLE()` start from the observed network, and the auxiliary network is then filled with the initialisation macro `__undir_net_totoggle`, which for the rule
`weak` is "toggle unless the reverse arc exists": every reciprocated dyad is missing from the symmetrized network the MPLE change statistics are computed on
(108 of 182 change statistics differed from brute-force differences of `summary()` on a 14-node directed network; the rules strong, upper, lower agree exactly).
nwergm computes the exact change statistics, so its `rule(weak)` MPLE equals R's only on a network without reciprocated ties. `cscripts/test_nwergm_ops.do`
therefore compares `rule(weak)` on networks with reciprocated ties with a pseudolikelihood fitted to R's own `summary()` differences (generator `dev/gen_test_ops.R`, `brute = TRUE`),
and on a network without reciprocated ties with `ergm(estimate = "MPLE")` itself. Do not "fix" nwergm to reproduce R's initial network.

## R computes `Prod()` statistics as `Exp(Sum(Log))` with log(0) = -1/sqrt(eps); its own summary() is only exact to about 1e-8

Built up edge by edge from the empty network, the statistic passes through values of about 6.7e7 and loses 8 digits (mesa: 522.48718785 in R, exactly 522.48719458 = (3491*659*62)^(1/3)
in nwergm). The Prod rows of `test_nwergm_ops.do` use the tolerance 1e-6 for the statistics for this reason; the MPLE coefficients agree to 1e-5.

## An ado-file's other programs are private to that file

`_nwergm_numvar` is defined at the end of `nwergm.ado` and cannot be called from `_nwergm_ops.ado` ("command _nwergm_numvar is unrecognized"), although it works inside `nwergm`.
A helper that several files need has to be a file of its own, or be repeated (the operators check numeric attributes with their own few lines).

## Mata at the command line cannot copy class instances

`mata: B = A` for a class instance A fails with "transmorphic = class not allowed", and `class T scalar x` is not accepted as a declaration there. Inside a function `b = a`
copies the instance (value semantics, the pointers inside are shared), and an argument written `*p` is passed by reference. `unw_ergm.do` therefore has `ergm_ops_copyM/copyG`
(typed arguments) for the places where `_nwergm_ops.ado` has to save and restore `__nwergm_last_M` and `__nwergm_last_G` around a model-building call of `nwergm`.
Also: `template` is a reserved word in Mata, and `mata:` blocks cannot be nested in a `forvalues` loop of a do-file (the batch run stops with --Break--): repeat the statements.

## The operators run in the native plugin only; a changed plugin has to be rebuilt for every platform

`native/ergm_mcmc.c` now evaluates composite columns and derived networks (`TERMCODE_COMP`, contexts 1-4). The macOS plugin in `lib/plugins/macos` was rebuilt here;
`lib/plugins/unix` and `lib/plugins/windows` have to be rebuilt on a Linux and a Windows host (`make -C native unix`; Windows: see native/Makefile) before a release.

## `seed()` did not reproduce a fit across sessions: the neighbor order of the core is not stable (fixed 2026-10-24)

`nwergm ..., seed(1)` draws the plugin's RNG seed from Mata's `runiform()` right after `set seed`, so the
stream was always deterministic. The fit still differed between do-files (`edges` -3.375 vs -3.325 on Lazega
with the same data and seed) because the starting network is built with `G.toggle()` in the order of
`netobj->neighbors(i)`, and the core returns the neighbors of a node in a different order once another
network has been loaded in the session. The MCMC proposal picks "the k-th edge" of that edge list, so the
chain changed. The bridge functions (`ergm_bridge_from_netobj`, the copy in `nwergm_estat.ado`,
`ergm_bridge_obs`, `ergm_netobj_to_graph`) now sort the neighbors. Found by printing the plugin argument
string (identical seed and theta) and a checksum of the edge list (different). **Lesson:** when a seeded
stochastic fit differs, compare the inputs of the sampler (edge order), not only the seed. Test:
`test_nwergm_seedrepro`.

## `mata mlib index` does not persist: a library installed by net install can be missing from a session's Mata library list

Stata builds its list of Mata libraries (.mlib) once, early in a session; `mata mlib index` rebuilds it for the running session only
and nothing is saved. A library that `net install` put into PLUS/l/ can be absent from the list (`mata mlib query` shows `lnwcommands`
but not `lnwergm`). The first Mata call then stops with r(3499) "<function>() not found", and a Mata block that mentions a class of
the library stops the whole ado file with r(3000) "class ... undefined (error occurred while loading ...)". Running `mata mlib index`
by hand "fixes" it for that session only, which hid the bug in every manual test.
- Every entry program starts with `_nwergm_libcheck` (which runs `mata mlib index` once when a library function is not visible); do not
  call Mata before it.
- A **file-scope** `mata:` block in an .ado file is compiled when the file is auto-loaded, i.e. before any program of the file runs:
  `_nwergm_libcheck` is therefore also called at file scope (`capture quietly ...`) in front of such a block.
- Reproduce: `SMOKE_STALE=1 tools/smoke_fresh_install.sh <core> <models>` in the core repo builds exactly this state (the session's Mata
  index is made while only the core library is visible). Without `SMOKE_STALE` a plain new session usually finds all libraries,
  which is why a simple "install, restart, run" test passes.

## The default of `mcmcburnin()` is derived from `mcmcinterval()` (R: `MCMLE.burnin = MCMLE.interval * 16`)

In `nwergm.ado` the syntax line declares `MCMCBURNIN(integer -1)`: -1 means "not given", and the program then sets
`mcmcburnin = 16 * mcmcinterval` (same in `nwergm simulate`). So the burn-in default is 16384 only while the interval is
1024; `mcmcinterval(100)` alone gives a burn-in of 1600. Do not put a literal number back into the syntax line, and do
not read `mcmcburnin` before the derivation line right after `set more off`. The dialog hints, `nwergm.sthlp` and
`cscripts/test_nwergm_rdefaults.do` state the defaults; change all four together. The old (pre-1.2.0) fast settings are
`mcmcburnin(3000) mcmcinterval(50)`; tests that need a small, quick chain name their MCMC options explicitly.

## `nwset ... edgelist` makes a DIRECTED network unless you say `undirected` (benchmarks and loaders)

`nwset ego alter value, edgelist name(x)` with an edge list that holds each undirected edge once (upper triangle) creates a directed network. In the
timing scripts of the SJ article (`rcheck/bench_nwergm.do`, 2026-10-26) the undirected benchmark networks (100-node `gwesp`, 500-node, 1000-node sparse
`gwesp+gwnsp`) were therefore fitted as directed networks (`gwesp` then means OTP, the model is a different one), while R fitted the undirected model:
the "74.5 s" of the sparse model is the directed model; the undirected one takes about 18 s in 1.2.3. Always pass `directed` or `undirected` in a loader
and check `e(directed)` and `e(ties)` of the first fit against R.

## The native plugin publishes its generation; Mata sizes the frame from it (speed130)

`ergm_mcmc` sets the Stata scalar `__ergm_native_gen` on every call (2 since the speed work). With generation 2 the sampler writes the final network only if it
fits the frame it was given (`SF_nobs()`) and otherwise just reports `__ergm_native_nties_out`; `ErgmNativeSampleCore()` then enlarges the frame and repeats the
call (same seed, same result). A plugin of generation 1 (1.2.3 and earlier, or the first call of a session) is given one row per dyad as before, so an old
binary next to new Mata code is correct, only slower. Traps: `st_numscalar()` of a scalar that does not exist returns an empty matrix, not a missing value
(`gen < .` then fails with 3200 conformability); a plugin binary is only replaced after `rm` (macOS code-signature kill); the Linux and Windows binaries
change only after a push (CI), so test with the old binary too (`git show <tag>:lib/plugins/macos/ergm_mcmc_macos.plugin`).

## G is stale while native runs hand the network on as a tie list

In the adaptive MCMLE loop and in the bridge sampling (carry) the network travels between native runs as a plain tie list (`tiesin`/`tiesout` of
`ErgmNativeSampleCore()`); the Mata `ErgmGraph` (asarray adjacency, about 45 ms to rebuild for 1000 nodes and 6000 ties) is rebuilt once at the end by
`ergm_graph_load_ties()`. Code inside those loops must not read `G` (full statistics are carried as the last row of the previous sample instead). An error
in the middle leaves `G` out of date; the next `nwergm` call builds a new graph anyway.

## Plugin: the GW kernel table must survive `ops_free()`

`gw_kernel()` reads a table of the kernel for the counts 0..n+1 (built with the same expression as before, so results are bit-identical). The table is created
per decay value and released by the next call's `gwk_reset()`. `ops_free()` runs in the middle of the setup of every call; when it also reset the table, the
kernel silently fell back to `pow()`/`exp()` for every proposal (25% slower, no error). Profile with `sample <pid> 5` while a long run is going: `pow` and `exp`
near the top of `libsystem_m` mean the table is not in use.

## `ergm_mple_irls()` declined large designs because of an absolute 1e-9 check

The check "the log-likelihood must not decrease" used an absolute 1e-9; for 500,000 or more dyads the rounding noise of the sum is larger than that, the
function returned 0 and `nwergm` fitted the MPLE with Stata's `logit` on a dataset of all dyads (1.3 s for 1000 nodes). The check is relative now, and a design
with few distinct rows is compressed (`ergm_mple_compress()`, weighted likelihood; `uniqrows()` takes 0.17 s for 1,000,000 rows).

## Fits with the adaptive sample are as noisy as R's

With the target effective size 64 the coefficients scatter between seeds like those of R (about 0.03-0.05 standard errors at the Monte Carlo level), so a test
that compares one seed to an R value needs a tolerance of about 0.3 standard errors. Tests of fixed-size behaviour (`test_nwergm_ess`, `_estat`, `_rdefaults`) use
`mcmleeffectivesize(0)`.

## Mata `symeigensystem()` returns missing values for a matrix whose eigenvalues are all equal

Found while porting R's tolerance-region test (`ergm_ellipsoid_mahalanobis()`): `U^(-1/2) W U^(-1/2)` was a multiple of the identity (the tolerance matrix is a multiple of the
covariance matrix), and `symeigensystem()` returned all-missing eigenvalues for it even though the input was symmetric and finite (rounding noise in the off-diagonal, about 1e-16).
`eigenvalues()` (general matrix, complex result) works; take `Re()`. Also: `symeigensystem(A, X, L)` needs `X` and `L` to exist when called from an interactive `mata:` block, and in a
function `{ stmt; continue }` on one line is a syntax error (use separate lines).

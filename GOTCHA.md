# Gotchas of nwergm

Known, already diagnosed pitfalls. Entries copied from the nwcommands notes at the time of the split; some mention the core package.

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


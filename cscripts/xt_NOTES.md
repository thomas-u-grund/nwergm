# Extended nwergm tests (xt_*.do): notes

Status: DRAFT, none of these files has been run. Written against nwergm 1.5.12 (branch tests-extended off main).
Reference values come from R ergm 4.12.0 / network 1.20.0 or from hand derivations (closed forms stated in the
files). Hand formulas were cross-checked against R (max difference 2e-13). A number without either source is a
`* TODO-R:` with the assert commented out.

Conventions: runs from the repository root; no sysdir/adopath lines (the runner adds them); Stata 17 syntax; every
block ends with a `di "PASS ..."` line, every file with `di "ALL PASS"`. Lines starting `SOFT` print a value without
asserting it (behaviour not yet decided).

## Files

| File | Coverage | Runtime |
|---|---|---|
| xt_stats_undirected.do | every undirected term's e(obs_stats) vs R on a 7-node network with an isolate; decays 0/.5/1/10/30/40/100; edgecov/hamming; near-empty/near-complete; empty/complete -> r(2000) with data restored; valued ties fitted as binary; florentine vs R; missing attribute -> 416 | 1-2 min |
| xt_stats_directed.do | every directed term vs R; all five shared-partner types (esp/dsp/gwesp/gwdsp/gwnsp), default and lowercase type; sender/receiver; near-complete | ~1 min |
| xt_stats_bipartite.do | 4x5 two-mode network with an isolate in each mode: all b-terms and the one-mode terms R allows; refusals 198 on both shapes | ~1 min |
| xt_stats_longmodel.do | 80-node model with ~80 columns (50 nodecov, 10-level nodefactor, degree/kstar/esp/dsp ranges, edgecov, hamming, gwesp) checked by Mata hand counts and vs nonative; 40-node directed with 40 covariates; varlist ranges, expressions, 32-char names; fewer data rows than nodes | 1-3 min |
| xt_mple_crossroute.do | MPLE vs R (b, SE) and vs logit on hand-built change statistics; offset(); estat ic arithmetic; edges-only closed form; missing dyad (e(N), e(nmissing)) | ~30 s |
| xt_mcmle.do | MCMLE within 0.5 SE of closed-form MLEs (edges+mutual, offset(mutual 1), edges only); seed() bit-identical after other work; 1x1 matrices in mcmcdiag/gof/ic; options stored in e(); init(); constraints(edges)/fixdensity; CD, SA, curved | 1-2 min |
| xt_invariance.do | permutation invariance of stats, b, V, ll, predict and gof observed columns; edge list with name-sorted nodes; lazega stored vs natural order | 30-60 s |
| xt_postest_shapes.do | estat gof / simulate / predict on undirected, directed and bipartite fits; hand-checked gof observed values (mean degree, triad census, dsp sums); p-values in [0,1]; boundary coefficients +-50; constraints kept by simulation; refusals 198/111/498 | 1-2 min |
| xt_errors_state.do | ~40 refusals with exact r() codes, each followed by a check that e(b)/e(V)/e(cmd), the data signature and the network are unchanged; 301 without estimates; r() kept through plots; two state-leak tests (expected FAIL) | ~1 min |
| xt_tiny.do | 2- and 3-node networks, 1x2 two-mode, single-column terms, one free coefficient, simulate with 1-6 nodes and boundary theta | ~30 s |

Total: about 10-15 minutes under Stata 17.

## Tests expected to FAIL now (suspected bugs)

1. `_nwergm_fitstats.ado:48-67`: `e(predict)` is set only after `if missing(ll) exit`, so `predict` fails after a
   `nologlik` fit (xt_mcmle.do, "predict after nologlik"). The curved-model refusal also comes from Stata's default
   predict, not a nwergm message.
2. `nwergm.ado:617-622, 833, 3020, 3805-3833`: `nwergm simulate N, ...` and refused nwergm calls overwrite the Mata
   globals `__nwergm_last_M` / `__nwergm_last_G` while `e()` still holds the earlier fit. `estat gof`
   (`_nwergm_gof.ado:16`), simulate-from-fit (`_nwergm_simfit.ado:18`) and `predict` then use the wrong model
   (xt_errors_state.do, two state tests).
3. `_nwergm_cov.ado:158-187` (`_nwergm_covattr`): no varlist expansion. `nodeocov(o1-o3)` or `x*` reach `st_data`
   as several columns, and `count if missing(o1-o3)` is read as a subtraction. `in 1/nodes` gives r(198) when the
   dataset has fewer rows than nodes (xt_stats_longmodel.do).
4. `_nwergm_simfit.ado` edge-list branch / `unw_ergm.do:5955`: when all draws are empty the 0x3 edge list may not
   create a Stata matrix, so `matrix EL = __simE7_el` fails (xt_postest_shapes.do, theta -50 with output(edgelist)).

## Code vs R or help mismatches (recorded, mostly SOFT)

- `_nwergm_gof.ado:29-35`: default gof interval after MPLE is `ceil(1024/nsim)`. R gof.ergm uses
  1024 * EVL(samplesize/nsim, 1) and `fit$control$MCMC.samplesize` is NULL after MPLE, so R uses 1024 (confirmed in R
  4.12.0; after MCMLE R gives 512 with the default sample size 256). SOFT in xt_postest_shapes.do.
- `nwergm.ado` ~548: `triangle` on a directed network is refused (198); R accepts it (= 5 on network D). At least
  the message should point to `structural(triangle)`. SOFT in xt_stats_directed.do.
- `nwergm.ado:135,143`: invalid `proposal()` / `type()` give r(6556) via `_opts_oneof`; other option errors give 198.
  The tests assert 6556 as current behaviour.
- `nwergm_estimation.sthlp:115`: says `estat mcmcdiag` prints the report by default; since 1.5.5 only with `report`.
- `nwergm.sthlp:526`: the theta() order statement is wrong for `nodeofactor`/`nodeifactor`, which are registered
  after degree/concurrent/triangle/ctriple (`nwergm.ado:1232/1236` and in simulate).
- `nwergm_estat.sthlp:96`: default `gofinterval` after MPLE is described ambiguously (see the interval item above).
- mpletype(penalized) on an empty network: the all-same check comes first, so r(2000). R 4.12 penalized is broken
  there, so no reference (TODO-R).
- `gwesp(-1)`: R returns NaN; nwergm behaviour not decided (SOFT).
- Coefficient names longer than 32 characters (`_nwergm_coeflabel`): no handling seen (SOFT, xt_stats_longmodel.do).
- `nwergm simulate, seed(-1)` cannot be passed (option parsing).
- Core `_nwsyntax.ado:71`: the local `errNWsNotFound` is not defined, so the missing-network message is empty (core;
  SOFT in xt_errors_state.do).
- Leftover no-op `capture confirm number 0` at `nwergm_p.ado:13,47` and `_nwergm_fitstats.ado:11`.

## TODO-R items

- `gwesp(-1)`: `summary(nw ~ gwesp(-1, fixed=TRUE))` returns NaN. Decide the wanted nwergm behaviour (refuse or NaN).
- Penalized MPLE on an empty network: `ergm(empty ~ edges, estimate="MPLE", control=control.ergm(MPLE.type="penalized"))`.
  This fails in ergm 4.12.0, so there is no reference.
- gof interval after MPLE: resolved in R (1024). The assert in xt_postest_shapes.do stays commented out until the
  owner decides whether to follow R.

## Runner caveats

- `cscripts/run_tests.sh` does not add the `$NWCORE` root to the adopath and does not `do unw_core.do` / `unw_ergm.do`.
  The existing tests do this themselves; the xt files rely on the runner. Add it to the preamble, or prepend it per file.
- Add the xt files to the runner's test list.
- xt_invariance.do and xt_mcmle.do read `$NWCORE/data/lazega` and `/florentine` through `env NWCORE`.
- Do not wrap nwergm in `preserve`: it preserves the data itself in the MPLE step (a nested preserve gives r(621)).

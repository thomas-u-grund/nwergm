# nwergm extended tests: triage (2026-11-12, Stata 17 BE, nwergm 1.5.12 + core of the same date)

Repro do-files and logs: `$S/xtrun/models/repro/nwergm/` (`t1.do` 2-node rc, `t2.do` nwsummarize returns, `t3.do`
nwtomata diagonal, `e2.do` state after refused call / simulate N, `gofseed.do` + `gofseed2.do` estat gof
reproducibility). Test logs: `$S/xtrun/models/nwergm_xt_*.log`. R ergm 4.12.0 rechecked today for the gw limits.

## Suspects and new findings

| Id | Verdict | Severity | One-line repro | Cause |
|---|---|---|---|---|
| N5 (new) | CONFIRMED | wrong results silently | 7-node U: `nwergm U, edges gwesp(40) method(mple)` -> e(obs_stats) gwesp = 0 (R: 6); same for gwdsp/gwnsp/gwdegree(40), gwesp/gwdegree(100); gwesp(30) = 6.000998 (R 5.99999999999991), gwdegree(30) 14.0023 (R 14) | naive `exp(d)*(1-(1-exp(-d))^k)`: cancellation from d of about 30, exactly 0 from d >= ~37; R uses the stable form / limit. Also affects the fitted coefficients |
| E3 (notes 3) | CONFIRMED | wrong results silently | `nwergm D40, edges nodeocov(o1-o3) method(mple)` fits ONE column `nodeocov_o1-o3` (the expression o1 minus o3) instead of o1 o2 o3; `nodeocov(o*)` -> r(111) "neither a variable nor a valid expression"; fewer data rows than nodes -> r(198) "Obs. nos. out of range" | `_nwergm_cov.ado:158-187` (`_nwergm_covattr`): no varlist expansion; `confirm variable` fails, so the text goes to `generate ... = o1-o3`. nwergm.sthlp:68 documents `nodecov(varlist)` |
| N6 (new) | CONFIRMED | wrong results silently (reproducibility) | `estat gof, gof(model) nsim(20) seed(5)` twice after one MPLE fit: tables differ (mreldif .05); `nwergm simulate, nsim(2) seed(5)` before and after another `estat gof`: r(stats) differ (8.39); refitting before each gof makes it reproducible; predict unaffected | `ergm_gof_run` (unw_ergm.do:5742-5770) runs the chain on the stored `__nwergm_last_G`, which then stays at the last gof draw; the next gof / simulate-from-fit start there, not at the observed network (Mata path; the MPLE fit ran without the plugin) |
| E2 (notes 2) | CONFIRMED | error only (not silent: guarded or raw Mata error) | fit U14; `nwergm simulate 30, edges kstar(2) theta(-2 0.01) nsim(1)`; then `estat gof` / `nwergm simulate` / `predict` -> r(498) "no fitted nwergm model available"; after a refused `nwergm R14, edges triangle nodematch(gm)` (416, also 14 nodes): `estat gof` and `nwergm simulate` -> raw `ErgmMCMCSample(): 3200 conformability error`, predict r(498). e() still shows the U14 fit | nwergm.ado:617-622, 833, 3020, 3805-3833 replace the Mata globals; the guards in _nwergm_gof.ado:16 / nwergm_p.ado:27-40 catch only a missing global, not a different one |
| E5 (new) | CONFIRMED | minor (results lost) | fit U14, then `nwergm E5, edges` (empty network, refused r(2000)): e() is empty afterwards | the inner `logit` (nwergm.ado:2225) clears e() before nwergm refuses; every other refusal keeps e() |
| N4 (new) | CONFIRMED | error only (raw Mata error) | `nwergm U, edges nodefactor(one) method(mple)` with a single-level attribute -> `_ergm_cov_pick(): 3203 <tmp>[0,0] found where colvector required` | R drops the term with a note; _ergm_cov_levels/_ergm_cov_pick in unw_ergm.do do not handle one level (nodemix(one) is fine) |
| E1 (notes 1) | CONFIRMED | error only | `nwergm D12, edges mutual nologlik seed(5)` then `predict, matrix(Pn)` -> "varlist required", r(100) | `_nwergm_fitstats.ado:48-67` sets e(predict) only after `if missing(ll) exit`; curved models get the same Stata default error instead of a nwergm message |
| E4 (notes 4) | CONFIRMED | error only | `nwergm simulate, nsim(2) output(edgelist) clear coef(-50 ...)` (all draws empty) -> "__simE7_el not found", r(111) | `_nwergm_simfit.ado` edge-list branch / unw_ergm.do:5955 (0x3 matrix not created) |
| long names | CONFIRMED | error only (R has no limit) | `nodeocov(<two 32-character names>)` -> r(198) | coefficient name `nodeocov_<name>` > 32 characters (`_nwergm_coeflabel`); same class as nwrem S7 |
| mcmcdiag doc | CONFIRMED | cosmetic (help) | `estat mcmcdiag` without `report` prints no report | nwergm_estimation.sthlp:115 says it prints the report; nwergm_estat.ado:19 needs `report` |
| seed(-1) | CONFIRMED (code reading; runtime-confirmed for nwrem/nwdynam) | minor | `nwergm ..., seed(-1)` / `nwergm simulate, seed(-1)` = unseeded | nwergm.ado:54, 2853 `SEED(integer -1)` sentinel |
| gof interval after MPLE | POLICY (R deviation, owner decides) | wrong default vs R | `estat gof, nsim(20)` after MPLE uses interval 52; R gof.ergm uses 1024 | _nwergm_gof.ado:29-35 `ceil(1024/nsim)`; nwergm_estat.sthlp:96 ambiguous |
| triangle directed | POLICY (documented) | - | `nwergm D12, edges triangle` -> r(198); R gives 5 | nwergm.sthlp:147 says "undirected only"; the message could name `ctriple`/structural |
| gwesp(-1) | POLICY | - | accepted, statistic 3.2817 (R: NaN) | no check of the decay sign |
| proposal()/type() r(6556) | POLICY (cosmetic) | cosmetic | invalid `proposal(foo)` / `type(XYZ)` -> r(6556), other option errors r(198) | nwergm.ado:135, 143 `_opts_oneof` |
| theta() order (nwergm.sthlp:526) | UNCLEAR (not verified at runtime) | cosmetic (help) | - | code reading only (nwergm.ado:1232/1236 register nodeofactor/nodeifactor after the structural terms) |
| penalized MPLE on empty network | UNCLEAR (no R reference; ergm 4.12 fails) | - | r(2000) | - |
| core `_nwsyntax` errNWsNotFound | NOT A BUG | - | `nwergm nosuchnet, edges` -> "Network nosuchnet not found", r(482) | the code is defined |
| no-op `capture confirm number 0` | NOT A BUG (dead code) | - | - | nwergm_p.ado:13, 47; _nwergm_fitstats.ado:11 |
| N1 replay | DECIDED: fix (owner 2026-11-12: add estimates replay to all four packages, low priority) | - | `estimates replay` after nwergm: no replay branch, same as the other model commands | - |

Counts: CONFIRMED 11 (N5, E3, N6, E2, E5, N4, E1, E4, long names, mcmcdiag doc, seed(-1)), NOT A BUG 2, POLICY 4
(gof interval, triangle directed, gwesp(-1), 6556 codes), DECIDED: fix 1 (replay), UNCLEAR 2 (theta order, penalized empty).

## Test-code fixes

- xt_tiny.do: 2-node full undirected network gives r(2001) (logit with one observation), not r(2000); directed
  `nwsummarize` returns `r(arcs)`, not `r(edges)`.
- xt_errors_state.do: `nwtomata` returns a missing diagonal (compare after `_diag(__U, 0)`); refusal checks record
  failures in `$XT_FAILS` and refit the reference instead of stopping; E5 (`nwergm E5`) left out of the state block,
  marked; E2 checks marked; PASS lines no longer printed after a FAIL.
- xt_stats_undirected.do / xt_stats_directed.do / xt_stats_longmodel.do / xt_postest_shapes.do: Mata `col :op row'`
  outer operations (not conformable in Stata 17) rewritten with `J()` products.
- xt_stats_undirected.do: `xt_stat` records failures (N5 marked); single-level factor raw Mata error recorded (N4).
- xt_mple_crossroute.do: SE vs R glm compared with relative tolerance 1e-4 (R differs by up to 3e-5 relative,
  coefficients agree to 1e-6); one-line Mata `if` without `else` (waits for input) replaced by select(); matrix width.
- xt_invariance.do: the 14-term model on 14 nodes is separated (residual deviance 0, |b| up to 900), so b is not
  determined: statistics of that model still compared, b/V/ll/predict compared on edges gwesp(.5) gwdegree(.8) +
  nodematch + nodecov.
- xt_stats_longmodel.do: varlist range / wildcard / long names recorded instead of stopping (E3).
- xt_mcmle.do: `nwuse` needs `nwappend`; E1 recorded.
- xt_postest_shapes.do: directed simulation count `r(arcs)`; N6 and E4 recorded.

## Remaining failures per file

| File | Result |
|---|---|
| xt_tiny.do | ALL PASS |
| xt_stats_bipartite.do | ALL PASS |
| xt_stats_directed.do | ALL PASS (SOFT: triangle on directed) |
| xt_stats_undirected.do | r(9): N5 (8 gw checks), N4 (nodefactor one level); SOFT gwesp(-1) |
| xt_stats_longmodel.do | r(9): E3 range and wildcard; SOFT long names (r(198)) |
| xt_mple_crossroute.do | ALL PASS |
| xt_invariance.do | ALL PASS |
| xt_mcmle.do | r(9): E1 |
| xt_postest_shapes.do | r(9): N6, E4; SOFT gof interval 52 vs R 1024 |
| xt_errors_state.do | r(9): E5 (two r(2000) refusals clear e()), E2 (simulate N, refused call) |

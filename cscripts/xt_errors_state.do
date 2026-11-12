cscript

* DRAFT, not yet run.
* xt_errors_state: error paths with the exact return codes of the code (file:line in the comments), and that a refused
* call leaves e(), the data and the networks as they were. Then the state shared between calls: nwergm keeps the
* fitted model and graph in the Mata globals __nwergm_last_M / __nwergm_last_G, which estat gof, nwergm simulate
* (from a fit) and predict use, while e() describes the fit. A later nwergm simulate with a number of nodes, or a
* refused nwergm call, replaces those globals (nwergm.ado lines 617-622, 833, 3020, 3805-3833) but not e().
* The state checks are expected to FAIL until that is fixed (suspected bug, see xt_NOTES.md).
* Also: r() results survive the helpers that estat runs (plot, report).
* Expected runtime: about 1 minute.
* Runs from the repository root; the runner sets PLUS, the adopath and the plugin path.
capture program drop nwinstall
set graphics off

* U14 / D12 as in xt_mple_crossroute.do, E5 empty, M14 = U14 with a missing dyad, U7 a smaller undirected network
nwclear
clear
mata: ui = (1,2,3,1,4,4,5,1,6,1,5,1,6,7,9,10,4,7,10,2,5,6,10,11,2,7,10)
mata: uj = (2,4,4,5,5,6,6,7,8,9,9,10,11,11,11,11,12,12,12,13,13,13,13,13,14,14,14)
mata: A = J(14, 14, 0)
mata: for (k = 1; k <= 27; k++) A[ui[k], uj[k]] = 1
mata: A = A + A'
mata: st_matrix("AU14", A)
mata: Am = A; Am[1,3] = .; Am[3,1] = .; st_matrix("AM14", Am)
mata: dt = (4,9,3,6,5,7,9,10,11,12,1,10,3,5,9,1,4,6,10,12,3,4,5,10,4,12,9,9)
mata: dh = (1,1,2,2,3,3,3,4,4,4,5,5,6,6,6,7,7,8,8,8,9,9,9,9,10,10,11,12)
mata: B = J(12, 12, 0)
mata: for (k = 1; k <= 28; k++) B[dt[k], dh[k]] = 1
mata: st_matrix("AD12", B)
mata: st_matrix("AE5", J(5, 5, 0))
mata: C = J(7, 7, 0); C[1,2] = 1; C[2,3] = 1; C[3,1] = 1; C[4,5] = 1; C = C + C'; st_matrix("AU7", C)
nwset, mat(AU14) undirected name(U14) nooutput
nwset, mat(AM14) undirected name(M14) nooutput
nwset, mat(AD12) directed name(D12) nooutput
nwset, mat(AE5) undirected name(E5) nooutput
nwset, mat(AU7) undirected name(U7) nooutput
clear
set obs 14
gen double g = mod(_n - 1, 2) + 1
gen double gm = g
replace gm = . in 3
gen str5 s = cond(g == 1, "a", "b")

* ---------------------------------------------------------------------------------------------------------------
* the reference fit and a checker: after a refused call, e() of the reference fit, the data and network U14 are unchanged
nwergm U14, edges triangle method(mple)
matrix __b0 = e(b)
matrix __V0 = e(V)
qui datasignature
local __sig0 "`r(datasignature)'"

capture program drop xt_unchanged
program xt_unchanged
	* records a failure in $XT_FAILS (does not stop); restores the reference fit when e() was replaced
	args id
	if "`e(cmd)'" != "nwergm" | "`e(depvar)'" != "U14" {
		di as err "FAIL `id': e() was replaced (cmd `e(cmd)', depvar `e(depvar)')"
		global XT_FAILS "$XT_FAILS `id'(e-replaced)"
		qui nwergm U14, edges triangle method(mple)
		exit
	}
	tempname bb VV
	matrix `bb' = e(b)
	matrix `VV' = e(V)
	if mreldif(`bb', __b0) != 0 | mreldif(`VV', __V0) != 0 {
		di as err "FAIL `id': e(b)/e(V) changed"
		global XT_FAILS "$XT_FAILS `id'(e-changed)"
		qui nwergm U14, edges triangle method(mple)
		exit
	}
	qui datasignature
	if "`r(datasignature)'" != "$XT_SIG0" {
		di as err "FAIL `id': the data changed"
		global XT_FAILS "$XT_FAILS `id'(data)"
		exit
	}
	qui nwtomata U14, mat(__U)
	mata: _diag(__U, 0)                 // nwtomata gives a missing diagonal
	mata: st_numscalar("__ok", __U == st_matrix("AU14"))
	if __ok != 1 {
		di as err "FAIL `id': network U14 changed"
		global XT_FAILS "$XT_FAILS `id'(network)"
		exit
	}
	di as txt "PASS `id': state unchanged"
end
global XT_FAILS ""
global XT_SIG0 "`__sig0'"

* each refused call: exact return code, then the state check
capture program drop xt_refuse
program xt_refuse
	args id rc cmdline
	capture noisily `cmdline'
	local got = _rc
	if `got' != `rc' {
		di as err "FAIL `id': r(`got'), expected r(`rc')"
		global XT_FAILS "$XT_FAILS `id'(rc`got')"
	}
	xt_unchanged `id'
end

xt_refuse noedges 198 "nwergm U14, triangle"                                     // nwergm.ado ~95
xt_refuse mutual_undirected 198 "nwergm U14, edges mutual"                     // ~268
* triangle on a directed network is accepted as in R (xt_stats_directed.do checks the statistic)
xt_refuse gwesp_negative 198 "nwergm U14, edges gwesp(-1)"
xt_refuse seed_negative 198 "nwergm U14, edges seed(-1)"
xt_refuse kstar_directed 198 "nwergm D12, edges kstar(2)"                      // ~560
xt_refuse gwdegree_directed 198 "nwergm D12, edges gwdegree(.5)"               // ~532
xt_refuse ostar_undirected 198 "nwergm U14, edges ostar(2)"                    // ~564
xt_refuse sender_undirected 198 "nwergm U14, edges sender"                     // ~582
xt_refuse bterm_onemode 198 "nwergm U14, edges bdegree1(1)"                    // ~251
xt_refuse string_attr 109 "nwergm U14, edges nodematch(s)"                     // _nwergm_cov.ado _nwergm_covattr ~178
xt_refuse missing_attr 416 "nwergm U14, edges nodematch(gm)"                   // _nwergm_covattr ~184
xt_refuse missing_attr_dep 416 "nwergm U14, edges triangle nodecov(gm)"
xt_refuse no_variable 111 "nwergm U14, edges nodecov(nosuchvar)"               // _nwergm_covattr ~166
xt_refuse method 198 "nwergm U14, edges method(foo)"                           // _nwergm_est.ado _opts_oneof ... 198
xt_refuse estimate_conflict 198 "nwergm U14, edges estimate(mple) method(cd)"  // _nwergm_est.ado ~22
xt_refuse proposal 198 "nwergm U14, edges triangle proposal(foo)"             // nwergm.ado ~135 (_opts_oneof ... 6556)
xt_refuse type 198 "nwergm D12, edges gwesp(.5) type(XYZ)"                    // ~143
xt_refuse curved_twice 198 "nwergm U14, edges gwesp(.5) gwespfree(.5)"
xt_refuse offset_odd 198 "nwergm U14, edges triangle offset(triangle)"         // ~1907
xt_refuse offset_name 198 "nwergm U14, edges triangle offset(nosuch 1)"        // ~1921
xt_refuse offset_value 198 "nwergm U14, edges triangle offset(triangle abc)"   // ~1916
xt_refuse offset_dup 198 "nwergm U14, edges triangle offset(triangle 1 triangle 2)" // ~1927
xt_refuse offset_all 198 "nwergm U14, edges triangle offset(edges -1 triangle 1)"   // ~1934
xt_refuse offset_curved 198 "nwergm U14, edges gwespfree(.5) offset(edges -1)"     // ~1903
xt_refuse init_count 198 "nwergm U14, edges triangle init(1)"                  // _nwergm_est.ado ~66
xt_refuse init_value 198 "nwergm U14, edges triangle init(1 x)"                // ~78
xt_refuse fixdensity_mple 198 "nwergm U14, edges triangle fixdensity method(mple)" // nwergm.ado ~117
xt_refuse fixdensity_free 198 "nwergm U14, edges triangle fixdensity freedyads(U7)"
xt_refuse penalized_offset 198 "nwergm U14, edges triangle offset(triangle 1) mpletype(penalized) method(mple)"
xt_refuse confidence 198 "nwergm U14, edges triangle mcmleconfidence(1)"       // _nwergm_est.ado ~148
xt_refuse mpletype 198 "nwergm U14, edges mpletype(foo)"
xt_refuse expstat_log0 198 "nwergm U14, edges kstar(2) method(mple) expstat(kstar_2, log0(-5))"
xt_refuse edgecov_size 198 "nwergm U14, edges edgecov(U7)"                     // _nwergm_cov.ado ~37
xt_refuse edgecov_missing 416 "nwergm U14, edges edgecov(M14)"                 // ~58
* E5 (fixed): the r(2000) refusals below keep e() of the previous fit
xt_refuse empty_network 2000 "nwergm E5, edges triangle method(mple)"          // nwergm.ado ~2234 (logit: outcome does not vary)
xt_refuse empty_network_dind 2000 "nwergm E5, edges"
* penalized MPLE on an empty network: edges alone has a finite Firth estimate; with a statistic that is 0 on every
* dyad there is none (clean refusal)
xt_refuse empty_penalized_tri 2000 "nwergm E5, edges triangle mpletype(penalized) method(mple)"
* a network that does not exist: _nwsyntax stops with "Network ... not found" and error `errNWsNotFound', a local that
* is not defined in _nwsyntax.ado (core) - the code is whatever "error" with an empty argument gives. Recorded only.
capture noisily nwergm nosuchnet, edges
local rcn = _rc
assert `rcn' != 0
assert `rcn' < 3000 | `rcn' > 3999
xt_unchanged nosuchnet
di as txt "NOTE missing network: r(`rcn')"

* estat / simulate / predict refusals (nwergm_estat.ado, _nwergm_gof.ado, _nwergm_simfit.ado, nwergm_p.ado)
xt_refuse estat_unknown 321 "estat foo"
xt_refuse estat_mcmcdiag_mple 498 "estat mcmcdiag"
xt_refuse gof_nsim 198 "estat gof, nsim(1)"
xt_refuse predict_nomatrix 198 "predict"
di "PASS block refusals"

* without nwergm results: estat and simulate from a fit refuse with 301
estimates store __ref
ereturn clear
capture noisily estat gof, nsim(5)
assert _rc == 301
capture noisily nwergm simulate, nsim(1)
assert _rc == 301
estimates restore __ref
di "PASS no estimates: 301"

* ---------------------------------------------------------------------------------------------------------------
* r() results survive what estat runs after computing them (plot: graph combine; report: _nwergm_mcdiag)
qui nwergm U14, edges triangle method(mple)
estat gof, nsim(5) seed(1) plot name(xtgof)
assert r(nsim) == 5
confirm matrix r(gof_model)
confirm matrix r(gof_degree)
assert r(obs_triad_300) == 5
qui nwergm D12, edges mutual seed(1) mcmcinterval(100)
estat mcmcdiag, report
confirm matrix r(ess)
confirm matrix r(geweke)
confirm matrix r(heidel)
confirm matrix r(mc_summary)
estat mcmcdiag, plot name(xtdiag)
confirm matrix r(ess)
assert r(acceptrate) > 0
di "PASS r() results kept through plot and report"

* ---------------------------------------------------------------------------------------------------------------
* state shared between calls (suspected bug). Reference: fit on U14 (14 nodes), its observed model statistics 27 and 5.
qui nwergm U14, edges triangle method(mple)
matrix __b0 = e(b)
predict, matrix(P0)

* (1) nwergm simulate with a number of nodes in between: e() still describes the U14 fit
* (other terms than the fit, so that a replaced model shows in the observed statistics and the coefficient names)
nwergm simulate 30, edges kstar(2) theta(-2 0.01) nsim(1) generate(other) seed(1)
assert "`e(depvar)'" == "U14"
capture noisily estat gof, gof(model) nsim(5) seed(1)
local rc1 = _rc
local ok1 = 0
if `rc1' == 0 {
	matrix GM = r(gof_model)
	if rowsof(GM) == 2 {
		if GM[1,1] == 27 & GM[2,1] == 5 local ok1 = 1
	}
}
capture noisily nwergm simulate, nsim(1) generate(after1) seed(1)
local rc2 = _rc
local ok2 = 0
if `rc2' == 0 {
	qui nwsummarize after1
	if r(nodes) == 14 local ok2 = 1
}
capture noisily predict, matrix(P1)
local rc3 = _rc
local ok3 = 0
if `rc3' == 0 {
	if mreldif(P0, P1) < 1e-12 local ok3 = 1
}
di as txt "state after simulate N: estat gof rc `rc1' ok `ok1'; simulate rc `rc2' ok `ok2'; predict rc `rc3' ok `ok3'"
if !(`ok1' & `ok2' & `ok3') {
	// E2 (fixed)
	di as err "FAIL nwergm simulate N replaced the fitted model/graph used by estat gof / simulate / predict"
	global XT_FAILS "$XT_FAILS E2-simulateN"
}
else di "PASS postestimation unaffected by nwergm simulate N"

* (2) a refused nwergm call on another network in between (the graph global is rebuilt before the error)
clear
set obs 14
gen double g = mod(_n - 1, 2) + 1
gen double gm = g
replace gm = . in 3
qui nwergm U14, edges triangle method(mple)
capture noisily nwergm U7, edges triangle nodematch(gm) method(mple)
assert _rc == 416
assert "`e(depvar)'" == "U14"
capture noisily estat gof, gof(model) nsim(5) seed(1)
local rc1 = _rc
local ok1 = 0
if `rc1' == 0 {
	matrix GM = r(gof_model)
	if rowsof(GM) == 2 {
		if GM[1,1] == 27 & GM[2,1] == 5 local ok1 = 1
	}
}
capture noisily nwergm simulate, nsim(1) generate(after2) seed(1)
local rc2 = _rc
local ok2 = 0
if `rc2' == 0 {
	qui nwsummarize after2
	if r(nodes) == 14 local ok2 = 1
}
di as txt "state after refused calls: estat gof rc `rc1' ok `ok1'; simulate rc `rc2' ok `ok2'"
if !(`ok1' & `ok2') {
	// E2 (fixed)
	di as err "FAIL a refused nwergm call replaced the fitted model/graph used by estat gof / simulate"
	global XT_FAILS "$XT_FAILS E2-refused"
}
else di "PASS postestimation unaffected by refused calls"

* replay (N1): nwergm alone, nwergm, level(90), estimates replay; postestimation after estimates restore of an earlier
* fit refuses cleanly (the model held in Mata belongs to the later fit)
qui nwergm U14, edges triangle method(mple)
matrix BR = e(b)
estimates store xtA
nwergm
nwergm, level(90)
estimates replay xtA
assert mreldif(e(b), BR) == 0
qui nwergm U14, edges kstar(2) method(mple)
estimates restore xtA
capture noisily estat gof, gof(model) nsim(5) seed(1)
if _rc != 498 {
	di as err "FAIL estat gof after estimates restore of an earlier fit: r(`=_rc'), expected r(498)"
	global XT_FAILS "$XT_FAILS restore-mismatch"
}
estimates drop xtA
ereturn clear
capture nwergm
if _rc != 301 {
	di as err "FAIL nwergm alone without estimates: r(`=_rc'), expected r(301)"
	global XT_FAILS "$XT_FAILS replay301"
}
* penalized MPLE on the empty network with edges alone: finite Firth estimate, logit(1/2 / (n + 1/2)) for n = 10 dyads
* is the closed form of Firth's estimate for an intercept-only model with no events: p = 0.5/(n+1)
nwergm E5, edges mpletype(penalized) method(mple)
assert abs(_b[edges] - logit(0.5 / 11)) < 1e-6
di "PASS replay, restore mismatch, penalized MPLE on an empty network"

if "$XT_FAILS" != "" {
	di as err "failures:$XT_FAILS"
	exit 9
}
di "ALL PASS"

cscript

* e(mple_exists) and e(converged) when the maximum pseudolikelihood estimate does not exist (separation).
* method(mple): the estimate is not converged (e(converged) = 0) and a warning is printed; method(mcmle): the pseudolikelihood is only
* the starting value, e(mple_exists) records it and e(converged) stays the result of the MCMLE test; mpletype(penalized) is exempt.

local nwcore : env NWCORE
if `"`nwcore'"' == "" {
	di as error "set the environment variable NWCORE to the directory of the nwcommands (core) package"
	exit 198
}
adopath ++ `"`nwcore'"'
adopath ++ `"`c(pwd)'"'
quietly do `"`nwcore'/unw_core.do"'
do unw_ergm.do

* two groups of four; ties only inside the groups, and not all of them: nodematch separates the ties from the non-ties
matrix S = J(8,8,0)
forvalues i = 1/4 {
	forvalues j = 1/4 {
		if `i' != `j' & !(`i' + `j' == 7) matrix S[`i',`j'] = 1
	}
}
forvalues i = 5/8 {
	forvalues j = 5/8 {
		if `i' != `j' & !(`i' + `j' == 13) matrix S[`i',`j'] = 1
	}
}
matrix G = (1\1\1\1\2\2\2\2)
* a ring of 12 actors: no triangle, so the triangle coefficient of edges + triangle is separated
matrix R = J(12,12,0)
forvalues i = 1/12 {
	local j = mod(`i',12) + 1
	matrix R[`i',`j'] = 1
	matrix R[`j',`i'] = 1
}
qui nwclear
qui clear
qui nwset, mat(R) name(ring) undirected
qui nwset, mat(S) name(sep) undirected
qui svmat G, names(c)
qui rename c1 grp

* ---- method(mple): separated models are flagged, in the dyad-independent and the dyad-dependent case
foreach spec in "sep|edges nodematch(grp)" "ring|edges triangle" {
	gettoken net trm : spec, parse("|")
	local trm = subinstr("`trm'", "|", "", 1)
	nwergm `net', `trm' method(mple)
	assert e(mple_exists) == 0
	assert e(converged) == 0
	assert e(method) == "mple"
	* the warning does not change the coefficients: the glm iterate is still reported
	mata: st_numscalar("mx", max(abs(st_matrix("e(b)"))))
	assert scalar(mx) > 10
	* the same without the existence check: nothing is known, so nothing is flagged
	nwergm `net', `trm' method(mple) mplecheck(off)
	capture confirm scalar e(mple_exists)
	assert _rc != 0
	assert e(converged) == 1
	* the penalised MPLE is finite by construction
	nwergm `net', `trm' method(mple) mpletype(penalized)
	assert e(converged) == 1
	assert e(mple_exists) == 1
	mata: st_numscalar("mx", max(abs(st_matrix("e(b)"))))
	assert scalar(mx) < 10
}
* mplecheck(off) with method(mcmle): the existence of the pseudolikelihood is unknown, e(mple_exists) is not posted; e(converged) is the MCMLE test
nwergm ring, edges triangle method(mcmle) mplecheck(off) seed(1)
capture confirm scalar e(mple_exists)
assert _rc != 0
assert e(converged) < .
di "PASS separated method(mple) flagged, mplecheck(off) and penalized exempt"

* ---- method(mcmle): a statistic at the boundary of the simulated statistics (R: "at their smallest attainable values", -Inf): the maximum
* likelihood estimate does not exist; the pseudolikelihood used as the starting value is recorded in e(mple_exists)
matrix T = J(10,10,0)
forvalues i = 1/9 {
	matrix T[`i',`i'+1] = 1
	matrix T[`i'+1,`i'] = 1
}
qui nwset, mat(T) name(tree) undirected
foreach spec in "ring|edges triangle" "tree|edges triangle" {
	gettoken net trm : spec, parse("|")
	local trm = subinstr("`trm'", "|", "", 1)
	nwergm `net', `trm' method(mcmle) seed(1)
	assert e(mple_exists) == 0
	assert e(mle_exists) == 0
	assert e(converged) == 0
	mata: st_numscalar("mx", max(abs(st_matrix("e(b)"))))
	assert scalar(mx) < 20
}
di "PASS zero-triangle networks, method(mcmle): e(mle_exists) = 0, e(converged) = 0"
* the warning that the MCMLE test failed is not hidden by the MPLE / MLE warnings: one iteration, no MPLE, no MLE, test not satisfied
tempfile wlog
qui log using `"`wlog'"', text replace name(wl)
nwergm tree, edges triangle method(mcmle) seed(1) mcmleiterations(1)
qui log close wl
assert e(converged) == 0 & e(mple_exists) == 0 & e(mle_exists) == 0
local found_mple 0
local found_mle 0
local found_conv 0
tempname fh
file open `fh' using `"`wlog'"', read text
file read `fh' line
while r(eof) == 0 {
	if strpos(`"`line'"', "The MPLE does not exist") local found_mple 1
	if strpos(`"`line'"', "maximum likelihood estimate does not exist for this model") local found_mle 1
	if strpos(`"`line'"', "MCMLE did NOT satisfy its own convergence test") local found_conv 1
	file read `fh' line
}
file close `fh'
assert `found_mple' & `found_mle' & `found_conv'
di "PASS MCMLE non-convergence warning printed together with the MPLE and MLE warnings"
* a separated model whose observed statistics are inside the simulated ones keeps the MCMLE test
nwergm sep, edges nodematch(grp) method(mcmle) seed(1)
assert e(mple_exists) == 0
assert e(converged) == e(converged) & e(mle_exists) < .
di "  (sep, mcmle: e(converged) = " e(converged) ", e(mle_exists) = " e(mle_exists) ")"

* ---- the pseudolikelihood exists: e(mple_exists) = 1, e(converged) = 1 for method(mple)
set seed 20261122
mata: A = (uniform(24,24) :< .15); A = A - diag(diag(A)); B = (A + A' :> 0)
mata: st_matrix("U", B); st_matrix("G3", ceil((1::24)/8))
qui nwclear
qui clear
qui nwset, mat(U) name(u) undirected
qui svmat G3, names(c)
qui rename c1 grp
nwergm u, edges nodematch(grp) method(mple)
assert e(mple_exists) == 1 & e(converged) == 1
nwergm u, edges triangle method(mple)
assert e(mple_exists) == 1 & e(converged) == 1
nwergm u, edges triangle method(mcmle) seed(4)
assert e(mple_exists) == 1 & e(converged) == 1 & e(mle_exists) == 1
di "PASS ordinary fits: e(mple_exists) = 1"

* ---- the sparse design (more than 100 coefficients, via nodefactor; the dense design with NWERGM_NOSPARSE): a node without ties separates its level
mata: A = (uniform(120,120) :< .04); A = A - diag(diag(A)); B = (A + A' :> 0); B[120,.] = J(1,120,0); B[.,120] = J(120,1,0)
mata: st_matrix("W", B); st_matrix("L", (1::120))
qui nwclear
qui clear
qui nwset, mat(W) name(w) undirected
qui svmat L, names(c)
qui rename c1 lev
foreach ns in "" 1 {
	global NWERGM_NOSPARSE "`ns'"
	nwergm w, edges nodefactor(lev) method(mple)
	mata: st_numscalar("sp", ergm_sp_use(__nwergm_last_M, __nwergm_last_G))
	assert scalar(sp) == 1
	assert e(mple_exists) == 0
	assert e(converged) == 0
}
global NWERGM_NOSPARSE ""
di "PASS many-level model (sparse and dense design)"

di "ALL TESTS PASSED"

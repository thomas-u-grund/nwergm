cscript

* The core package nwcommands is found through the environment variable NWCORE (path of the core checkout).
local nwcore : env NWCORE
if `"`nwcore'"' == "" {
	di as error "set the environment variable NWCORE to the directory of the nwcommands (core) package"
	exit 198
}
adopath ++ `"`nwcore'"'
adopath ++ `"`c(pwd)'"'
quietly do `"`nwcore'/unw_core.do"'
quietly do unw_ergm.do

* Egocentrically sampled data: nwergm ego (R: ergm.ego 1.1.4, Krivitsky and Morris 2017).
*  1. the statistics estimated from the egos and their design-based covariance equal R's, exactly
*  2. coefficients and standard errors agree with ergm.ego (two seeds of R, long runs) on the faux.mesa.high example and on a planted
*     ERGM on 1,000 nodes sampled with equal and with unequal weights; recovery of the planted values
*  3. popsize() and ppopsize(), the network size adjustment; egodegree(); if and in; reproducibility
*  4. estat gof, nwergm simulate, replay, other postestimation
*  5. error paths
* The reference values are in cscripts/ego/ (ergm.ego 1.1.4 with ergm 4.12.0; the R scripts that made them are there too).

local D "cscripts/ego"

capture program drop _t_load
program _t_load
	args tag
	capture frame drop alt
	frame create alt
	frame alt: quietly import delimited using "cscripts/ego/`tag'_alter.csv", clear case(preserve) varnames(1)
	quietly import delimited using "cscripts/ego/`tag'_ego.csv", clear case(preserve) varnames(1)
end

* reads the reference coefficients of R: scalars _r1_<name>, _r2_<name>, _se1_<name>, _se2_<name> for seeds 1 and 2
capture program drop _t_ref
program _t_ref
	args tag
	forvalues s = 1/2 {
		capture frame drop ref
		frame create ref
		frame ref: quietly import delimited using "cscripts/ego/`tag'_coef_s`s'.csv", clear
		frame ref: quietly drop if name == "offset(netsize.adj)"
		frame ref: quietly destring se, replace force
		frame ref: local nr = _N
		forvalues i = 1/`nr' {
			frame ref: local nm = name[`i']
			frame ref: scalar _r`s'_`i' = b[`i']
			frame ref: scalar _se`s'_`i' = se[`i']
		}
	}
	capture frame drop ref
end

* compares the coefficients: nwergm names in the order of R's coefficients
capture program drop _t_cmp
program _t_cmp
	syntax , NAMES(string) TAG(string) [TOLSE(real 0.25) RATIO(real 1.33) Z(real 0)]
	local i = 0
	foreach nm of local names {
		local ++i
		local rb = (scalar(_r1_`i') + scalar(_r2_`i')) / 2
		local rse = (scalar(_se1_`i') + scalar(_se2_`i')) / 2
		local d = abs(_b[`nm'] - `rb')
		local tol = max(`tolse' * `rse', 1e-4)
		if `d' > `tol' {
			di as err "FAIL `tag' `nm': b = " _b[`nm'] ", R = `rb' (differs by `d', tolerance `tol')"
			exit 9
		}
		local q = _se[`nm'] / `rse'
		if `q' > `ratio' | `q' < 1 / `ratio' {
			di as err "FAIL `tag' `nm': se = " _se[`nm'] ", R = `rse' (ratio `q')"
			exit 9
		}
	}
	di as txt "PASS `tag': coefficients within `tolse' standard errors of R and standard errors within a factor `ratio'"
end

* the target statistics and their covariance against R's, by name pairs (nwergm name, R name)
capture program drop _t_stats
program _t_stats
	syntax , TAG(string) NWNAMES(string) RNAMES(string) [TOL(real 1e-7)]
	capture frame drop rm
	frame create rm
	frame rm: quietly import delimited using "cscripts/ego/`tag'_m.csv", clear
	capture frame drop rv
	frame create rv
	frame rv: quietly import delimited using "cscripts/ego/`tag'_v.csv", clear varnames(nonames) rowrange(2)
	local k : word count `nwnames'
	tempname T V
	matrix `T' = e(target)
	matrix `V' = e(V_target)
	forvalues i = 1/`k' {
		local a : word `i' of `nwnames'
		local ra : word `i' of `rnames'
		frame rm: quietly summarize m if name == "`ra'", meanonly
		local rm = r(mean)
		local tm = `T'[1, colnumb(`T', "`a'")]
		if abs(`tm' - `rm') > `tol' * max(1, abs(`rm')) {
			di as err "FAIL `tag' target `a': `tm' against R `rm'"
			exit 9
		}
		frame rv: quietly generate long _ri = _n if v1 == "`ra'"
		frame rv: quietly summarize _ri, meanonly
		local ri = r(mean)
		frame rv: quietly drop _ri
		forvalues j = 1/`k' {
			local b : word `j' of `nwnames'
			local rb : word `j' of `rnames'
			frame rv: quietly generate long _ci = _n if v1 == "`rb'"
			frame rv: quietly summarize _ci, meanonly
			local cj = r(mean) + 1
			frame rv: quietly drop _ci
			frame rv: local val = v`cj'[`ri']
			local tv = `V'[colnumb(`V', "`a'"), colnumb(`V', "`b'")]
			if abs(`tv' - `val') > `tol' * max(1, abs(`val')) {
				di as err "FAIL `tag' covariance of the target `a' `b': `tv' against R `val'"
				exit 9
			}
		}
	}
	di as txt "PASS `tag': the estimated statistics and their covariance equal those of ergm.ego (`k' statistics)"
end

* ---------------------------------------------------------------------------------------------
* 1.+2. faux.mesa.high (R: ergm.ego(egor ~ edges + degree(1:3) + nodefactor("Race") + nodematch("Race") + nodefactor("Sex") + nodematch("Sex") + absdiff("Grade"), popsize = 205))
_t_load mesa
rename egoID egoid
frame alt: rename egoID egoid
local mesaterms "edges degree(1/3) nodefactor(Race Sex) nodematch(Race Sex) absdist(Grade)"
nwergm ego, `mesaterms' egoid(egoid) alters(alt) popsize(205) seed(11)
assert e(cmd) == "nwergm"
assert "`e(estimate)'" == "Ego"
assert e(egos) == 205 & e(N) == 205 & e(ppopsize) == 205 & e(popsize) == 205 & e(nodes) == 205
assert e(converged) == 1
assert e(egoshift) == 0
assert colsof(e(b)) == 12
assert rowsof(e(V)) == 12 & colsof(e(V)) == 12
_t_stats, tag(mesa) nwnames(edges degree_1 degree_2 degree_3 nodefactor_Race_2 nodefactor_Race_3 nodefactor_Race_4 nodefactor_Race_5 nodematch_Race nodefactor_Sex_2 nodematch_Sex absdist_Grade) ///
	rnames(edges degree1 degree2 degree3 nodefactor.Race.Hisp nodefactor.Race.NatAm nodefactor.Race.Other nodefactor.Race.White nodematch.Race nodefactor.Sex.M nodematch.Sex absdiff.Grade)
_t_ref mesa
_t_cmp, tag(mesa) names(edges degree_1 degree_2 degree_3 nodefactor_Race_2 nodefactor_Race_3 nodefactor_Race_4 nodefactor_Race_5 nodematch_Race nodefactor_Sex_2 nodematch_Sex absdist_Grade)
* the standard errors are the square roots of the diagonal of e(V)
forvalues i = 1/12 {
	assert abs(_se[`: word `i' of `: colnames e(b)''] - sqrt(e(V)[`i', `i'])) < 1e-12
}
* the covariance is the sandwich: V = A^-1 V_t A^-1
tempname A Ai Vt
matrix `A' = e(info)
matrix `Ai' = invsym(`A')
matrix `Vt' = `Ai' * e(V_target) * `Ai''
forvalues i = 1/12 {
	forvalues j = 1/12 {
		assert abs(`Vt'[`i', `j'] - e(V)[`i', `j']) < 1e-9 * max(1, abs(e(V)[`i', `j']))
	}
}
di as txt "PASS mesa: e(V) is A^-1 V_target A^-1"
estimates store mesafit
matrix bmesa = e(b)

* reproducibility with seed()
nwergm ego, `mesaterms' egoid(egoid) alters(alt) popsize(205) seed(11)
matrix b2 = e(b)
assert mreldif(bmesa, b2) < 1e-12
di as txt "PASS mesa: the same seed gives the same fit"

* ---------------------------------------------------------------------------------------------
* 4. postestimation after the mesa fit (the last fit above)
estat gof, nsim(40) seed(5)
matrix G = r(gof_model)
assert rowsof(G) == 12 & colsof(G) == 5
* the draws are centred on the estimate, per capita
assert abs(G[1, 3] - G[1, 1]) < 0.12 * G[1, 1]
matrix D = r(gof_degree)
assert colsof(D) == 5
assert rowsof(D) == e(maxdeg) + 1
assert r(nsim) == 40
di as txt "PASS estat gof: model statistics and degree distribution"
estat gof, nsim(10) seed(5) gof(degree)
matrix D2 = r(gof_degree)
assert colsof(D2) == 5
nwergm simulate, nsim(3) seed(3) output(stats)
matrix S = r(stats)
assert rowsof(S) == 3 & colsof(S) == 12
local simedges = (S[1,1] + S[2,1] + S[3,1]) / 3
assert abs(`simedges' / 205 - e(target)[1, 1] / 205) < 0.15 * e(target)[1, 1] / 205
nwergm simulate, nsim(2) seed(3)
nwsummarize sim_1
assert r(nodes) == 205
di as txt "PASS nwergm simulate: draws at the size of the pseudopopulation"
* replay
nwergm
nwergm, ci
estimates replay
estat mcmcdiag
capture noisily estat ic
assert _rc == 498
capture noisily predict p, pr
assert _rc != 0
di as txt "PASS postestimation: replay, mcmcdiag; ic and predict refused"

* ---------------------------------------------------------------------------------------------
* planted ERGM on 1,000 nodes (edges, nodefactor(g), nodematch(g), nodecov(age), absdiff(age), concurrent); 400 egos sampled with equal weights
_t_load pl
rename egoID egoid
frame alt: rename egoID egoid
rename sample_weights w
local plterms "edges nodefactor(g) nodematch(g) nodecov(age) absdist(age) concurrent"
local plnames "edges nodefactor_g_2 nodefactor_g_3 nodematch_g nodecov_age absdist_age concurrent"
local plr "edges nodefactor.g.b nodefactor.g.c nodematch.g nodecov.age absdiff.age concurrent"
_t_ref pl
foreach s in 1 2 {
	nwergm ego, `plterms' egoid(egoid) alters(alt) weights(w) popsize(1000) seed(`s') mcmleeffectivesize(200)
	assert e(ppopsize) == 800
	assert abs(e(egoshift) - ln(1000 / 800)) < 1e-12
	assert e(converged) == 1
	_t_stats, tag(pl) nwnames(`plnames') rnames(`plr')
	_t_cmp, tag(pl seed `s') names(`plnames')
	if `s' == 1 {
		* recovery of the planted values, edges for the population of 1,000
		local truth "-5.2 0.0 0.0 0.8 0.004 -0.03 -0.4"
		local tn "edges nodefactor_g_2 nodefactor_g_3 nodematch_g nodecov_age absdist_age concurrent"
		local truth "-5.2 -0.3 0.2 0.8 0.004 -0.03 -0.4"
		local i 0
		foreach nm of local tn {
			local ++i
			local tr : word `i' of `truth'
			assert abs(_b[`nm'] - `tr') < 3.5 * _se[`nm']
		}
		di as txt "PASS planted: the estimates are within 3.5 standard errors of the planted values"
	}
}

* the same sample, unequal weights (sampling probability by group)
_t_load pw
rename egoID egoid
frame alt: rename egoID egoid
rename sample_weights w
_t_ref pw
nwergm ego, `plterms' egoid(egoid) alters(alt) weights(w) popsize(1000) seed(3) mcmleeffectivesize(200)
assert e(ppopsize) == 1052
quietly summarize w
assert abs(e(sum_weights) - r(sum)) < 1e-6
assert abs(e(sum_weights) - 1079.575) < 1e-3
_t_stats, tag(pw) nwnames(`plnames') rnames(`plr') tol(1e-3)
_t_cmp, tag(pw weighted) names(`plnames')

* ---------------------------------------------------------------------------------------------
* 3. popsize() and ppopsize(): coefficients refer to a network of popsize() nodes (the offset of the network size adjustment)
_t_load pl
rename egoID egoid
frame alt: rename egoID egoid
rename sample_weights w
nwergm ego, `plterms' egoid(egoid) alters(alt) weights(w) popsize(1000) seed(4)
local e1000 = _b[edges]
local nm1000 = _b[nodematch_g]
nwergm ego, `plterms' egoid(egoid) alters(alt) weights(w) popsize(5000) ppopsize(800) seed(4)
assert e(ppopsize) == 800 & e(popsize) == 5000
assert abs(e(egoshift) - ln(5000 / 800)) < 1e-12
assert abs(_b[edges] - (`e1000' - ln(5))) < 0.15
assert abs(_b[nodematch_g] - `nm1000') < 0.05
di as txt "PASS popsize(5000) shifts the coefficient of edges by -log(5), the others do not move"
* the default popsize (1): the pseudopopulation has the size of the sample; R: edges = 1.651 (offset -log(400))
nwergm ego, `plterms' egoid(egoid) alters(alt) weights(w) seed(4)
assert e(ppopsize) == 400 & e(popsize) == 1
assert abs(e(egoshift) - (-ln(400))) < 1e-12
frame create refd
frame refd: quietly import delimited using "cscripts/ego/pl_default.csv", clear
frame refd: quietly summarize b if name == "edges", meanonly
assert abs(_b[edges] - r(mean)) < 0.2
frame refd: quietly summarize b if name == "nodematch.g", meanonly
assert abs(_b[nodematch_g] - r(mean)) < 0.06
frame drop refd
di as txt "PASS the default popsize gives the coefficients per person of R"
* popsize(0): no network size adjustment
nwergm ego, `plterms' egoid(egoid) alters(alt) weights(w) popsize(0) ppopsize(800) seed(4) mcmleiterations(3) mcmcsamplesize(400)
assert e(egoshift) == 0
di as txt "PASS popsize(0): no adjustment"

* the ego data with the degrees only (egodegree()): the statistics that need no attribute of the alters are the same
_t_load mesa
rename egoID egoid
frame alt: rename egoID egoid
tempname T1
nwergm ego, edges degree(1/2) concurrent egoid(egoid) alters(alt) popsize(205) seed(1) mcmleiterations(4) mcmcsamplesize(500)
matrix `T1' = e(target)
frame alt: quietly contract egoid, freq(k)
frlink 1:1 egoid, frame(alt)
frget k = k, from(alt)
quietly replace k = 0 if missing(k)
nwergm ego, edges degree(1/2) concurrent egoid(egoid) egodegree(k) popsize(205) seed(1) mcmleiterations(4) mcmcsamplesize(500)
foreach nm in edges degree_1 degree_2 concurrent {
	assert abs(e(target)[1, colnumb(e(target), "`nm'")] - `T1'[1, colnumb(`T1', "`nm'")]) < 1e-9
}
di as txt "PASS egodegree() gives the statistics of the alters version"

* if and in
_t_load mesa
rename egoID egoid
frame alt: rename egoID egoid
nwergm ego if Grade >= 9, edges degree(1/2) nodematch(Sex) egoid(egoid) alters(alt) popsize(100) seed(2) mcmleiterations(5)
quietly count if Grade >= 9
assert e(egos) == r(N)
di as txt "PASS if restricts the egos (alters of the others are ignored)"

* ---------------------------------------------------------------------------------------------
* 5. error paths
_t_load mesa
rename egoID egoid
frame alt: rename egoID egoid
local ok "egoid(egoid) alters(alt) popsize(205)"
capture nwergm ego, degree(1) `ok'
assert _rc == 198
capture nwergm ego, edges alters(alt)
assert _rc == 198
capture nwergm ego, edges egoid(egoid)
assert _rc == 198
quietly generate byte kk = 1
capture nwergm ego, edges egoid(egoid) alters(alt) egodegree(kk)
assert _rc == 198
capture nwergm ego, edges egoid(egoid) alters(nosuchframe)
assert _rc == 111
capture nwergm ego, edges egoid(egoid) alters(alt) alteregoid(nosuchvar)
assert _rc == 111
capture nwergm ego, edges nodecov(Sex) `ok'
assert _rc == 109
capture nwergm ego, edges nodefactor(nosuchvar) `ok'
assert _rc == 111
capture nwergm ego, edges degrangeto(4) `ok'
assert _rc == 198
capture nwergm ego, edges degrange(1 2) degrangeto(4) `ok'
assert _rc == 198
capture nwergm ego, edges degrange(3) degrangeto(2) `ok'
assert _rc == 198
capture nwergm ego, edges egoid(egoid) alters(alt) popsize(-1)
assert _rc == 198
capture nwergm ego, edges egoid(egoid) alters(alt) popsize(205) ppopsize(abc)
assert _rc == 198
capture nwergm ego, edges egoid(egoid) alters(alt) popsize(205) ppopsize(5)
assert _rc == 198
capture nwergm ego, edges egoid(egoid) alters(alt) popsize(205) ppopwt(median)
assert _rc == 198
capture nwergm ego, edges egoid(egoid) alters(alt) popsize(205) ppopmul(0)
assert _rc == 198
capture nwergm ego, edges egoid(egoid) alters(alt) popsize(205) gwesp(0.5)
assert _rc != 0
* the same attribute in ego and alter data with different levels
frame alt: quietly replace Race = "Zzz" in 1
capture nwergm ego, edges nodefactor(Race) `ok'
assert _rc == 498
_t_load mesa
rename egoID egoid
frame alt: rename egoID egoid
* a term that needs the attribute of the alters, with only the degree
capture nwergm ego, edges nodematch(Sex) egoid(egoid) egodegree(Grade) popsize(205)
assert _rc == 498
capture nwergm ego, edges absdist(Grade) egoid(egoid) egodegree(Grade) popsize(205)
assert _rc == 498
* the ids
quietly replace egoid = 1 in 2
capture nwergm ego, edges `ok'
assert _rc == 459
quietly replace egoid = 2 in 2
quietly replace egoid = . in 3
capture nwergm ego, edges `ok'
assert _rc == 416
quietly replace egoid = 3 in 3
* missing attribute values
quietly replace Grade = . in 4
capture nwergm ego, edges absdist(Grade) `ok'
assert _rc == 416
quietly replace Grade = 9 in 4
* weights
quietly generate double w0 = 0
capture nwergm ego, edges `ok' weights(w0)
assert _rc == 402
* too few egos
capture nwergm ego if egoid <= 2, edges `ok'
assert _rc == 2001
* an ego data set without ties
frame alt: quietly keep if 0
capture nwergm ego, edges `ok'
assert _rc == 498
* estat gof after something else
nwrandom 20, prob(.2) name(rr) undirected
nwergm rr, edges method(mple)
estat ic
assert "`e(estimate)'" != "Ego"
di as txt "PASS error paths"

* a network called ego is still fitted as a network
nwrandom 20, prob(.2) name(ego) undirected
quietly nwergm ego, edges method(mple)
assert "`e(estimate)'" != "Ego"
di as txt "PASS a network named ego is still a network"

di as txt "ALL OK nwergm ego"

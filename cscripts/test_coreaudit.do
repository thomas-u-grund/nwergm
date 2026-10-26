cscript

* Core 3.6.0 audit: the Valued flag is set when a network is created, no longer worked out from the values.
* nwergm accepts a valued network whose ties are all 1 (the graph is binary), refuses other tie values, reads a
* network that is not declared valued as binary (R's ergm without response=), keeps two-mode networks two-mode
* through nwdropnodes, and takes a two-mode covariate network in edgecov() on a two-mode model.
* Expected values are computed independently: the MPLE of an edges-only model is log(ties / (dyads - ties)).

local nwcore : env NWCORE
if `"`nwcore'"' == "" {
	di as error "set the environment variable NWCORE to the directory of the nwcommands (core) package"
	exit 198
}
adopath ++ `"`nwcore'"'
adopath ++ `"`c(pwd)'"'
quietly do `"`nwcore'/unw_core.do"'
quietly do unw_ergm.do

nwclear
clear
set seed 1234
set obs 400
gen int a = ceil(_n/20)
gen int b = mod(_n-1,20)+1
drop if a==b
gen byte x1 = runiform()<.15
gen double val = 1 + floor(runiform()*4)
gen double sh = .1+.9*runiform()
gen double one = 1
count if x1
local t = r(N)
foreach v in "" one val sh {
	preserve
	keep if x1
	nwfromedge a b `v', name(n`v') directed
	restore
}
local expb = ln(`t' / (20*19 - `t'))

nwergm n, edges method(mple)
assert abs(el(e(b),1,1) - `expb') < 1e-6
* valued, every value 1
_nwsyntax none, max(1)
assert "`valued'" == "true"
nwergm none, edges method(mple)
assert abs(el(e(b),1,1) - `expb') < 1e-6
* valued with other values (shares, 1-4, negative): fitted as the binary graph (R: ergm without response=), same coefficients
nwergm n, edges mutual method(mple)
matrix B0 = e(b)
nwergm nval, edges mutual method(mple)
assert mreldif(B0, e(b)) < 1e-10
nwergm nsh, edges mutual method(mple)
assert mreldif(B0, e(b)) < 1e-10
nwergm nsh, edges method(mple)
assert abs(el(e(b),1,1) - `expb') < 1e-6
* not declared valued but holding values: read as binary as well
nwduplicate nsh, name(f)
nwname f, newvalued(false)
nwergm f, edges method(mple)
assert abs(el(e(b),1,1) - `expb') < 1e-6
di as text "  PASS: one-mode valued / binary rules"

* two-mode
nwclear
mata: rseed(5); st_matrix("__B", (runiform(15,8):<.25)); st_matrix("__B2", (runiform(15,8):<.25))
nwset, mat(__B) bipartite name(bp) nooutput
nwset, mat(__B2) bipartite name(bp2) nooutput
mata: st_numscalar("__t", sum(st_matrix("__B")))
local t = scalar(__t)
nwergm bp, edges method(mple)
assert abs(el(e(b),1,1) - ln(`t'/(15*8-`t'))) < 1e-6
* declared valued, ties all 1
nwduplicate bp, name(bpv)
nwname bpv, newvalued(true)
nwergm bpv, edges method(mple)
assert abs(el(e(b),1,1) - ln(`t'/(15*8-`t'))) < 1e-6
* edgecov() with a two-mode covariate network on a two-mode model: statistic = sum of the covariate over the ties
nwergm bp, edges edgecov(bp2) method(mple)
mata: st_numscalar("__obs", __nwergm_last_M.full_statistic(__nwergm_last_G)[1,2])
mata: st_numscalar("__exp", sum(st_matrix("__B") :* st_matrix("__B2")))
assert scalar(__exp) > 0 & scalar(__obs) == scalar(__exp)
* nwdropnodes keeps the two-mode flag: drop 3 of the 8 mode-1 nodes (the first 8 nodes), the columns 1-3 of the matrix
nwduplicate bp, name(bpk)
nwdropnodes bpk, nodes(1/3)
_nwsyntax bpk, max(1)
assert "`is2mode'" == "true" & `nodes' == 20
mata: B = st_matrix("__B"); st_numscalar("__tk", sum(B[., 4..8]))
local tk = scalar(__tk)
nwergm bpk, edges method(mple)
assert abs(el(e(b),1,1) - ln(`tk'/(15*5-`tk'))) < 1e-6
* a two-mode model with a bipartite term on the kept network
nwergm bpk, edges bdegree1(2) method(mple)
assert colsof(e(b)) == 2
di as text "  PASS: two-mode rules"
di as text "test_coreaudit (nwergm) PASS"

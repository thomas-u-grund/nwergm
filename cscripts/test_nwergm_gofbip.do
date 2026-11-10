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
do unw_ergm.do

* estat gof, gof(b1degree b2degree) after a two-mode fit: the fit was taken for a one-mode network
* (the detection read a count that is always 0), so both statistics were refused with "needs a two-mode network".
* Reference: R ergm 4.12.0, gof(fit, GOF = ~ b1degree + b2degree) on the same network (with the 10 columns of the
* incidence matrix as the first mode, as nwergm has them): the observed degree distributions are identical.

* two-mode network from an 8 x 10 incidence matrix (nwset puts the 10 columns in the first mode)
nwclear
clear
mata: rseed(13); B = runiform(8,10) :< 0.3; st_matrix("Bbip", B)
nwset, mat(Bbip) bipartite name(bip) nooutput
local mc mcmcsamplesize(300) mcmcburnin(500) mcmcinterval(20) mcmleiterations(3) seed(1)

qui nwergm bip, edges bstar1(2) `mc'
estat gof, gof(b1degree b2degree)
* first mode (10 nodes): degrees 0..4 -> 0 3 4 2 1; second mode (8 nodes): 0 1 3 2 2
matrix G1 = r(gof_b1degree)
matrix G2 = r(gof_b2degree)
assert rowsof(G1) == 9
assert rowsof(G2) == 11
local want1 "0 3 4 2 1 0 0 0 0"
local want2 "0 1 3 2 2 0 0 0 0 0 0"
forvalues i = 1/9 {
	local w : word `i' of `want1'
	assert G1[`i', 1] == `w'
}
forvalues i = 1/11 {
	local w : word `i' of `want2'
	assert G2[`i', 1] == `w'
}
* the one-mode only statistics are still refused on a two-mode fit
capture estat gof, gof(degree)
assert _rc == 198
* Nodes of a two-mode network stored with the modes interleaved (davis: nodes sorted by name, women and events
* mixed). The degree and shared-partner counts of estat gof took the first n1 nodes as mode 1 (nwergm 1.5.8 and
* earlier), which gave 4 "isolated" women and degree sums of 72 instead of 89. Each mode's degree sum must be the
* number of ties; the women's and events' degrees are those of Davis, Gardner and Gardner (1941).
nwclear
nwwebuse davis, nwclear
qui nwergm davis, edges
estat gof, nsim(20) seed(1)
foreach t in b1degree b2degree dspartners {
	matrix G = r(gof_`t')
	local s = 0
	local c = 0
	forvalues i = 1/`=rowsof(G)' {
		local s = `s' + (`i' - 1) * G[`i', 1]
		local c = `c' + G[`i', 1]
	}
	local s_`t' = `s'
	local c_`t' = `c'
}
assert `c_b1degree' == 18 & `s_b1degree' == 89 & r(gof_b1degree)[1, 1] == 0
assert `c_b2degree' == 14 & `s_b2degree' == 89
* every pair of nodes of the same mode once: C(18,2) + C(14,2)
assert `c_dspartners' == 153 + 91
* women's degrees (Davis): 2 2 2 3 4 4 4 4 4 4 5 6 7 7 7 8 8 8
local want "0 0 3 1 6 1 1 3 3"
forvalues i = 1/9 {
	local w : word `i' of `want'
	assert r(gof_b1degree)[`i', 1] == `w'
}
di "PASS test_nwergm_gofbip"

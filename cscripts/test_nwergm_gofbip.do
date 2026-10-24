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
di "PASS test_nwergm_gofbip"

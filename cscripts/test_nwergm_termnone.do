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

* mcmletermination(none) failed with "subscript invalid" (r(3301)) for about 1 seed in 6: without a convergence
* test the sample-size boost used Fstat/Fcrit, which is below 1 when the test would pass, and shrank the sample to a
* single draw, which the variance step then could not handle.  Seeds 4 11 12 13 17 27 failed before the fix.
nwclear
clear
mata: n = 24; rseed(11); R = runiform(n,n) :< 0.18; R = R :* (1 :- I(n)); st_matrix("Aund", ((R + R') :> 0))
nwset, mat(Aund) undirected name(und) nooutput
local nfail 0
forvalues s = 1/30 {
	capture quietly nwergm und, edges triangle mcmletermination(none) mcmcsamplesize(300) mcmcburnin(500) mcmcinterval(20) mcmleiterations(3) seed(`s')
	if _rc {
		di "seed `s' failed with r(" _rc ")"
		local ++nfail
	}
}
assert `nfail' == 0
di "PASS test_nwergm_termnone"

* Certifies estat mcmcdiag's effective sample size against coda.
* ESS = n*var(x)/spectrum0.ar(x), as coda::effectiveSize(). Reference
* values: coda 0.19 effectiveSize() on e(mcmcsample) of this exact fit
* (Faux Mesa High, edges + nodematch(grade race) + gwesp(.25),
* seed(12345), mcmcinterval(1000), mcmcburnin(20000)):
* 277.8 262.0 317.8 291.8. The lag-1 AR(1) formula used before gave
* 472-539 on the same chain.
clear all
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
set more off
nwwebuse mesa, nwclear
encode race, generate(racen)
qui nwergm mesa, edges nodematch(grade racen) gwesp(.25) seed(12345) ///
	mcmcinterval(1000) mcmcburnin(20000) mcmleeffectivesize(0) mcmcsamplesize(3000)
qui estat mcmcdiag
matrix E = r(ess)
matrix R = (277.8, 262.0, 317.8, 291.8)
forvalues k = 1/4 {
	assert abs(E[1,`k'] - R[1,`k']) / R[1,`k'] < 0.01
}
* estat gof defaults follow the fit's MCMC settings (as R's gof.ergm)
qui estat gof, seed(1) nsim(5)
di "test_nwergm_ess.do: ALL TESTS PASSED"

cscript

* The MCMC defaults are those of R's ergm 4.12.0 (MCMLE.interval 1024, MCMLE.burnin = 16 x interval = 16384) and the
* documented defaults are what runs. The old fast settings stay reachable by naming them.
local nwcore : env NWCORE
if `"`nwcore'"' == "" {
	di as error "set the environment variable NWCORE to the directory of the nwcommands (core) package"
	exit 198
}
adopath ++ `"`nwcore'"'
adopath ++ `"`c(pwd)'"'
quietly do `"`nwcore'/unw_core.do"'
do unw_ergm.do
capture adopath ++ "lib/plugins/macos"
capture adopath ++ "lib/plugins/unix"
capture adopath ++ "lib/plugins/windows"

nwclear
clear
mata: rseed(4); n = 25; R = runiform(n,n) :< 0.15; R = R :* (1 :- I(n)); R = ((R + R') :> 0); st_matrix("A", R)
nwset, mat(A) undirected name(un) nooutput
local base "edges triangle mcmleiterations(2) mcmcsamplesize(200) nologlik seed(1)"

* A: nothing given -> R's values
qui nwergm un, `base'
assert e(mcmc_interval) == 1024
assert e(mcmc_burnin) == 16384
assert e(mcmc_samplesize) == 200
di "PASS defaults are interval 1024 and burn-in 16384"

* B: only the interval given -> the burn-in follows (R: MCMLE.burnin = MCMLE.interval * 16)
qui nwergm un, `base' mcmcinterval(100)
assert e(mcmc_interval) == 100
assert e(mcmc_burnin) == 1600
di "PASS burn-in follows an explicit interval"

* C: only the burn-in given -> the interval stays at its default
qui nwergm un, `base' mcmcburnin(500)
assert e(mcmc_interval) == 1024
assert e(mcmc_burnin) == 500
di "PASS explicit burn-in is kept"

* D: explicit values, the old ones included, are used as given
qui nwergm un, `base' mcmcburnin(3000) mcmcinterval(50)
assert e(mcmc_interval) == 50
assert e(mcmc_burnin) == 3000
qui nwergm un, `base' mcmcburnin(0) mcmcinterval(10)
assert e(mcmc_interval) == 10
assert e(mcmc_burnin) == 0
di "PASS explicit values, the old defaults among them, are used unchanged"

* E: the default fit is the fit with the values written out (same seed)
qui nwergm un, `base'
matrix b1 = e(b)
qui nwergm un, `base' mcmcburnin(16384) mcmcinterval(1024)
matrix b2 = e(b)
assert mreldif(b1, b2) < 1e-12
di "PASS default fit equals the fit with the documented values written out"

* F: nwergm simulate has the same defaults
qui nwergm simulate 20, edges theta(-2) nsim(1) seed(3) generate(sd1)
qui nwtomata sd1, mat(S1)
qui nwergm simulate 20, edges theta(-2) nsim(1) seed(3) generate(sd2) mcmcburnin(16384) mcmcinterval(1024)
qui nwtomata sd2, mat(S2)
mata: assert(max(abs(S1 :- S2)) == 0)
qui nwergm simulate 20, edges theta(-2) nsim(1) seed(3) generate(sd3) mcmcinterval(1024)
qui nwtomata sd3, mat(S3)
mata: assert(max(abs(S1 :- S3)) == 0)
di "PASS nwergm simulate defaults"

* G: the help file and the dialogs state the defaults that run
mata: L = cat("nwergm.sthlp")
mata: i = selectindex(strpos(L, "{opt mcmcinterval(int)}}") :> 0); assert(rows(i) >= 1); assert(strpos(L[i[1]], "default 1,024") > 0); assert(strpos(L[i[1]], "mcmcburnin(3000) mcmcinterval(50)") > 0)
mata: i = selectindex(strpos(L, "{opt mcmcburnin(int)}}") :> 0); assert(rows(i) >= 1); assert(strpos(L[i[1]], "16,384") > 0)
mata: D = cat("nwergm.dlg")
mata: assert(sum(strpos(D, `"label("default 16 x mcmcinterval (16384)")"') :> 0) == 1)
mata: assert(sum(strpos(D, `"label("default 1024 (the old default was 50)")"') :> 0) == 1)
mata: assert(sum(strpos(D, `"label("default 50")"') :> 0) == 0)
di "PASS help file and dialog state the running defaults"
di "test_nwergm_rdefaults: ALL OK"

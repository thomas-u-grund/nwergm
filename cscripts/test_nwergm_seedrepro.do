cscript

* seed() must reproduce an MCMLE fit exactly, whatever was loaded or fitted before it in the session.
* Regression test: the edge order of the starting network (which steers the MCMC) used to depend on the
* order in which the core returned the neighbors of a node, which differed after another network had been
* loaded, so the same fit and seed gave edges -3.375 in one session and -3.325 in another.
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

local model "edges mutual nodematch(prac) gwesp(0.5)"
local opts "seed(1) mcmleiterations(3) mcmcsamplesize(1000) nologlik"

* A: Lazega alone, fitted twice
nwwebuse lazega, nwclear
encode practice, generate(prac)
nwergm lazega_fr, `model' `opts'
matrix bA1 = e(b)
nwergm lazega_fr, `model' `opts'
matrix bA2 = e(b)
assert mreldif(bA1, bA2) < 1e-12
di "PASS same call twice: identical"

* B: another network is loaded and fitted first, then the same fit
nwwebuse mesa, nwclear
nwergm mesa, edges
nwwebuse lazega, nwclear
encode practice, generate(prac)
nwergm lazega_fr, `model' `opts'
matrix bB = e(b)
assert mreldif(bA1, bB) < 1e-12
di "PASS other network loaded and fitted before: identical"

* C: a different seed gives a different fit
nwergm lazega_fr, `model' seed(2) mcmleiterations(3) mcmcsamplesize(1000) nologlik
matrix bC = e(b)
assert mreldif(bA1, bC) > 1e-6
di "PASS different seed: different"
di "test_nwergm_seedrepro: ALL OK"

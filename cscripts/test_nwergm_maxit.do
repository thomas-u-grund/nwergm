cscript

* MCMLE stops at mcmleiterations() (R: MCMLE.maxit) with a warning and e(converged) = 0, also on a model where the
* Newton step is stuck. Regression test for a report that bgwdegreefree2() on a simulated 30 x 12 two-mode network "did
* not finish": the loop is bounded, but on that degenerate fit the thinning interval grows to its cap of 20000 within
* eight iterations and every further iteration costs about a minute, so 60 iterations take about an hour.
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

clear
set seed 20261024
nwclear
mata:
g1 = (runiform(30,1) :> 0.5) :+ 1
g2 = (runiform(12,1) :> 0.5) :+ 1
P = J(30,12,0.08)
for (i=1;i<=30;i++) for (j=1;j<=12;j++) if (g1[i]==g2[j]) P[i,j] = 0.30
B = (runiform(30,12) :< P)
st_matrix("B", B')
end
nwset, mat(B) bipartite name(clubs)
set obs 42
generate byte kind = .
mata: st_store(., "kind", (g1 \ g2))

timer clear 1
timer on 1
nwergm clubs, edges nodemix(kind) bgwdegreefree2(0.5) seed(1) mcmleiterations(3) nologlik
timer off 1
quietly timer list 1
assert e(mcmle_iterations) == 3
assert e(converged) == 0
assert r(t1) < 120
di "PASS MCMLE stopped at mcmleiterations(3) with converged = 0 in " r(t1) " seconds"
di "test_nwergm_maxit: ALL OK"

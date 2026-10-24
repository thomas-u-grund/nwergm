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

* obsconstraints(b1degrees) / obsconstraints(b2degrees) on a two-mode network crashed Stata (exit 139): the
* graph that carries the observation constraints was not marked two-mode, so the plugin was given a two-mode model
* with an empty mode table.  A crash here ends the do-file before the PASS line.
* Reference: R ergm 4.12.0, obs.constraints = ~b1degrees / ~b2degrees on the same incidence matrix (R's modes are
* the other way round: nwergm b1degrees = R's b2degrees), model edges + one star term: R gives edges -0.16, star2 -0.50
* and edges 0.14, star2 -0.52 (the constraint fixes every statistic, so both equal the unconstrained fit).

* two-mode network from an 8 x 10 incidence matrix (nwset puts the 10 columns in the first mode)
nwclear
clear
mata: rseed(13); B = runiform(8,10) :< 0.3; st_matrix("Bbip", B)
nwset, mat(Bbip) bipartite name(bip) nooutput
local mc mcmcsamplesize(300) mcmcburnin(500) mcmcinterval(20) mcmleiterations(3) seed(1)

local big mcmcsamplesize(3000) mcmcburnin(5000) mcmcinterval(50) mcmleiterations(20) seed(2)
qui nwergm bip, edges bstar1(2) obsconstraints(b1degrees) `big'
assert "`e(obsconstraints)'" == "b1degrees"
assert abs(_b[edges] + 0.16) < 0.6
assert abs(_b[b1star_2] + 0.50) < 0.35
qui nwergm bip, edges bstar2(2) obsconstraints(b2degrees) `big'
assert "`e(obsconstraints)'" == "b2degrees"
assert abs(_b[edges] - 0.14) < 0.6
assert abs(_b[b2star_2] + 0.52) < 0.35
* both together
qui nwergm bip, edges bstar1(2) obsconstraints(b1degrees + b2degrees) `mc'
* a one-mode network keeps refusing them
mata: n = 12; rseed(4); R = runiform(n,n) :< 0.2; R = R :* (1 :- I(n)); st_matrix("Au", ((R + R') :> 0))
nwset, mat(Au) undirected name(un) nooutput
capture nwergm un, edges triangle obsconstraints(b1degrees) `mc'
assert _rc != 0
di "PASS test_nwergm_obsbdeg"

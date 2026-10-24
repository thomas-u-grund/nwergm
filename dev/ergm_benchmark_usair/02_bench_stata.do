/*
	Real-world nwergm benchmark: US airport route network, edges +
	mutual (does route reciprocity exceed chance - a natural real
	question on this data), fit via nwergm with default control
	settings, on the exact edgelist 01_prep_network.do exported.
*/
adopath + "/Users/tgrund/FILES_NEW/SOFTWARE/nwcommands/lib"
adopath + "/Users/tgrund/FILES_NEW/SOFTWARE/nwcommands"
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
run "/Users/tgrund/FILES_NEW/SOFTWARE/nwcommands/nwergm.ado"

local ddir "/Users/tgrund/FILES_NEW/SOFTWARE/nwcommands/dev/ergm_benchmark_usair"

nwclear
import delimited "`ddir'/usair_edgelist.csv", clear varnames(nonames)
nwfromedge v1 v2, directed name(usair_fit)

timer clear 1
set seed 999
timer on 1
nwergm usair_fit, edges mutual
timer off 1
timer list 1

di
di "======================================"
di "STATA nwergm: US airport routes, 549 nodes, 5450 ties, edges + mutual"
di "======================================"
di "Wall time: " %8.3f r(t1) " seconds"
di "Converged: " e(converged)
di "MCMLE iterations: " e(mcmle_iterations)
matrix list e(b)
matrix list e(V)

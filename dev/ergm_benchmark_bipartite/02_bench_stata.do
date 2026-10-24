/*
	Bipartite speed benchmark, Stata side: 60x40 bipartite network
	(dev/ergm_benchmark_bipartite/bipnet.csv, generated once by
	01_generate_network.do), edges + bstar1(2), method(mcmle) via
	nwergm's own TRUE DEFAULTS (no mcmcburnin()/mcmcinterval()/
	mcmcsamplesize()/mcmleiterations() specified) - matching the
	sibling dev/ergm_benchmark_r_vs_stata/20_bench_100undir_gwesp.do's
	own "both sides at default settings" discipline exactly.

	Bipartite models are Mata-only in v1 (ErgmNativeSetup() bails out on
	G.bipartite regardless of term names - see the development notes
	unit 155) - this benchmark exists specifically to measure how much
	that costs relative to R, not assumed.
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

local ddir "/Users/tgrund/FILES_NEW/SOFTWARE/nwcommands/dev/ergm_benchmark_bipartite"

nwclear
import delimited using "`ddir'/bipnet.csv", clear varnames(1)
nwset person event, twomode name(bipbench)

nw_syntax bipbench, max(1)
di "nodes=`nodes' is2mode=`is2mode' directed=`directed'"

timer clear 1
set seed 999
timer on 1
nwergm bipbench, edges bstar1(2)
timer off 1
timer list 1

di
di "======================================"
di "STATA nwergm: 60x40 bipartite, edges + bstar1(2), method(mcmle), true defaults"
di "======================================"
di "Wall time: " %8.3f r(t1) " seconds"
di "Converged: " e(converged)
di "MCMLE iterations: " e(mcmle_iterations)
matrix list e(b)
matrix list e(V)

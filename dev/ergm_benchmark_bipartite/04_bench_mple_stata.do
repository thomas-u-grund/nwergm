/*
	Same 60x40 bipartite network, but the Stage 2 (dyad-independent)
	case: edges + bcov1(age) - method(mple), a closed-form `logit` call
	on both sides, no MCMC at all. Included alongside 02/03's own
	MCMLE benchmark since the two term families have very different
	computational paths (deterministic design-matrix build + one
	`logit` call vs. an iterative MCMC/Newton loop) and "how much does
	bipartite cost relative to R" has a different answer for each.
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
nwset person event, twomode name(bipbenchmple)

gen age = .
forvalues i = 1/60 {
	replace age = runiform()*40 + 20 in `i'
}

timer clear 2
timer on 2
nwergm bipbenchmple, edges bcov1(age)
timer off 2
timer list 2

di
di "======================================"
di "STATA nwergm: 60x40 bipartite, edges + bcov1(age), method(mple)"
di "======================================"
di "Wall time: " %8.3f r(t2) " seconds"
matrix list e(b)

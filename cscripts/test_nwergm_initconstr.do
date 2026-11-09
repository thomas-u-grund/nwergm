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
* init() under a dyad-dependent constraint and with missing dyads: Monte Carlo maximum likelihood starts at the
* values given in init(), as R's ergm() does; only coefficients without a given value start at zero. With step
* length 0 and one iteration the fit returns its starting point.
nwclear
clear
set obs 12
gen g = ceil(_n/4)
nwset, mat((0,0,0,0,0,0,1,0,0,1,1,1 \ 0,0,0,1,0,0,0,0,1,0,0,1 \ 0,0,0,0,1,0,0,1,0,0,0,0 \ 0,1,0,0,0,1,0,0,1,0,0,0 \ 0,0,1,0,0,0,0,0,0,0,0,0 \ 0,0,0,1,0,0,0,0,1,0,0,0 \ 1,0,0,0,0,0,0,1,0,0,0,0 \ 0,0,1,0,0,0,1,0,0,0,0,1 \ 0,1,0,1,0,1,0,0,0,1,0,0 \ 1,0,0,0,0,0,0,0,1,0,1,0 \ 1,0,0,0,0,0,0,0,0,1,0,0 \ 1,1,0,0,0,0,0,1,0,0,0,0)) undirected name(U)
local ctl "method(mcmle) mcmleiterations(1) mcmletermination(none) mcmlesteplength(0) mcmlestepmargin(.) mcmleeffectivesize(0) mcmcsamplesize(500) mcmcburnin(2000) mcmcinterval(100) seed(3)"
capture program drop _ic_chk
program _ic_chk
	args what name want
	local got = _b[`name']
	if abs(`got' - `want') > 1e-10 {
		di as err "FAIL `what': `name' starts at `got', not `want'"
		exit 9
	}
	di "PASS `what': `name' starts at `want'"
end
* all free coefficients given
qui nwergm U, edges nodematch(g) triangle constraints(degrees) init(. -0.7 0.4) `ctl'
_ic_chk "complete init, degrees" nodematch_g -0.7
_ic_chk "complete init, degrees" triangle 0.4
* some given: the given value is kept, the others start at zero
qui nwergm U, edges nodematch(g) triangle constraints(degrees) init(. . 0.4) `ctl'
_ic_chk "partial init, degrees" nodematch_g 0
_ic_chk "partial init, degrees" triangle 0.4
* without init() the start is zero, as in R
qui nwergm U, edges nodematch(g) triangle constraints(degrees) `ctl'
_ic_chk "no init, degrees" nodematch_g 0
_ic_chk "no init, degrees" triangle 0
* missing dyads: the fit with a second, constrained sample also starts at the values given in init()
import delimited using "dev/ergm_missing/u_nodes.csv", clear
tempfile nodes
save `nodes'
import delimited using "dev/ergm_missing/u_adj.csv", clear varnames(nonames)
mkmat v*, matrix(A)
nwclear
nwset, mat(A) undirected name(un)
use `nodes', clear
qui nwergm un, edges triangle init(-1.5 0.1) `ctl'
_ic_chk "complete init, missing dyads" edges -1.5
_ic_chk "complete init, missing dyads" triangle 0.1
qui nwergm un, edges triangle init(. 0.1) `ctl'
_ic_chk "partial init, missing dyads" triangle 0.1
di "ALL OK"

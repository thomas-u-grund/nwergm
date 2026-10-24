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

* constraints(observed) / obsconstraints(observed).  R ergm 4.12.0: the observed constraint frees exactly the missing
* dyads (free_dyads = the missing ones).  obs.constraints = ~observed is the default treatment of missing dyads;
* constraints = ~observed on a network with missing dyads stops inside R ('types' and 'constraints' are not the same
* length); on a network without missing dyads R drops the empty constraint and fits the unconstrained model
* (simulate() and ergm() checked).  Before: constraints(observed) gave "no observations", obsconstraints(observed)
* a conformability error r(3200).
local d "dev/ergm_missing"
import delimited using "`d'/u_adj.csv", clear varnames(nonames)
mkmat v*, matrix(A)
nwclear
nwset, mat(A) undirected name(un) nooutput
mata: A0 = editmissing(st_matrix("A"), 0); st_matrix("A0", A0)
nwset, mat(A0) undirected name(comp) nooutput
local mc mcmcsamplesize(1000) mcmcburnin(2000) mcmcinterval(50) mcmleiterations(10) seed(1)

* missing dyads: obsconstraints(observed) is the default missing-data fit
qui nwergm un, edges triangle `mc'
local b0 = _b[edges]
local t0 = _b[triangle]
qui nwergm un, edges triangle obsconstraints(observed) `mc'
assert e(nmissing) == 3
assert "`e(obsconstraints)'" == "observed"
assert abs(_b[edges] - `b0') < 0.25
assert abs(_b[triangle] - `t0') < 0.3
* constraints(observed) with missing dyads: a plain error, as R stops
capture nwergm un, edges triangle constraints(observed) `mc'
assert _rc == 198
capture nwergm un, edges triangle constraints(observed + edges) `mc'
assert _rc == 198

* no missing dyads: R fits without the (empty) constraint
qui nwergm comp, edges triangle `mc'
local b1 = _b[edges]
qui nwergm comp, edges triangle constraints(observed) `mc'
assert abs(_b[edges] - `b1') < 0.2
qui nwergm comp, edges triangle obsconstraints(observed) `mc'
assert abs(_b[edges] - `b1') < 0.2
assert "`e(obsconstraints)'" == ""
di "PASS test_nwergm_observed"

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

* A fit with a shared-partner term on a random network of 5000 nodes (12.5 million dyads) stopped with r(198)
* "observation number out of range": the number of rows of the pseudolikelihood data was passed to the next step as
* text with strofreal(), which writes a large number in scientific notation (1.12e+07).  One short chain is enough.
nwclear
clear
set seed 20261025
mata: n = 5000; m = round(3 * n); i = ceil(runiform(m, 1) * n); j = ceil(runiform(m, 1) * n); k = selectindex(i :< j); E = i[k], j[k]; E = uniqrows(E); st_matrix("EE", E)
svmat double EE, names(e)
drop if missing(e1)
nwfromedge e1 e2, undirected name(rnet)
clear
* the count of dyads as it is formatted for a macro must be an integer string
mata: st_local("s", strofreal(12497500, "%18.0g")); assert(st_local("s") == "12497500")
qui nwergm rnet, edges gwesp(0.5) mcmcsamplesize(100) mcmcburnin(1000) mcmcinterval(100) mcmleiterations(1) seed(1)
assert "`e(cmd)'" == "nwergm"
assert e(b)[1,1] < 0
di "PASS test_nwergm_bigdyads"

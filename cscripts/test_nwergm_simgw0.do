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

* nwergm simulate: a geometrically weighted term with decay 0 is a term of the model (it was dropped, so that
* theta() had one coefficient too many); a decay that is not a number is an error.
* 6 nwergm simulate: gwesp(0) is a term
nwclear
nwergm simulate 20, edges gwesp(0) theta(-2 .3) nsim(1)
capture nwergm simulate 20, edges gwesp(0) theta(-2) nsim(1)
assert _rc != 0
capture nwergm simulate 20, edges gwesp(abc) theta(-2 .3) nsim(1)
assert _rc == 198
nwergm simulate 20, edges gwesp(.5) theta(-2 .3) nsim(1)
di "PASS ergmsim"
di "PASS test_nwergm_simgw0"

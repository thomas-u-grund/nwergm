* test_nwergm_structopt: a term that is an option of nwergm itself (gwesp(), nodematch()) given inside
* structural() stops with a message saying it is an option; structural terms still work
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
set linesize 80
nwwebuse lazega, nwclear

capture noisily nwergm lazega_adv, edges structural(gwesp(.5))
assert _rc == 198
capture noisily nwergm lazega_adv, edges structural(twopath nodematch(office))
assert _rc == 198
nwergm lazega_adv, edges structural(twopath) method(mple)
assert colnumb(e(b), "twopath") < .
* the option itself, outside structural(), is what the message points to
nwergm lazega_adv, edges gwesp(.5) method(mple)
assert colnumb(e(b), "gwesp") < . | colnumb(e(b), "gwesp.fixed.0.5") < . | colsof(e(b)) == 2
di "PASS test_nwergm_structopt"

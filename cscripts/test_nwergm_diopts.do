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

* Coefficient tables show the names in full by default: names of up to 32 characters do not fit next to the confidence
* intervals below linesize 100, so the intervals are then left out (as with noci). ci, or level(#) given explicitly, shows
* the intervals with the names cut (nodematch_o~e), as up to 1.7.1. Display options (noci, nopvalues, cformat(), ...)
* for fits and the replay.
capture program drop _logcount
program _logcount, rclass
	// number of lines of a log file that contain a string
	args fn what
	tempname fh
	local n 0
	file open `fh' using `"`fn'"', read text
	file read `fh' line
	while r(eof) == 0 {
		if strpos(`"`macval(line)'"', `"`what'"') local ++n
		file read `fh' line
	}
	file close `fh'
	return scalar n = `n'
end
set linesize 80
nwuse `"`nwcore'/data/lazega"', nwclear
tempfile l1 l2 l3 l4
* 1. default: full names, no intervals; with ci: intervals, cut names
log using `l1', text replace name(t1)
nwergm lazega_adv, edges nodematch(office) nodeofactor(status)
log close t1
_logcount `l1' "nodeofactor_status_2 |"
assert r(n) == 1
_logcount `l1' "conf. interval"
assert r(n) == 0
log using `l2', text replace name(t2)
nwergm lazega_adv, edges nodematch(office) nodeofactor(status) ci
log close t2
_logcount `l2' "nodematch_o~e"
assert r(n) == 1
_logcount `l2' "[95% conf. interval]"
assert r(n) == 1
di "PASS fit: full names by default, intervals with ci"

* 2. replay: default, ci, level(), noci, nopvalues, cformat(); the intervals are left out at linesize 80 whatever the names
log using `l3', text replace name(t3)
nwergm
nwergm, noci
nwergm, ci
nwergm, level(90)
nwergm, nopvalues cformat(%9.3f)
estimates replay
log close t3
_logcount `l3' "nodematch_office |"
assert r(n) == 4
_logcount `l3' "nodematch_o~e"
assert r(n) == 2
_logcount `l3' "[90% conf. interval]"
assert r(n) == 1
_logcount `l3' "1.314 "
assert r(n) >= 1
rcof "nwergm, noci nopvalues" == 198
rcof "nwergm, ci noci" == 198
rcof "nwergm lazega_adv, edges bogus" == 198
rcof "nwergm lazega_adv, edges noci noci" == 198
log using `l4', text replace name(t4)
nwergm lazega_adv, edges mutual method(mple)
log close t4
_logcount `l4' "[95% conf. interval]"
assert r(n) == 0
log using `l4', text replace name(t4)
nwergm lazega_adv, edges mutual method(mple) ci
log close t4
_logcount `l4' "[95% conf. interval]"
assert r(n) == 1
* from linesize 100 on there is room for both
set linesize 100
log using `l4', text replace name(t4)
nwergm lazega_adv, edges nodematch(office) nodeofactor(status)
log close t4
set linesize 80
_logcount `l4' "nodeofactor_status_2 |"
assert r(n) == 1
_logcount `l4' "[95% conf. interval]"
assert r(n) == 1
di "PASS replay and display options"

* 3. nodemix() names and lincom after a fit
nwergm lazega_adv, edges nodemix(status) noci
lincom nodemix_status_2_2 - nodemix_status_2_1
assert abs(r(estimate) - (_b[nodemix_status_2_2] - _b[nodemix_status_2_1])) < 1e-12
di "PASS nodemix() names and lincom"
di "ALL TESTS PASSED"

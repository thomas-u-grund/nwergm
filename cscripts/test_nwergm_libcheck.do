cscript

* A core and an nwergm Mata library built for different versions give r(3021) at the first Mata call; nwergm must print a
* plain message and exit with that code.  The mismatch is simulated by a session function that stops with 3021
* (a function in memory takes precedence over the library).
local nwcore : env NWCORE
if `"`nwcore'"' == "" {
	di as error "set the environment variable NWCORE to the directory of the nwcommands (core) package"
	exit 198
}
adopath ++ `"`nwcore'"'
adopath ++ `"`c(pwd)'"'
quietly do `"`nwcore'/unw_core.do"'
do unw_ergm.do

nwclear
clear
mata: rseed(4); n = 12; R = runiform(n,n) :< 0.2; R = R :* (1 :- I(n)); R = ((R + R') :> 0); st_matrix("A", R)
nwset, mat(A) undirected name(un) nooutput

* matching libraries: no message, the fit works
_nwergm_libcheck
qui nwergm un, edges mcmcsamplesize(100) mcmcburnin(200) mcmcinterval(10) mcmleiterations(2) seed(1)

* simulated mismatch
mata: mata drop ergm_libcheck()
mata:
void ergm_libcheck()
{
	_error(3021)
}
end
log using _libcheck_msg.log, text replace name(lc)
capture noisily nwergm un, edges
local rc = _rc
log close lc
assert `rc' == 3021
tempname fh
file open `fh' using _libcheck_msg.log, read text
local found 0
file read `fh' line
while r(eof) == 0 {
	if strpos(`"`line'"', "built for different versions") local found 1
	file read `fh' line
}
file close `fh'
erase _libcheck_msg.log
assert `found' == 1
di as txt "test_nwergm_libcheck: ALL OK"

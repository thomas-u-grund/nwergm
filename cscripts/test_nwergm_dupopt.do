* test_nwergm_dupopt: an option given twice (edgecov(a) edgecov(b)) stops with a message that says to
* list the networks in one option; one edgecov() with several networks equals the fit it describes
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
* the output of a failing command, all lines joined, in a local of the caller
capture program drop _t_msg
program define _t_msg
	args lname
	gettoken lname 0 : 0
	tempfile lg
	quietly log using `"`lg'"', text replace name(_tdo)
	capture noisily `0'
	local rc = _rc
	quietly log close _tdo
	tempname fh
	local all ""
	file open `fh' using `"`lg'"', read text
	file read `fh' line
	while r(eof) == 0 {
		local all `"`all' `macval(line)'"'
		file read `fh' line
	}
	file close `fh'
	c_local `lname' `"`all'"'
	c_local rc `rc'
end
* 1. edgecov() twice
_t_msg out nwergm lazega_adv, edges edgecov(lazega_fr) edgecov(lazega_cow)
assert `rc' == 198
assert strpos(`"`out'"', "edgecov() is given more than once")
assert strpos(`"`out'"', "edgecov(lazega_fr lazega_cow)")
assert !strpos(`"`out'"', "not allowed")
di as text "PASS: edgecov() twice names the one-option form"
* 2. the form the message names works and has one coefficient per network
nwergm lazega_adv, edges edgecov(lazega_fr lazega_cow)
local names : colnames e(b)
assert "`names'" == "edges edgecov_lazega_fr edgecov_lazega_cow"
di as text "PASS: edgecov(lazega_fr lazega_cow)"
* 3. other options: variables, and an option with suboptions
_t_msg out nwergm lazega_adv, edges nodecov(seniority) nodecov(age)
assert `rc' == 198
assert strpos(`"`out'"', "nodecov(seniority age)")
_t_msg out nwergm lazega_adv, edges hamming(lazega_fr) hamming(lazega_cow)
assert `rc' == 198
assert strpos(`"`out'"', "hamming(lazega_fr lazega_cow)")
_t_msg out nwergm lazega_adv, edges nodefactor(seniority, base(1)) nodefactor(age)
assert `rc' == 198
assert strpos(`"`out'"', "nodefactor() is given more than once")
di as text "PASS: other repeated options"
* 4. names inside an option (structural(), operators()) are not counted, nor are options given once
_t_msg out nwergm lazega_adv, edges nodecov(seniority) edgecov(lazega_fr) method(mple)
assert `rc' == 0
_t_msg out nwergm lazega_adv, edges structural(gwesp(.5, fixed)) edgecov(lazega_fr) method(mple)
assert !strpos(`"`out'"', "given more than once")
di as text "PASS: no false alarms"

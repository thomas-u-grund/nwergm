cscript

* Regression test: when the MCMLE sampler does not mix, nwergm stops with the message "Unconstrained MCMC sampling did not
* mix at all" and r(498) only. Before, the user also saw a Mata traceback ("ErgmMCMLE(): 498 Stata returned error",
* "<istmt>: - function returned error") after the message.

local nwcore : env NWCORE
if `"`nwcore'"' == "" {
	di as error "set the environment variable NWCORE to the directory of the nwcommands (core) package"
	exit 198
}
adopath ++ `"`nwcore'"'
adopath ++ `"`c(pwd)'"'
quietly do `"`nwcore'/unw_core.do"'
do unw_ergm.do
global nwwebpath `"`nwcore'/data"'

nwclear
nwwebuse mesa, nwclear
encode race, gen(racen)

tempfile lg
log using `"`lg'"', text replace name(fixes1)
capture noisily nwergm mesa, edges nodematch(grade racen) triangle seed(1)
local rc = _rc
log close fixes1
assert `rc' == 498

tempname fh
local text ""
file open `fh' using `"`lg'"', read text
file read `fh' line
while r(eof) == 0 {
	local text `"`text' `macval(line)'"'
	file read `fh' line
}
file close `fh'
assert strpos(`"`text'"', "did not mix at all") > 0
assert strpos(`"`text'"', "ErgmMCMLE()") == 0
assert strpos(`"`text'"', "function returned error") == 0
di as text "  PASS: non-mixing chain gives the message and r(498) without a Mata traceback"
di as result "ALL TESTS PASSED"

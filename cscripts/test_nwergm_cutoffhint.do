cscript

capture adopath ++ "."
capture adopath ++ "lib"
local nwcore : env NWCORE
if `"`nwcore'"' == "" {
	di as error "set the environment variable NWCORE to the directory of the nwcommands (core) package"
	exit 198
}
adopath ++ `"`nwcore'"'
adopath ++ `"`c(pwd)'"'
quietly do `"`nwcore'/unw_core.do"'
do unw_ergm.do
capture adopath ++ "lib/plugins/macos"
capture adopath ++ "lib/plugins/unix"
capture adopath ++ "lib/plugins/windows"

* A curved fit (gwespfree) of the mesa network with seed(3) stops with r(498): an MCMLE iteration moves the decay to about 10, at which the
* simulated networks degenerate and a shared-partner count of 31 exceeds the default gwcutoff(30). R's ergm(... gwesp(.25, fixed = FALSE)) fails
* the same way for about half of the seeds (ergm 4.12.0: seeds 1, 3, 6, 7, 10-14, 16 of 1-17). Raising gwcutoff() does not help (the count grows
* with it). This is not a bug of the sampler; the message must say what happened and what to do. Before the fix the log held only R's one-line message.
nwwebuse mesa, nwclear
encode race, generate(racen)
tempfile lg
quietly log using `"`lg'"', text replace name(cutlog)
capture noisily nwergm mesa, edges nodematch(grade racen) gwespfree(.25) seed(3)
local rc = _rc
quietly log close cutlog
if `rc' != 498 {
	di as err "FAIL cutoff hint: expected r(498), got r(`rc')"
	exit 9
}
tempname fh
file open `fh' using `"`lg'"', read text
local all ""
file read `fh' line
while r(eof) == 0 {
	local all `"`all' `line'"'
	file read `fh' line
}
file close `fh'
foreach s in "exceeded the cutoff of 30" "degenerate" "Raising gwcutoff() only postpones" "another seed()" {
	if strpos(`"`all'"', "`s'") == 0 {
		di as err `"FAIL cutoff hint: output lacks "`s'""'
		exit 9
	}
}
di "PASS cutoff hint: the r(498) of a curved fit says what happened and what to do"

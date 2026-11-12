cscript

* Long messages wrap at word boundaries (1.5.10). Stata cuts a display line that is longer than the linesize at exactly that
* column, in the middle of a word ("... the dashed l" / "> ine is ..."); the messages are now SMCL paragraphs. The test sets
* linesize 80 (as in the book), triggers an error and the notes of estat gof, plot and estat mcmcdiag, plot, and checks the log text.

local nwcore : env NWCORE
if `"`nwcore'"' == "" {
	di as error "set the environment variable NWCORE to the directory of the nwcommands (core) package"
	exit 198
}
adopath ++ `"`nwcore'"'
adopath ++ `"`c(pwd)'"'
quietly do `"`nwcore'/unw_core.do"'
do unw_ergm.do

* _mw_check logfile "message": the message must appear in the log, joined from its output lines (trimmed, joined with one
* space) exactly as written, on at least two lines, none longer than the linesize and none a hard-wrap continuation ("> ").
capture program drop _mw_check
program _mw_check
	args logf msg
	local start = substr(`"`macval(msg)'"', 1, 30)
	tempname fh
	local found 0
	local nl 0
	local hard 0
	local toolong 0
	local joined ""
	file open `fh' using `"`logf'"', read text
	file read `fh' line
	while r(eof) == 0 {
		if `found' == 1 & strlen(`"`macval(joined)'"') < strlen(`"`macval(msg)'"') {
			if substr(`"`macval(line)'"', 1, 2) == "> " local hard 1
			if strlen(`"`macval(line)'"') > 80 local toolong 1
			local t = trim(`"`macval(line)'"')
			local joined `"`macval(joined)' `macval(t)'"'
			local ++nl
		}
		if `found' == 0 & strpos(trim(`"`macval(line)'"'), `"`macval(start)'"') == 1 {
			local found 1
			if strlen(`"`macval(line)'"') > 80 local toolong 1
			local joined = trim(`"`macval(line)'"')
			local nl 1
		}
		file read `fh' line
	}
	file close `fh'
	di as text "  lines: `nl'  hard wrap: `hard'  too long: `toolong'"
	assert `found' == 1
	assert `nl' >= 2
	assert `hard' == 0
	assert `toolong' == 0
	assert `"`macval(joined)'"' == `"`macval(msg)'"'
	di as text "  PASS: wraps at word boundaries: " substr(`"`macval(msg)'"', 1, 50) "..."
end

set linesize 80
set graphics off
tempfile l1 l2 l3

nwclear
nwset, mat((0,1,1,0,0\1,0,0,0,0\0,0,0,1,0\0,0,0,0,1\1,0,0,0,0)) directed name(toynet)

* 1. error
log using `l1', text replace name(mw1)
capture noisily nwergm toynet, edges gwesp(0.5) gwespfree(1)
local rc = _rc
log close mw1
assert `rc' == 198
_mw_check `l1' "options gwesp() and gwespfree() cannot both be specified - a gwesp term is either fixed-decay or curved (free-decay), not both."

* 2. estat gof, plot and estat mcmcdiag, plot
qui nwergm toynet, edges mutual method(mcmle) seed(777)
log using `l2', text replace name(mw2)
estat gof, seed(777) nsim(10) plot
log close mw2
_mw_check `l2' "(plot saved as gof; box and whiskers summarize the simulated draws, the red line with circles is the observed network)"
log using `l3', text replace name(mw3)
estat mcmcdiag, plot
log close mw3
_mw_check `l3' "(plot saved as mcmcdiag; each row is one model statistic's MCMC trace and density from the final simulation)"
capture graph drop gof
capture graph drop mcmcdiag

di as result "ALL TESTS PASSED"

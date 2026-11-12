cscript

* Messages of estat gof (plot note), estat ic (reason for a missing log-likelihood), estat mcmcdiag (pvalue()),
* the note after a curved MPLE fit, and expstat() with log0() (refused, as R's Exp() has no log0 argument).
* Run from the repository root with NWCORE set (cscripts/run_tests.sh does this); the runner sets an empty PLUS.
capture program drop nwinstall
local nwcore : env NWCORE
if `"`nwcore'"' == "" {
	di as error "set the environment variable NWCORE to the directory of the nwcommands (core) package"
	exit 198
}
adopath ++ `"`nwcore'"'
adopath ++ `"`nwcore'/lib"'
adopath ++ `"`c(pwd)'"'
adopath ++ `"`c(pwd)'/lib"'
capture adopath ++ "lib/plugins/macos"
capture adopath ++ "lib/plugins/unix"
capture adopath ++ "lib/plugins/windows"
quietly do `"`nwcore'/unw_core.do"'
do unw_ergm.do
set graphics off

* has the log file `1' the text `2'?
capture program drop _fx_has
program _fx_has, rclass
	args file text
	mata: st_numscalar("r(has)", strpos(invtokens(cat(st_local("file"))', " "), st_local("text")) > 0)
	return scalar has = r(has)
end

nwclear
clear
mata: rseed(7); n = 40; R = runiform(n,n) :< 0.10; R = R :* (1 :- I(n)); R = ((R + R') :> 0); st_matrix("A", R)
nwset, mat(A) undirected name(un) nooutput

* --- estat ic after an MCMLE fit with nologlik names the option
qui nwergm un, edges gwesp(.5) seed(1) nologlik
assert missing(e(ll))
tempfile lg1
log using `"`lg1'"', text replace name(fx1)
capture noisily estat ic
local rc = _rc
log close fx1
assert `rc' == 498
_fx_has `"`lg1'"' "fitted with the option"
assert r(has) == 1
_fx_has `"`lg1'"' "curved"
assert r(has) == 0
di "PASS estat ic nologlik"

* --- estat mcmcdiag, pvalue(): message without internal file names
tempfile lg2
log using `"`lg2'"', text replace name(fx2)
capture noisily estat mcmcdiag, pvalue(0.2)
local rc = _rc
log close fx2
assert `rc' == 198
_fx_has `"`lg2'"' "unw_ergm"
assert r(has) == 0
_fx_has `"`lg2'"' "Cramer-von Mises"
assert r(has) == 1
di "PASS estat mcmcdiag pvalue"

* --- estat gof, plot: the note describes the observed network as drawn
tempfile lg3
log using `"`lg3'"', text replace name(fx3)
estat gof, seed(777) nsim(10) plot
log close fx3
_fx_has `"`lg3'"' "red line with circles is the observed network"
assert r(has) == 1
_fx_has `"`lg3'"' "dashed"
assert r(has) == 0
di "PASS estat gof plot note"

* --- curved MCMLE fit: estat ic names the curved term, not nologlik
qui nwergm un, edges gwespfree(.5) seed(1)
assert e(curved) == 1
assert "`e(method)'" == "mcmle"
assert missing(e(ll))
tempfile lg4
log using `"`lg4'"', text replace name(fx4)
capture noisily estat ic
local rc = _rc
log close fx4
assert `rc' == 498
_fx_has `"`lg4'"' "curved (estimated decay) term fitted by MCMLE"
assert r(has) == 1
_fx_has `"`lg4'"' "nologlik"
assert r(has) == 0
di "PASS estat ic curved"

* --- curved MPLE fit: the note points to the gw_effects section, estat ic works
tempfile lg5
log using `"`lg5'"', text replace name(fx5)
nwergm un, edges gwespfree(.5) method(mple)
log close fx5
_fx_has `"`lg5'"' "The decay of the curved term is estimated"
assert r(has) == 1
_fx_has `"`lg5'"' "BFGS"
assert r(has) == 0
estat ic
assert _rc == 0
di "PASS MPLE curved note"

* --- expstat() refuses log0(); logstat() takes it; expstat() alone works
capture noisily nwergm un, edges kstar(2) method(mple) expstat(kstar_2, log0(-5))
assert _rc == 198
qui nwergm un, edges kstar(2) method(mple) expstat(kstar_2)
assert _rc == 0
local cn : colnames e(b)
assert strpos("`cn'", "exp_kstar_2") > 0
qui nwergm un, edges kstar(2) method(mple) logstat(kstar_2, log0(-5))
assert _rc == 0
local cn : colnames e(b)
assert strpos("`cn'", "log_kstar_2") > 0
di "PASS expstat log0"

di "ALL PASS"

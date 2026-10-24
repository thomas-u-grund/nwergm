cscript

capture adopath ++ "."
capture adopath ++ "lib"
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
capture adopath ++ "lib/plugins/macos"
capture adopath ++ "lib/plugins/unix"
capture adopath ++ "lib/plugins/windows"

* Certifies gwodegreefree() and gwidegreefree() against R ergm 4.12.0 (gwodegree, gwidegree with fixed = FALSE); dev/gen_test_curveddeg.R

matrix __A = J(30, 30, 0)
local el `"4 1 7 1 8 1 9 1 18 1 26 1 1 2 22 2 26 2 15 4 1 5 3 5 4 5 8 5 9 5 16 5 19 5 20 5 27 5 30 5 1 6 4 6 21 6 22 6 28 6 30 6 3 7 4 7 8 7 9 7 10 7 26 7 18 8 20 8 1 9 8 9 3 10 4 10 5 10 9 10 16 10 18 10 24 10 29 10 4 11 19 11 27 11 1 12 4 12 8 12 16 12 18 12 30 12 4 14 13 14 10 15 28 15 4 16 8 16 13 16 13 17 20 17 1 18 12 18 9 19 10 19 12 19 16 19 18 19 25 19 29 19 6 20 8 20 10 20 4 21 6 21 9 21 12 21 19 21 20 21 28 21 1 22 3 22 4 22 6 22 9 22 12 22 18 22 3 23 15 23 18 23 29 23 1 24 3 24 13 24 14 24 15 24 21 24 26 24 9 25 16 25 1 26 4 26 6 27 13 27 4 28 16 28 21 28 23 28 26 28 3 29 8 29 13 29 16 29 18 29 22 29 12 30 13 30 14 30 15 30 18 30 24 30 28 30 29 30"'
local k : word count `el'
forvalues t = 1(2)`k' {
	local i : word `t' of `el'
	local j : word `=`t'+1' of `el'
	matrix __A[`i', `j'] = 1
}
nwset, mat(__A) directed name(dd) nooutput

qui nwergm dd, edges gwodegreefree(0.5) method(mple)
matrix bb = e(b)
matrix VV = e(V)
local __cf "-0.507896764941286 -2.49204946963073 1.85233970361657"
local __sf "0.738884232312822 0.630550691268971 0.600802641390269"
forvalues j = 1/3 {
	local e : word `j' of `__cf'
	local s : word `j' of `__sf'
	if !(abs(el(bb,1,`j') - (`e')) < 1e-3 * max(1, abs(`e'))) {
		di as err "FAIL curved degree term: difference to R too large"
		exit 9
	}
	if !(abs(sqrt(el(VV,`j',`j')) - (`s')) < 1e-3 * max(1, `s')) {
		di as err "FAIL curved degree term: difference to R too large"
		exit 9
	}
}
di "PASS gwodegreefree: MPLE equal to R"
foreach sd in 101 202 {
	set seed `sd'
	qui nwergm dd, edges gwodegreefree(0.5) method(mcmle) mcmcsamplesize(2000) mcmcinterval(200) mcmcburnin(5000) mcmleiterations(25) nologlik
	matrix bb = e(b)
	local __cf "-0.484622465329218 -2.50469897384404 1.87383021768504"
	local __sf "0.929356641171593 0.71370919462354 0.755525480819689"
	forvalues j = 1/3 {
		local e : word `j' of `__cf'
		local s : word `j' of `__sf'
		if !(abs(el(bb,1,`j') - (`e')) < 3.5 * `s') {
			di as err "FAIL curved degree term: difference to R too large"
			exit 9
		}
	}
}
di "PASS gwodegreefree: MCMLE within Monte Carlo noise of R for two seeds"
qui nwergm dd, edges gwidegreefree(0.5) method(mple)
matrix bb = e(b)
matrix VV = e(V)
local __cf "-0.991859555377135 -0.127354950288824 1.45685095626314e-13"
local __sf "0.081386112684414 0.312989472128019 2.68327995288175"
forvalues j = 1/3 {
	local e : word `j' of `__cf'
	local s : word `j' of `__sf'
	if !(abs(el(bb,1,`j') - (`e')) < 1e-3 * max(1, abs(`e'))) {
		di as err "FAIL curved degree term: difference to R too large"
		exit 9
	}
	if !(abs(sqrt(el(VV,`j',`j')) - (`s')) < 1e-3 * max(1, `s')) {
		di as err "FAIL curved degree term: difference to R too large"
		exit 9
	}
}
di "PASS gwidegreefree: MPLE equal to R"
di "test_nwergm_curveddeg: ALL OK"

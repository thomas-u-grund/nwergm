cscript

* Certifies offset() in models with a curved (free-decay) term against R ergm 4.12.0 (reference: dev/offset_curved_ref.R,
* which writes dev/offset_curved_r.csv; the Stata side is dev/offset_curved_run.do):
*  (1) the pseudolikelihood fits equal ergm(..., offset.coef=, estimate="MPLE") (coefficients, standard errors, log-pseudolikelihood),
*      native plugin and Mata alike, on the Florentine marriages and the Lazega friendship network (directed, gwesp OTP);
*  (2) Monte Carlo fits are within Monte Carlo noise of the mean of three R seeds (0.5 standard errors), the offsets exactly at their values
*      with zero rows and columns in e(V);
*  (3) error paths (r(198)) and init() replacing an offset value.

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

capture program drop oc_check
program oc_check
	// oc_check label "R coefficients" "R standard errors" R_ll tol : compares e(b), sqrt(diag(e(V))) and e(ll) (tol relative to max(1,|x|))
	args label rb rse rll tol
	local k = colsof(e(b))
	assert `k' == `: word count `rb''
	forvalues j = 1/`k' {
		local b : word `j' of `rb'
		local s : word `j' of `rse'
		assert reldif(el(e(b), 1, `j'), `b') < `tol' | abs(el(e(b), 1, `j') - `b') < 1e-8
		assert abs(sqrt(el(e(V), `j', `j')) - `s') < `tol' * max(1, `s')
	}
	if "`rll'" != "" assert reldif(e(ll), `rll') < `tol'
	di "PASS `label'"
end
capture program drop oc_mc
program oc_mc
	// oc_mc label "R mean coefficients" "R mean standard errors" "offset positions" "offset values"
	args label rb rse fpos fval
	local k = colsof(e(b))
	forvalues j = 1/`k' {
		local b : word `j' of `rb'
		local s : word `j' of `rse'
		if `s' > 0 assert abs(el(e(b), 1, `j') - `b') < 0.5 * `s'
	}
	local m : word count `fpos'
	forvalues t = 1/`m' {
		local j : word `t' of `fpos'
		local v : word `t' of `fval'
		assert el(e(b), 1, `j') == `v'
		forvalues i = 1/`k' {
			assert el(e(V), `j', `i') == 0 & el(e(V), `i', `j') == 0
		}
	}
	di "PASS `label'"
end

nwwebuse florentine, nwclear
quietly nwergm flomarriage, edges gwespfree(0.5) offset(gwesp_weight 0.5 gwesp_decay 0.3) estimate(mple)
oc_check "fA MPLE" "-2.25727833688891 0.5 0.3" "0.255541263124699 0 0" -56.5194434788368 1e-6
quietly nwergm flomarriage, edges gwespfree(0.5) offset(gwesp_weight 0.5 gwesp_decay 0.3) estimate(mple) nonative
oc_check "fA MPLE (Mata)" "-2.25727833688891 0.5 0.3" "0.255541263124699 0 0" -56.5194434788368 1e-6
assert e(df_m) == 1
quietly nwergm flomarriage, edges gwespfree(0.5) offset(gwesp_decay 0.3) estimate(mple)
oc_check "fB MPLE" "-1.72678126200361 0.111463650991626 0.3" "0.312028972591089 0.171489617995958 0" -53.8609613513535 1e-6
quietly nwergm flomarriage, edges gwespfree(0.5) offset(gwesp_decay 0.3) estimate(mple) nonative
oc_check "fB MPLE (Mata)" "-1.72678126200361 0.111463650991626 0.3" "0.312028972591089 0.171489617995958 0" -53.8609613513535 1e-6
assert e(df_m) == 2
quietly nwergm flomarriage, edges gwespfree(0.5) offset(gwesp_weight 0.5) estimate(mple)
oc_check "fC MPLE" "-8.98137249659649e-08 0.5 2.8689162412353e-11" "0.20560608725801 0 0.647571108957065" -108.383085426248 1e-6
quietly nwergm flomarriage, edges gwespfree(0.5) offset(gwesp_weight 0.5) estimate(mple) nonative
oc_check "fC MPLE (Mata)" "-8.98137249659649e-08 0.5 2.8689162412353e-11" "0.20560608725801 0 0.647571108957065" -108.383085426248 1e-6
assert e(df_m) == 2
quietly nwergm flomarriage, edges gwespfree(0.5) offset(edges -2) estimate(mple)
oc_check "fD MPLE" "-2 0.249999880763427 1.90408829729856e-10" "0 0.16300552099863 1.67697165088914" -54.2114774940417 1e-6
quietly nwergm flomarriage, edges gwespfree(0.5) offset(edges -2) estimate(mple) nonative
oc_check "fD MPLE (Mata)" "-2 0.249999880763427 1.90408829729856e-10" "0 0.16300552099863 1.67697165088914" -54.2114774940417 1e-6
assert e(df_m) == 2
quietly nwergm flomarriage, edges gwesp(0.5) offset(gwesp_0.5 0.5) estimate(mple)
oc_check "fE MPLE" "-2.28405112420779 0.5" "0.256202300680827 0" -56.7987990158585 1e-6
nwwebuse lazega, nwclear
quietly nwergm lazega_fr, edges mutual gwespfree(0.5) offset(gwesp_decay 0.5) estimate(mple)
oc_check "lB MPLE" "-2.99858826765081 0.961696352123581 0.458637052047711 0.5" "0.0894564100820491 0.111911801278743 0.0381377491361213 0" -1655.92346122916 1e-6
quietly nwergm lazega_fr, edges mutual gwespfree(0.5) offset(gwesp_decay 0.5) estimate(mple) nonative
oc_check "lB MPLE (Mata)" "-2.99858826765081 0.961696352123581 0.458637052047711 0.5" "0.0894564100820491 0.111911801278743 0.0381377491361213 0" -1655.92346122916 1e-6
assert e(df_m) == 3
quietly nwergm lazega_fr, edges mutual gwespfree(0.5) offset(gwesp_weight 0.8 gwesp_decay 0.5) estimate(mple)
oc_check "lA MPLE" "-3.70441626027604 0.866836914877114 0.8 0.5" "0.0535326871299741 0.116639197432574 0 0" -1694.18990861575 1e-6
quietly nwergm lazega_fr, edges mutual gwespfree(0.5) offset(gwesp_weight 0.8 gwesp_decay 0.5) estimate(mple) nonative
oc_check "lA MPLE (Mata)" "-3.70441626027604 0.866836914877114 0.8 0.5" "0.0535326871299741 0.116639197432574 0 0" -1694.18990861575 1e-6
assert e(df_m) == 2
quietly nwergm lazega_fr, edges mutual gwespfree(0.5) offset(mutual 2) estimate(mple)
oc_check "lD MPLE" "-2.10755093354327 2 -0.0821276676314666 2.43021734713117e-12" "0.0702199189014671 0 0.0490361775478368 0.515163601323375" -1790.96011733007 1e-6
quietly nwergm lazega_fr, edges mutual gwespfree(0.5) offset(mutual 2) estimate(mple) nonative
oc_check "lD MPLE (Mata)" "-2.10755093354327 2 -0.0821276676314666 2.43021734713117e-12" "0.0702199189014671 0 0.0490361775478368 0.515163601323375" -1790.96011733007 1e-6
assert e(df_m) == 3
quietly nwergm lazega_fr, edges mutual gwespfree(0.5) offset(mutual 2 gwesp_weight 0.8) estimate(mple)
oc_check "lC MPLE" "-2.06547620296578e-08 2 0.8 2.06547373396663e-12" "0.0426810323103919 0 0 0.0420904665630318" -6179.58355110208 1e-6
quietly nwergm lazega_fr, edges mutual gwespfree(0.5) offset(mutual 2 gwesp_weight 0.8) estimate(mple) nonative
oc_check "lC MPLE (Mata)" "-2.06547620296578e-08 2 0.8 2.06547373396663e-12" "0.0426810323103919 0 0 0.0420904665630318" -6179.58355110208 1e-6
assert e(df_m) == 2
nwwebuse florentine, nwclear
quietly nwergm flomarriage, edges gwespfree(0.5) offset(gwesp_weight 0.5 gwesp_decay 0.3) seed(1)
assert e(converged) == 1
oc_mc "fA MCMLE" "-2.1746824 0.5 0.3" "0.17852325 0 0" "2 3" "0.5 0.3"
nwwebuse florentine, nwclear
quietly nwergm flomarriage, edges gwespfree(0.5) offset(gwesp_decay 0.3) seed(1)
assert e(converged) == 1
oc_mc "fB MCMLE" "-1.7167303 0.104998 0.3" "0.35433062 0.27443135 0" "3" "0.3"
nwwebuse lazega, nwclear
quietly nwergm lazega_fr, edges mutual gwespfree(0.5) offset(gwesp_decay 0.5) seed(1)
assert e(converged) == 1
oc_mc "lB MCMLE" "-3.1862297 0.92419375 0.55136922 0.5" "0.11012422 0.16150061 0.062154321 0" "4" "0.5"
nwwebuse lazega, nwclear
quietly nwergm lazega_fr, edges mutual gwespfree(0.5) offset(gwesp_weight 0.8 gwesp_decay 0.5) seed(1)
assert e(converged) == 1
oc_mc "lA MCMLE" "-3.5868516 0.71578589 0.8 0.5" "0.02821782 0.15072335 0 0" "3 4" "0.8 0.5"

* errors (r(198)) and init()
nwwebuse florentine, nwclear
capture nwergm flomarriage, edges gwespfree(0.5) estimate(mple) offset(gwesp_decay -0.3)
assert _rc == 198
capture nwergm flomarriage, edges gwespfree(0.5) estimate(mple) offset(gwesp 0.5)
assert _rc == 198
capture nwergm flomarriage, edges gwespfree(0.5) estimate(mple) offset(gwesp_decay 0.3 gwesp_decay 0.4)
assert _rc == 198
capture nwergm flomarriage, edges gwespfree(0.5) estimate(mple) offset(edges -2 gwesp_weight 0.5 gwesp_decay 0.3)
assert _rc == 198
capture nwergm flomarriage, edges gwespfree(0.5) estimate(mple) offset(gwesp_decay)
assert _rc == 198
capture nwergm flomarriage, edges gwespfree(0.5) estimate(mple) offset(gwesp_decay abc)
assert _rc == 198
di "PASS error paths"
quietly nwergm flomarriage, edges gwespfree(0.5) estimate(mple) offset(gwesp_decay 0.4)
matrix b1 = e(b)
quietly nwergm flomarriage, edges gwespfree(0.5) estimate(mple) offset(gwesp_decay 0.3) init(. . 0.4)
assert el(e(b), 1, 3) == 0.4
assert mreldif(e(b), b1) < 1e-6
* a zero decay is allowed
quietly nwergm flomarriage, edges gwespfree(0.5) estimate(mple) offset(gwesp_decay 0)
assert el(e(b), 1, 3) == 0
di "PASS init() and zero decay"

di "test_nwergm_offsetcurved: ALL OK"

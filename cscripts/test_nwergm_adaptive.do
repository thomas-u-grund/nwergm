cscript

* R-style adaptive MCMC sample size in MCMLE (nwergm 1.3.0): the defaults, the fixed-size switch, the helper functions, the
* tie-list hand-over between native runs, the frame protocol of the plugin, and agreement with R's ergm on a model with a
* shared-partner term. Tolerances for the R comparison are in units of the standard error that R reports.
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

nwclear
clear
mata: rseed(7); n = 40; R = runiform(n,n) :< 0.10; R = R :* (1 :- I(n)); R = ((R + R') :> 0); st_matrix("A", R)
nwset, mat(A) undirected name(un) nooutput

* A: the default is adaptive: base size max(256, 32 p), target ESS 64; mcmleeffectivesize(0) is the fixed-size fit (3000 draws)
qui nwergm un, edges gwesp(.5) seed(1) nologlik
assert e(mcmc_samplesize) >= 200
assert e(mcmc_samplesize) != 3000
assert e(converged) == 1
qui nwergm un, edges gwesp(.5) seed(1) nologlik mcmleeffectivesize(0)
assert e(mcmc_samplesize) == 3000
di "PASS default is adaptive, mcmleeffectivesize(0) restores fixed-size samples"

* B: a given sample size is the base size and the fit is still adaptive; the same seed gives the same fit
qui nwergm un, edges gwesp(.5) seed(3) nologlik mcmcsamplesize(400)
matrix b1 = e(b)
assert e(mcmc_samplesize) >= 300
qui nwergm un, edges gwesp(.5) seed(3) nologlik mcmcsamplesize(400)
assert mreldif(e(b), b1) < 1e-12
di "PASS a given sample size is the base size; fits are reproducible under the seed"

* C: the helper functions
mata:
t_ok = 1
// burn-in finder: a clearly trending start is detected, a stationary sample gets about 5%
rseed(5)
x = rnormal(2000, 2, 0, 1)
b0 = ergm_find_burnin(x)
if (b0[1] > 0.2*2000) t_ok = 0
y = x
for (i=1; i<=300; i++) y[i, .] = y[i, .] :+ 8*exp(-i/60)
b1 = ergm_find_burnin(y)
if (b1[1] < 100) t_ok = 0
// inflation: independent draws about 1, an AR(1) chain with phi = 0.8 about (1+phi)/(1-phi) = 9
if (ergm_geomean_infl(x) > 1.5) t_ok = 0
z = x
for (i=2; i<=2000; i++) z[i, .] = 0.8*z[i-1, .] + x[i, .]
infl = ergm_geomean_infl(z)
if (infl < 5 | infl > 14) t_ok = 0
// compression of an MPLE design: same likelihood on the distinct rows
D = (runiform(30000, 1) :< 0.5), (runiform(30000, 1) :< 0.3), (runiform(30000, 1) :< 0.1)
D = D[., (1, 2)], D[., 3]
U = ergm_mple_compress(D)
if (rows(U) != 8) t_ok = 0
r1 = ergm_mple_irls(D, "bb1", "VV1")
r2 = ergm_mple_irls_c(U, "bb2", "VV2")
if (r1 != 1 | r2 != 1) t_ok = 0
if (mreldif(st_matrix("bb1"), st_matrix("bb2")) > 1e-9 | mreldif(st_matrix("VV1"), st_matrix("VV2")) > 1e-9) t_ok = 0
if (ergm_mple_exists(D) != ergm_mple_exists_c(U)) t_ok = 0
st_numscalar("t_ok", t_ok)
end
assert scalar(t_ok) == 1
di "PASS burn-in finder, inflation, compressed design"

* D: lazy tie-list hand-over equals the graph-based run (same seed, same draws), and G is rebuilt afterwards
qui nwergm un, edges gwesp(.5) method(mple)
matrix b0 = e(b)
mata: th = st_matrix("b0")
mata: ties0 = __nwergm_last_G.all_ties()
mata: cur0 = __nwergm_last_M.full_statistic(__nwergm_last_G)
set seed 99
mata: s1 = ErgmNativeSampleCore(__nwergm_last_M, __nwergm_last_G, th, 500, 40, 300, cur0)
mata: ties1 = __nwergm_last_G.all_ties()
mata: ergm_graph_load_ties(__nwergm_last_G, ties0)
set seed 99
mata: ties2 = ties0; tiesout = J(0, 2, 0)
mata: s2 = ErgmNativeSampleCore(__nwergm_last_M, __nwergm_last_G, th, 500, 40, 300, cur0, ties2, tiesout)
mata: assert(s1 == s2)
mata: assert(rows(tiesout) == rows(ties1))
mata: ergm_graph_load_ties(__nwergm_last_G, tiesout)
mata: assert(__nwergm_last_G.nties == rows(tiesout))
mata: assert(mreldif(__nwergm_last_M.full_statistic(__nwergm_last_G), s2[rows(s2), .]) < 1e-9)
di "PASS lazy tie-list runs equal the graph-based run"

* E: the frame protocol: a sample that grows far beyond the starting network is returned complete (second call with a larger frame)
qui nwergm un, edges method(mple)
mata: th = (3)
mata: cur0 = __nwergm_last_M.full_statistic(__nwergm_last_G)
mata: t0 = __nwergm_last_G.nties
mata: s = ErgmNativeSampleCore(__nwergm_last_M, __nwergm_last_G, th, 200000, 10, 20, cur0)
mata: assert(__nwergm_last_G.nties > 2*t0 + 64)
mata: assert(__nwergm_last_G.nties == s[rows(s), 1])
* a plugin of generation 2 or later publishes its generation; an older plugin does not (and is then given a frame of one row per dyad)
capture confirm scalar __ergm_native_gen
if _rc == 0 assert scalar(__ergm_native_gen) >= 2
di "PASS the final network is returned complete when it outgrows the frame"

* F: agreement with R's ergm 4.12.0 (Florentine marriages, edges + nodematch(seat) + gwesp(0.5, fixed = TRUE); ergm over 10 seeds:
*    edges -1.961, nodematch 0.485, gwesp 0.096, standard errors 0.466, 0.498, 0.277)
nwwebuse florentine, nwclear
local sb1 0
local sb2 0
local sb3 0
forvalues s = 1/10 {
	qui nwergm flomarriage, edges nodematch(seat) gwesp(.5) seed(`s') nologlik
	local sb1 = `sb1' + _b[edges]
	local sb2 = `sb2' + _b[nodematch_seat]
	local sb3 = `sb3' + _b[gwesp_.5]
	assert e(converged) == 1
}
assert abs(`sb1'/10 + 1.961) < 0.3 * 0.466
assert abs(`sb2'/10 - 0.485) < 0.3 * 0.498
assert abs(`sb3'/10 - 0.096) < 0.3 * 0.277
di "PASS Florentine fit agrees with R within 0.3 standard errors"
di "PASS test_nwergm_adaptive"

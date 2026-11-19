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

* Certifies the width of the curved block of the free-decay terms (gwespfree, gwdspfree, gwnspfree, undirected and directed OTP, and the two-mode
* bgwdspfree1/2): a Monte Carlo fit (and the Bayesian estimator) must count every number of shared partners a simulated network can have, not only
* those of the observed network. The references are EXACT: on a small network every graph is enumerated (R's ergm.allstats on ergm 4.12.0, statistics
* edges + esp/dsp/nsp(1:k) with the curved weights exp(a) (1 - (1 - exp(-a))^j) of decay a = 0.5) and the likelihood is maximised, or the posterior
* with N(0,10^2) priors on edges, weight and decay is integrated on a grid. The decay is held at 0.5 with offset() so that the Monte Carlo maximum
* likelihood has a unique answer.
*   7 nodes, undirected, 21 possible ties : esp, dsp, nsp (k = 5)
*   5 nodes, directed (OTP), 20 possible arcs: esp, dsp, nsp (k = 3)
*   3 + 5 nodes, two-mode, 15 possible ties : b1dsp (k = 5), b2dsp (k = 3)

capture program drop cw_chk
program cw_chk
	// cw_chk label edges_exact weight_exact tol
	args label be bw tol
	local d1 = abs(el(e(b), 1, 1) - `be')
	local d2 = abs(el(e(b), 1, 2) - `bw')
	if `d1' > `tol' | `d2' > `tol' {
		di as err "FAIL `label': edges " el(e(b), 1, 1) " (exact `be'), weight " el(e(b), 1, 2) " (exact `bw')"
		exit 9
	}
	di "PASS `label' (edges " %7.4f el(e(b), 1, 1) " vs `be', weight " %7.4f el(e(b), 1, 2) " vs `bw')"
end

* ---- undirected, 7 nodes
quietly import delimited using "cscripts/curvedwidth_und7.csv", clear varnames(nonames)
mkmat v*, matrix(A)
clear
nwset, mat(A) name(und7) undirected nooutput
local k 0
foreach t in esp dsp {
	local ++k
	local be : word `k' of -0.98281 -0.66485
	local bw : word `k' of 0.37738 0.14147
	quietly nwergm und7, edges gw`t'free(0.5) offset(gw`t'_decay 0.5) seed(1) mcmcsamplesize(20000) mcmleiterations(40)
	cw_chk "MCMLE undirected gw`t'free vs exact MLE" `be' `bw' 0.04
}

* gwnspfree on another 7-node graph (the first one has an extreme pseudolikelihood start for nsp)
quietly import delimited using "cscripts/curvedwidth_nsp7.csv", clear varnames(nonames)
mkmat v*, matrix(A)
clear
nwset, mat(A) name(nsp7) undirected nooutput
quietly nwergm nsp7, edges gwnspfree(0.5) offset(gwnsp_decay 0.5) seed(1) mcmcsamplesize(20000) mcmleiterations(40)
cw_chk "MCMLE undirected gwnspfree vs exact MLE" 0.63312 1.06583 0.02

* ---- Bayesian posterior means, edges gwespfree, decay estimated (exact: -1.0919, 0.5363, 0.4650)
foreach s in 1 2 {
	quietly nwergm und7, edges gwespfree(0.5) method(bayes) seed(`s') burnin(100) iterations(100000) nodraws
	assert abs(el(e(b), 1, 1) - (-1.0919)) < 0.09
	assert abs(el(e(b), 1, 2) - 0.5363) < 0.07
	assert abs(el(e(b), 1, 3) - 0.4650) < 0.04
	di "PASS Bayes gwespfree seed `s' posterior means " %7.4f el(e(b), 1, 1) " " %7.4f el(e(b), 1, 2) " " %7.4f el(e(b), 1, 3) " (exact -1.0919 0.5363 0.4650)"
}

* ---- directed OTP, 5 nodes
quietly import delimited using "cscripts/curvedwidth_dir5.csv", clear varnames(nonames)
mkmat v*, matrix(D)
clear
nwset, mat(D) name(dir5) directed nooutput
local k 0
foreach t in esp dsp nsp {
	local ++k
	local be : word `k' of 1.65796 1.90857 0.19906
	local bw : word `k' of -0.72869 -0.76127 0.00675
	quietly nwergm dir5, edges gw`t'free(0.5) type(OTP) offset(gw`t'_decay 0.5) seed(1) mcmcsamplesize(20000) mcmleiterations(40)
	cw_chk "MCMLE directed gw`t'free(OTP) vs exact MLE" `be' `bw' 0.05
}

* ---- two-mode, 3 + 5 nodes
matrix A = J(5,3,0)
foreach p in "1 1" "2 1" "3 1" "2 2" "3 2" "4 2" "3 3" "5 3" {
	local j : word 1 of `p'
	local i : word 2 of `p'
	matrix A[`j', `i'] = 1
}
nwset, mat(A) bipartite name(bn) nooutput
clear
set obs 8
quietly nwergm bn, edges bgwdspfree1(0.5) offset(gwb1dsp_decay 0.5) seed(1) mcmcsamplesize(20000) mcmleiterations(40)
cw_chk "MCMLE two-mode bgwdspfree1 vs exact MLE" -0.29385 0.94864 0.03
quietly nwergm bn, edges bgwdspfree2(0.5) offset(gwb2dsp_decay 0.5) seed(1) mcmcsamplesize(20000) mcmleiterations(40)
cw_chk "MCMLE two-mode bgwdspfree2 vs exact MLE" 1.10700 -0.66750 0.04

* ---- the curved fit with a held decay equals the fixed-decay fit (same statistic), Faux Mesa High (205 nodes), seed by seed
nwwebuse mesa, nwclear
quietly nwergm mesa, edges gwesp(0.25) seed(3)
local bf = el(e(b), 1, 2)
quietly nwergm mesa, edges gwespfree(0.25) offset(gwesp_decay 0.25) seed(3)
assert abs(el(e(b), 1, 2) - `bf') < 1e-6
di "PASS Mesa curved fit with a held decay equals gwesp(0.25) (" %8.5f `bf' ")"

* ---- the pseudolikelihood is unchanged: the narrow block gives the same fit as the full block
nwwebuse florentine, nwclear
quietly nwergm flomarriage, edges gwespfree(0.5) method(mple)
assert abs(el(e(b), 1, 1) - (-1.73098)) < 1e-4 & abs(el(e(b), 1, 2) - 0.12349) < 1e-4
di "PASS MPLE gwespfree Florentine unchanged"

* ---- gwcutoff(): the number of counts of the block is min(gwcutoff, nodes - 2) (R: cutoff = 30); a count above it stops the fit (r(498)), as in R
* a cutoff that cannot bind (at least nodes - 2) gives the default fit: 7 nodes, default 30
quietly import delimited using "cscripts/curvedwidth_und7.csv", clear varnames(nonames)
mkmat v*, matrix(A)
clear
nwset, mat(A) name(und7) undirected nooutput
quietly nwergm und7, edges gwespfree(0.5) offset(gwesp_decay 0.5) seed(1) mcmcsamplesize(5000) mcmleiterations(20)
matrix b0 = e(b)
quietly nwergm und7, edges gwespfree(0.5) offset(gwesp_decay 0.5) seed(1) mcmcsamplesize(5000) mcmleiterations(20) gwcutoff(5)
assert mreldif(e(b), b0) < 1e-10
quietly nwergm und7, edges gwespfree(0.5) offset(gwesp_decay 0.5) seed(1) mcmcsamplesize(5000) mcmleiterations(20) gwcutoff(500)
assert mreldif(e(b), b0) < 1e-10
di "PASS gwcutoff(5) and gwcutoff(500) equal the default on 7 nodes"
capture nwergm und7, edges gwespfree(0.5) gwcutoff(0)
assert _rc == 198
* the observed network above the cutoff
capture nwergm und7, edges gwespfree(0.5) gwcutoff(1)
assert _rc == 498
capture nwergm und7, edges gwdspfree(0.5) gwcutoff(1)
assert _rc == 498
capture nwergm und7, edges gwdegreefree(0.5) gwcutoff(1)
assert _rc == 498
di "PASS the observed network above the cutoff: r(498)"
* a simulated network above the cutoff (Mesa: the observed maximum is 5 shared partners on an edge; the native sampler stops)
nwwebuse mesa, nwclear
capture noisily nwergm mesa, edges gwespfree(0.25) seed(3) gwcutoff(5)
assert _rc == 498
capture noisily nwergm mesa, edges gwespfree(0.5) seed(3) gwcutoff(5) method(bayes) iterations(200) burnin(20) nodraws
assert _rc == 498
di "PASS a simulated network above the cutoff stops the fit with r(498) (MCMLE and Bayes)"
* without the native sampler the cutoff cannot be enforced: refused
capture nwergm mesa, edges gwespfree(0.25) seed(3) gwcutoff(30) nonative
assert _rc == 498
* directed and two-mode
quietly import delimited using "cscripts/curvedwidth_dir5.csv", clear varnames(nonames)
mkmat v*, matrix(D)
clear
nwset, mat(D) name(dir5) directed nooutput
capture nwergm dir5, edges gwespfree(0.5) type(OTP) gwcutoff(1)
assert _rc == 498
di "PASS directed gwespfree(OTP) above the cutoff: r(498)"
* the Mesa fit with the default cutoff (30) equals the fit with every count (gwcutoff(203)): the further counts are zero
timer clear
timer on 1
quietly nwergm mesa, edges gwespfree(0.25) offset(gwesp_decay 0.25) seed(3)
timer off 1
matrix b30 = e(b)
timer on 2
quietly nwergm mesa, edges gwespfree(0.25) offset(gwesp_decay 0.25) seed(3) gwcutoff(203)
timer off 2
assert mreldif(e(b), b30) < 1e-4
timer list
di "PASS Mesa curved fit: gwcutoff(30) equals gwcutoff(203); seconds above (1: default, 2: 203)"
di "ALL TESTS PASSED"

cscript

* DRAFT, not yet run.
* xt_stats_undirected: observed sufficient statistics (e(obs_stats) after method(mple)) of every one-mode undirected term
* on small fixed networks, compared with R ergm 4.12.0 summary(). Edge cases: an isolate, a single attribute level,
* an attribute with a missing value, decay 0 / 0.5 / 1 / 10 / 30 / 40 / 100, k beyond the largest degree, a near-empty
* and a near-complete network, a valued network with values other than 1 (fitted as binary), the florentine network.
* Expected runtime: about 1-2 minutes (about 90 small pseudolikelihood fits).
* Runs from the repository root; the runner sets PLUS, the adopath and the plugin path (no adopath lines here).
* The R code that produced every reference value is quoted next to it (R 4.x, ergm 4.12.0, network 1.20.0).
capture program drop nwinstall
set graphics off
local nwcore : env NWCORE

* ---------------------------------------------------------------------------------------------------------------
* helper: fit `edges opts' by MPLE and compare e(obs_stats) with the full expected vector (edges first)
global XT_FAILS ""
capture program drop xt_stat
program xt_stat
	args id net opts expected
	capture noisily nwergm `net', edges `opts' method(mple)
	local rc = _rc
	if `rc' {
		* a pseudolikelihood that cannot be fitted is not what is tested here; retry with the glm iterate
		di as txt "NOTE `id': MPLE fit stopped with r(`rc'); retrying with mplecheck(off)"
		capture noisily nwergm `net', edges `opts' method(mple) mplecheck(off)
		local rc = _rc
	}
	if `rc' {
		di as err "FAIL `id': nwergm `net', edges `opts' stopped with r(`rc')"
		global XT_FAILS "$XT_FAILS `id'"
		exit
	}
	tempname S
	matrix `S' = e(obs_stats)
	local k : word count `expected'
	if colsof(`S') != `k' {
		di as err "FAIL `id': " colsof(`S') " statistics, expected `k'"
		matrix list `S'
		global XT_FAILS "$XT_FAILS `id'"
		exit
	}
	forvalues j = 1/`k' {
		local x : word `j' of `expected'
		if abs(`S'[1, `j'] - (`x')) > 1e-6 * max(1, abs(`x')) {
			di as err "FAIL `id': statistic `j' is " %20.12g `S'[1, `j'] ", R gives `x'"
			matrix list `S'
			global XT_FAILS "$XT_FAILS `id'"
			exit
		}
	}
	di as txt "PASS `id'"
end

* ---------------------------------------------------------------------------------------------------------------
* U: 7 nodes, ties 1-2 1-3 2-3 2-4 3-4 4-5 5-6, node 7 an isolate (two triangles 1-2-3 and 2-3-4)
* R: eu <- rbind(c(1,2),c(1,3),c(2,3),c(2,4),c(3,4),c(4,5),c(5,6)); U <- network.initialize(7, directed=FALSE)
*    U <- add.edges(U, eu[,1], eu[,2]); U %v% "g" <- c(1,1,2,2,1,3,1); U %v% "x" <- c(1.5,2,0,4,3.5,1,2); U %v% "one" <- rep(1,7)
*    W <- outer(1:7,1:7,"+"); diag(W) <- 0; H: ties 1-2 1-7 6-7
nwclear
clear
mata: E = (1,2\1,3\2,3\2,4\3,4\4,5\5,6)
mata: A = J(7, 7, 0)
mata: for (k = 1; k <= rows(E); k++) A[E[k,1], E[k,2]] = 1
mata: A = A + A'
mata: st_matrix("AU", A)
mata: W = (1::7) * J(1, 7, 1) + J(7, 1, 1) * (1..7); W = W :* (1 :- I(7)); st_matrix("WU", W)
mata: H = J(7, 7, 0); H[1,2] = 1; H[1,7] = 1; H[6,7] = 1; H = H + H'; st_matrix("HU", H)
nwset, mat(AU) undirected name(U) nooutput
nwset, mat(WU) undirected name(WU) nooutput
nwset, mat(HU) undirected name(HU) nooutput
* every network is set before the node attributes are created (nwset may touch the dataset)
* NE / NK (5 nodes): near-empty (one tie 1-2) and near-complete (all but 1-2); E5 / K5: empty and complete;
* UV: the ties of U with the values 2, 0.5 and -1 (valued)
mata: B = J(5, 5, 0); B[1,2] = 1; B[2,1] = 1; st_matrix("ANE", B)
mata: B = J(5, 5, 1) - I(5); B[1,2] = 0; B[2,1] = 0; st_matrix("ANK", B)
nwset, mat(ANE) undirected name(NE) nooutput
nwset, mat(ANK) undirected name(NK) nooutput
mata: st_matrix("AE5", J(5, 5, 0))
mata: st_matrix("AK5", J(5, 5, 1) - I(5))
nwset, mat(AE5) undirected name(E5) nooutput
nwset, mat(AK5) undirected name(K5) nooutput
mata: V = 2 :* A; V[4,5] = 0.5; V[5,4] = 0.5; V[5,6] = -1; V[6,5] = -1; st_matrix("AV", V)
nwset, mat(AV) undirected name(UV) nooutput
clear
set obs 7
gen g = .
gen x = .
gen one = 1
gen gm = .
mata: st_store(., "g", (1\1\2\2\1\3\1))
mata: st_store(., "x", (1.5\2\0\4\3.5\1\2))
mata: st_store(., "gm", (1\.\2\2\1\3\1))

xt_stat U_edges U "" "7"                                           // summary(U ~ edges) = 7
assert e(ties) == 7
assert e(N) == 21
xt_stat U_nodematch U "nodematch(g)" "7 2"                         // nodematch("g") = 2
xt_stat U_nodematchdiff U "nodematchdiff(g)" "7 1 1 0"             // nodematch("g", diff=TRUE) = 1 1 0
xt_stat U_nodematch_onelevel U "nodematch(one)" "7 7"              // nodematch("one") = 7 (one level: every tie matches)
xt_stat U_nodecov U "nodecov(x)" "7 29"                            // nodecov("x") = 29
xt_stat U_absdist U "absdist(x)" "7 13"                            // absdiff("x") = 13
xt_stat U_nodefactor U "nodefactor(g)" "7 6 1"                     // nodefactor("g") = 6 1 (levels 2 3)
xt_stat U_nodemix U "nodemix(g)" "7 4 1 1 0 0"                     // nodemix("g") = mix.g.1.2 2.2 1.3 2.3 3.3 = 4 1 1 0 0
xt_stat U_edgecov_valued U "edgecov(WU)" "7 45"                    // edgecov(W) = 45 (W[i,j] = i+j, valued covariate)
xt_stat U_hamming U "hamming(HU)" "7 8"                            // hamming(H) = 8
xt_stat U_degree U "degree(0/4)" "7 1 1 2 3 0"                     // degree(0:4) = 1 1 2 3 0 (degree 0: the isolate)
xt_stat U_concurrent U "concurrent" "7 5"                          // concurrent = 5
xt_stat U_triangle U "triangle" "7 2"                              // triangle = 2
xt_stat U_kstar U "kstar(1/4)" "7 14 11 3 0"                       // kstar(1:4) = 14 11 3 0
xt_stat U_kstar_beyond U "kstar(8)" "7 0"                          // kstar(8) = 0 (k larger than n - 1)
xt_stat U_degree_beyond U "degree(6)" "7 0"                        // degree(6) = 0 (no node has the largest possible degree)
xt_stat U_degrange_closed U "degrange(1) degrangeto(3)" "7 3"      // degrange(from=1, to=3) = 3
xt_stat U_degrange_open U "degrange(3)" "7 3"                      // degrange(from=3) = deg3+ = 3
xt_stat U_esp U "esp(0/3)" "7 2 4 1 0"                             // esp(0:3) = 2 4 1 0
xt_stat U_esp_long U "esp(0/6)" "7 2 4 1 0 0 0 0"                  // esp(0:6) = 2 4 1 0 0 0 0
xt_stat U_dsp U "dsp(0/3)" "7 12 7 2 0"                            // dsp(0:3) = 12 7 2 0
xt_stat U_structural_triangle U "structural(triangle)" "7 2"       // triangle = 2
di "PASS block U: covariate, degree, star and shared-partner terms"

* geometrically weighted terms at the boundaries of the decay. R: summary(U ~ gwesp(d, fixed=TRUE)) etc.
* Decay 30/40/100: (1 - exp(-d))^k is 1 in double precision for d >= ~37, so a naive exp(d) * (1 - (1 - exp(-d))^k)
* gives 0 or garbage there; R's value is the limit (the shared-partner / degree sum).
xt_stat U_gwesp0 U "gwesp(0)" "7 5"                                // gwesp(0) = 5 (number of ties with >= 1 shared partner)
xt_stat U_gwdsp0 U "gwdsp(0)" "7 9"                                // gwdsp(0) = 9
xt_stat U_gwnsp0 U "gwnsp(0)" "7 4"                                // gwnsp(0) = 4
xt_stat U_gwdegree0 U "gwdegree(0)" "7 6"                          // gwdegree(0) = 6 (nodes with degree >= 1)
xt_stat U_gwesp05 U "gwesp(.5)" "7 5.39346934028737"
xt_stat U_gwdsp05 U "gwdsp(.5)" "7 9.78693868057473"
xt_stat U_gwnsp05 U "gwnsp(.5)" "7 4.39346934028737"
xt_stat U_gwdegree05 U "gwdegree(.5)" "7 8.43180106667536"
xt_stat U_gwesp1 U "gwesp(1)" "7 5.63212055882856"
xt_stat U_gwdsp1 U "gwdsp(1)" "7 10.2642411176571"
xt_stat U_gwnsp1 U "gwnsp(1)" "7 4.63212055882856"
xt_stat U_gwdegree1 U "gwdegree(1)" "7 10.359331996824"
xt_stat U_gwesp10 U "gwesp(10)" "7 5.99995460007024"
xt_stat U_gwdsp10 U "gwdsp(10)" "7 10.9999092001405"
xt_stat U_gwnsp10 U "gwnsp(10)" "7 4.99995460007024"
xt_stat U_gwdegree10 U "gwdegree(10)" "7 13.9995006069561"
* CONFIRMED BUG N5: decay 30 loses ~3 digits, decay >= ~37 gives 0 (R gives the limit); naive exp(d)*(1-(1-exp(-d))^k)
xt_stat U_gwesp30 U "gwesp(30)" "7 5.99999999999991"
xt_stat U_gwdegree30 U "gwdegree(30)" "7 13.999999999999"
xt_stat U_gwesp40 U "gwesp(40)" "7 6"
xt_stat U_gwdsp40 U "gwdsp(40)" "7 11"
xt_stat U_gwnsp40 U "gwnsp(40)" "7 5"
xt_stat U_gwdegree40 U "gwdegree(40)" "7 14"
xt_stat U_gwesp100 U "gwesp(100)" "7 6"
xt_stat U_gwdegree100 U "gwdegree(100)" "7 14"
di "PASS block U: geometrically weighted terms, decay 0 to 100"

* a negative decay: R's summary() returns NaN (gwesp(-1, fixed=TRUE) and gwdegree(-1, fixed=TRUE)); there is no R value
* to match. Record what nwergm does (refusal with 198 or a number) without asserting.
* TODO-R: decide the wanted behaviour (R: summary(U ~ gwesp(-1, fixed=TRUE)) is NaN; ergm() then fails).
capture noisily nwergm U, edges gwesp(-1) method(mple)
local rcneg = _rc
if `rcneg' == 0 {
	matrix __S = e(obs_stats)
	di as txt "SOFT gwesp(-1): accepted, statistic " __S[1,2] " (R: NaN)"
}
else di as txt "SOFT gwesp(-1): refused with r(`rcneg')"
di "PASS block U: negative decay recorded"

* single-level attribute in nodefactor()/nodemix(): R skips the term ("contributes no statistics"); summary() returns
* edges only. nwergm should either drop it the same way or refuse it cleanly (a 1-column model, not a Mata error).
* R: summary(U ~ edges + nodefactor("one")) = 7 (with the note); summary(U ~ edges + nodemix("one")) = 7.
foreach t in nodefactor nodemix {
	capture noisily nwergm U, edges `t'(one) method(mple)
	local rc1 = _rc
	if `rc1' == 0 {
		assert colsof(e(b)) == 1
		matrix __S = e(obs_stats)
		assert colsof(__S) == 1 & __S[1,1] == 7
		di as txt "PASS `t'(one): term dropped as in R"
	}
	else {
		* a refusal must be a Stata error code of the input checks, not a Mata failure (3000-3999)
		if `rc1' >= 3000 & `rc1' <= 3999 {
			// CONFIRMED BUG N4: single-level factor -> raw Mata error in _ergm_cov_pick (R drops the term)
			di as err "FAIL `t'(one): raw Mata error r(`rc1')"
			global XT_FAILS "$XT_FAILS `t'_onelevel(N4)"
		}
		else di as txt "SOFT `t'(one): refused with r(`rc1') (R drops the term with a note)"
	}
}
* nodematchdiff() with a single level: R nodematch("one", diff=TRUE) = 7 (one column nodematch.one.1)
xt_stat U_nodematchdiff_onelevel U "nodematchdiff(one)" "7 7"
di "PASS block U: single attribute level"

* attribute with a missing value: R stops ("Attribute 'gm' has missing data, which is not currently supported by ergm");
* nwergm documents rc 416 (help nwergm_fit, Missing covariates; nwergm.ado _nwergm_numvar)
foreach t in nodematch nodecov nodefactor nodemix absdist nodematchdiff {
	capture noisily nwergm U, edges `t'(gm) method(mple)
	assert _rc == 416
}
di "PASS block U: attribute with a missing value refused with 416"

* ---------------------------------------------------------------------------------------------------------------
* near-empty (one tie 1-2) and near-complete (all but 1-2) networks on 5 nodes
* R: NE <- add.edges(network.initialize(5, directed=FALSE), 1, 2); Am <- matrix(1,5,5)-diag(5); Am[1,2] <- Am[2,1] <- 0
*    NK <- network(Am, directed=FALSE)
xt_stat NE_triangle NE "triangle" "1 0"                             // summary(NE ~ edges + triangle)
xt_stat NE_kstar NE "kstar(2)" "1 0"
xt_stat NE_degree NE "degree(0/4)" "1 3 2 0 0 0"
xt_stat NE_esp NE "esp(0/3)" "1 1 0 0 0"
xt_stat NE_dsp NE "dsp(0/3)" "1 10 0 0 0"
xt_stat NE_gwesp NE "gwesp(.5)" "1 0"
xt_stat NE_gwdegree NE "gwdegree(.5)" "1 2"
xt_stat NK_triangle NK "triangle" "9 7"
xt_stat NK_kstar NK "kstar(2)" "9 24"
xt_stat NK_degree NK "degree(0/4)" "9 0 0 0 2 3"
xt_stat NK_esp NK "esp(0/3)" "9 0 0 6 3"
xt_stat NK_dsp NK "dsp(0/3)" "9 0 0 6 4"
xt_stat NK_gwesp NK "gwesp(.5)" "9 13.0056784278248"
xt_stat NK_gwdegree NK "gwdegree(.5)" "9 7.9241858628517"
di "PASS block near-empty / near-complete"

* empty and complete networks: every dyad has the same value, the pseudolikelihood has no maximum; nwergm stops with
* the error of logit (r(2000), nwergm.ado around line 2234) and restores the data.
* R: ergm(E ~ edges, estimate = "MPLE") returns -Inf with a warning; summary(E ~ edges + triangle + ...) is all 0
* except degree0 = 5 and dsp0 = 10. The statistics cannot be read through e(obs_stats) here (there is no fit).
local nobs0 = _N
foreach net in E5 K5 {
	capture noisily nwergm `net', edges triangle method(mple)
	assert _rc == 2000
	assert _N == `nobs0'
	confirm variable g x one gm
}
di "PASS block empty / complete: r(2000), data restored"

* ---------------------------------------------------------------------------------------------------------------
* valued network: values 2, 0.5 and -1 on the ties of U. R: ergm() without response= uses the binary network,
* a tie being a non-zero value (as the comment in nwergm.ado around line 263 says); statistics are those of U.
xt_stat UV_edges UV "triangle kstar(2)" "7 2 11"                   // as U: edges 7, triangle 2, kstar2 11
assert e(ties) == 7
di "PASS block valued network fitted as binary"

* ---------------------------------------------------------------------------------------------------------------
* florentine marriage network (R: data(florentine); summary(flomarriage ~ ...)). Whole-network statistics do not
* depend on the node order of the file.
nwuse `"`nwcore'/data/florentine"', nwclear
xt_stat flo_triangle flomarriage "triangle" "20 3"
xt_stat flo_kstar flomarriage "kstar(2 3)" "20 47 34"
xt_stat flo_gwesp flomarriage "gwesp(.5)" "20 8.39346934028737"
xt_stat flo_gwdegree flomarriage "gwdegree(.5)" "20 20.93767397160774"
xt_stat flo_degree flomarriage "degree(0/2)" "20 1 4 2"
xt_stat flobus_triangle flobusiness "triangle" "15 5"
capture confirm numeric variable wealth
if _rc == 0 {
	xt_stat flo_wealth flomarriage "nodecov(wealth)" "20 2168"     // nodecov("wealth") = 2168
}
else di as txt "SKIP flo_wealth: variable wealth not in the florentine data of the core"
di "PASS block florentine"

if "$XT_FAILS" != "" {
	di as err "failures:$XT_FAILS"
	exit 9
}
di "ALL PASS"

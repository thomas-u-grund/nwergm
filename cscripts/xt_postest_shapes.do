cscript

* DRAFT, not yet run.
* xt_postest_shapes: estat gof, nwergm simulate (from a fit), predict, estat ic and estat mcmcdiag on an undirected, a
* directed and a two-mode network. Checks: tables and summary values against hand-derived observed values, the options
* reach the computation (nsim, burnin, interval, seed), simulated networks keep size, direction, modes and the sample-space
* constraints of the fit, r(stats) agrees with the simulated networks, predict against the closed form of
* dyad-independent and dyad-level models, boundary coefficients (all draws empty / complete), empty edge lists.
* Expected runtime: about 1-2 minutes.
* Runs from the repository root; the runner sets PLUS, the adopath and the plugin path.
capture program drop nwinstall
set graphics off

* U14 and D12 as in xt_mple_crossroute.do; BIP: 6 (mode 1) x 9 (mode 2), random
nwclear
clear
mata: ui = (1,2,3,1,4,4,5,1,6,1,5,1,6,7,9,10,4,7,10,2,5,6,10,11,2,7,10)
mata: uj = (2,4,4,5,5,6,6,7,8,9,9,10,11,11,11,11,12,12,12,13,13,13,13,13,14,14,14)
mata: A = J(14, 14, 0)
mata: for (k = 1; k <= 27; k++) A[ui[k], uj[k]] = 1
mata: A = A + A'
mata: st_matrix("AU14", A)
mata: dt = (4,9,3,6,5,7,9,10,11,12,1,10,3,5,9,1,4,6,10,12,3,4,5,10,4,12,9,9)
mata: dh = (1,1,2,2,3,3,3,4,4,4,5,5,6,6,6,7,7,8,8,8,9,9,9,9,10,10,11,12)
mata: B = J(12, 12, 0)
mata: for (k = 1; k <= 28; k++) B[dt[k], dh[k]] = 1
mata: st_matrix("AD12", B)
mata: rseed(13)
mata: BT = runiform(9, 6) :< 0.35
mata: st_matrix("BT", BT)
nwset, mat(AU14) undirected name(U14) nooutput
nwset, mat(AD12) directed name(D12) nooutput
nwset, mat(BT) bipartite name(BIP) nooutput
qui nwsummarize BIP
local bipties = r(edges)
assert r(nodes1) == 6 & r(nodes2) == 9
clear
set obs 15
gen double g = mod(_n - 1, 2) + 1
gen double x = _n / 4
gen double blk = (_n > 6) + 1

* ---------------------------------------------------------------------------------------------------------------
* undirected
nwergm U14, edges gwesp(.5) method(mple)
matrix OS = e(obs_stats)
capture noisily estat mcmcdiag
assert _rc == 498
estat ic
matrix IC = r(S)
assert IC[1,1] == 91
estat gof, nsim(20) seed(5) gofburnin(2000) gofinterval(64)
assert r(nsim) == 20 & r(burnin) == 2000 & r(interval) == 64
matrix GM = r(gof_model)
matrix GD = r(gof_degree)
matrix GE = r(gof_espartners)
confirm matrix r(gof_distance)
assert reldif(GM[1,1], OS[1,1]) < 1e-12 & reldif(GM[2,1], OS[1,2]) < 1e-12
mata: st_numscalar("sd", colsum(st_matrix("GD")[., 1])); st_numscalar("se", colsum(st_matrix("GE")[., 1]))
assert sd == 14 & se == 27
* hand-derived summary values (cscripts xt notes: python over the edge list): mean degree 54/14, average path
* 175/91 = 1.923076923 (U14 is connected), triad census 003 126, 102 157, 201 76, 300 5
assert reldif(r(obs_meandeg), 54/14) < 1e-12
assert reldif(r(obs_avgpath), 175/91) < 1e-9
assert r(obs_triad_003) == 126 & r(obs_triad_102) == 157 & r(obs_triad_201) == 76 & r(obs_triad_300) == 5
* every MC p-value in [0, 1], min <= mean <= max
foreach t in GM GD GE {
	mata: P = st_matrix("`t'"); assert(all((P[., 5] :>= 0) :& (P[., 5] :<= 1))); assert(all(P[., 2] :<= P[., 3] :+ 1e-12)); assert(all(P[., 3] :<= P[., 4] :+ 1e-12))
}
* same seed, same tables; the default statistics include the model
estat gof, nsim(20) seed(5) gofburnin(2000) gofinterval(64)
matrix GM2 = r(gof_model)
// CONFIRMED BUG N6: estat gof moves the stored graph __nwergm_last_G to the last gof draw (ergm_gof_run,
// unw_ergm.do:5742-5770), so a second estat gof with the same seed starts elsewhere; also nwergm simulate after it
global XT_FAILS ""
if mreldif(GM, GM2) != 0 {
	di as err "FAIL estat gof, seed(5) twice gives different tables (mreldif " mreldif(GM, GM2) ")"
	global XT_FAILS "$XT_FAILS N6"
}
estat gof, gof(-model degree) nsim(5) seed(1)
capture confirm matrix r(gof_model)
assert _rc != 0
* default interval after an MPLE fit: _nwergm_gof.ado:29-35 gives ceil(1024 * 1 / nsim) = 52 for nsim(20), because
* e(mcmc_samplesize) does not exist; R's gof.ergm multiplies by EVL(samplesize / nsim, 1), i.e. by 1 when the fit has
* no sample size, which gives 1024. Recorded, not asserted.
* TODO-R: fit <- ergm(nw ~ edges + gwesp(0.5, fixed=TRUE), estimate="MPLE"); trace the MCMC.interval that
*         gof(fit, control=control.gof.ergm(nsim=20)) passes to simulate() (expected 1024)
qui estat gof, gof(model) nsim(20) seed(1)
di as txt "SOFT default gof interval after MPLE with nsim(20): " r(interval) " (R: 1024 expected, see TODO-R)"
* assert r(interval) == 1024
capture noisily estat gof, nsim(1)
assert _rc == 198
capture noisily estat gof, gof(idegree) nsim(5)
assert _rc == 198
capture noisily estat gof, gof(b1degree) nsim(5)
assert _rc == 198
capture noisily estat gof, gof(nonsense) nsim(5)
assert _rc == 198
di "PASS estat gof / ic / mcmcdiag, undirected"

* nwergm simulate from the fit
nwergm simulate, nsim(3) generate(su) seed(2) burnin(500) interval(50)
matrix SS = r(stats)
assert rowsof(SS) == 3 & colsof(SS) == 2
assert r(nsim) == 3 & r(burnin) == 500 & r(interval) == 50
forvalues s = 1/3 {
	qui nwsummarize su_`s'
	assert r(nodes) == 14 & "`r(directed)'" == "false"
	assert r(edges) == SS[`s', 1]
}
nwergm simulate, nsim(4) output(stats) seed(3) burnin(500) interval(50)
matrix T1 = r(stats)
nwergm simulate, nsim(4) output(stats) seed(3) burnin(500) interval(50)
matrix T2 = r(stats)
assert mreldif(T1, T2) == 0
* output(edgelist): one row per tie, undirected ties once (unw_ergm.do ergm_sim_run, j > i)
capture noisily nwergm simulate, nsim(2) output(edgelist) seed(3)
assert _rc == 198
nwergm simulate, nsim(2) output(edgelist) clear seed(3) burnin(500) interval(50)
matrix T3 = r(stats)
forvalues s = 1/2 {
	qui count if _sim == `s'
	assert r(N) == T3[`s', 1]
}
assert _tail < _head
* boundary coefficients: edges -50 gives empty draws, +50 complete draws (dyad probability e^-50 / 1 - e^-50)
matrix CN = (-50, 0)
nwergm simulate, nsim(2) output(stats) coef(CN) seed(1) burnin(2000) interval(100)
matrix T4 = r(stats)
assert T4[1,1] == 0 & T4[2,1] == 0
matrix CP = (50, 0)
nwergm simulate, nsim(2) output(stats) coef(CP) seed(1) burnin(5000) interval(100)
matrix T5 = r(stats)
assert T5[1,1] == 91 & T5[2,1] == 91
* every draw empty with output(edgelist): no ties to list; the data should be empty, not an error
* (_nwergm_simfit.ado reads matrix __simE7_el, which a 0 x 3 Mata matrix may not create)
// CONFIRMED BUG E4: r(111) "__simE7_el not found" (_nwergm_simfit.ado edge-list branch, unw_ergm.do:5955)
capture noisily nwergm simulate, nsim(2) output(edgelist) clear coef(CN) seed(1) burnin(2000) interval(100)
if _rc {
	di as err "FAIL all-empty draws with output(edgelist): r(`=_rc')"
	global XT_FAILS "$XT_FAILS E4"
}
else assert _N == 0
* option errors of simulate from a fit
capture noisily nwergm simulate, nsim(0)
assert _rc == 198
capture noisily nwergm simulate, output(graph)
assert _rc == 198
capture noisily nwergm simulate, coef(nosuchmatrix)
assert _rc == 111
matrix C3 = (1, 2, 3)
capture noisily nwergm simulate, coef(C3)
assert _rc == 198
capture noisily nwergm simulate, basis(D12)
assert _rc == 498
di "PASS nwergm simulate after an undirected fit"

* predict: dyad-independent model, P[i,j] = invlogit(b0 + b1 (g_i == g_j)), symmetric (derived from e(b))
clear
set obs 15
gen double g = mod(_n - 1, 2) + 1
gen double x = _n / 4
gen double blk = (_n > 6) + 1
nwergm U14, edges nodematch(g)
predict, matrix(PU)
predict, matrix(XU) xb
predict, frame(FU)
mata: P = st_matrix("PU"); X = st_matrix("XU"); b = st_matrix("e(b)"); g = st_data(1::14, "g"); O = 1 :- I(14)
mata: E = b[1] :+ b[2] :* (g * J(1, 14, 1) :== J(14, 1, 1) * g'); st_numscalar("dp", max(editmissing(abs(P - invlogit(E)) :* O, 0))); st_numscalar("dx", max(editmissing(abs(X - E) :* O, 0)))
mata: st_numscalar("asym", max(editmissing(abs(P - P'), 0)))
assert dp < 1e-10 & dx < 1e-10 & asym == 0
frame FU: assert _N == 91
frame FU: assert p > 0 & p < 1
frame drop FU
capture noisily predict
assert _rc == 198
capture noisily predict, matrix(PZ) pr xb
assert _rc == 198
di "PASS predict, undirected"

* ---------------------------------------------------------------------------------------------------------------
* directed: edges + mutual by MPLE; the change statistic of i->j is (1, A_ji), so xb_ij = b0 + b1 A_ji (derived)
nwergm D12, edges mutual method(mple)
predict, matrix(XD) xb
mata: X = st_matrix("XD"); A = st_matrix("AD12"); b = st_matrix("e(b)"); O = 1 :- I(12)
mata: st_numscalar("dx", max(editmissing(abs(X - (b[1] :+ b[2] :* A')) :* O, 0)))
assert dx < 1e-10
estat ic
matrix IC = r(S)
assert IC[1,1] == 132
estat gof, nsim(10) seed(4) gofinterval(64)
matrix GI = r(gof_idegree)
matrix GO = r(gof_odegree)
matrix GE = r(gof_espartners)
confirm matrix r(gof_distance)
mata: st_numscalar("si", colsum(st_matrix("GI")[., 1])); st_numscalar("so", colsum(st_matrix("GO")[., 1])); st_numscalar("se", colsum(st_matrix("GE")[., 1]))
assert si == 12 & so == 12 & se == 28
assert reldif(r(obs_meandeg), 2 * 28 / 12) < 1e-12
* the 16 MAN triad types of the observed network add up to C(12,3) = 220 triads
local tsum 0
foreach c in 003 012 102 021D 021U 021C 111D 111U 030T 030C 201 120D 120U 120C 210 300 {
	local tsum = `tsum' + r(obs_triad_`c')
}
assert `tsum' == 220
capture noisily estat gof, gof(degree) nsim(5)
assert _rc == 198
nwergm simulate, nsim(2) generate(sd) seed(2) burnin(500) interval(50)
matrix SS = r(stats)
forvalues s = 1/2 {
	qui nwsummarize sd_`s'
	assert r(nodes) == 12 & "`r(directed)'" == "true"
	assert r(arcs) == SS[`s', 1]
}
di "PASS directed postestimation"

* directed constraints are kept by the simulation: odegrees (every out-degree fixed) and blockdiag (only dyads inside
* blocks 1-6 and 7-12 vary; the between-block arcs stay as observed)
nwergm D12, edges mutual constraints(odegrees) seed(3) mcmcinterval(128)
nwergm simulate, nsim(3) generate(co) seed(4)
forvalues s = 1/3 {
	qui nwtomata co_`s', mat(__C)
	mata: assert(rowsum(__C) == rowsum(st_matrix("AD12")))
}
nwergm D12, edges mutual constraints(blockdiag(blk)) seed(3) mcmcinterval(128)
nwergm simulate, nsim(3) generate(cb) seed(4)
forvalues s = 1/3 {
	qui nwtomata cb_`s', mat(__C)
	mata: A0 = st_matrix("AD12"); assert(__C[1::6, 7::12] == A0[1::6, 7::12]); assert(__C[7::12, 1::6] == A0[7::12, 1::6])
}
di "PASS simulation keeps odegrees and blockdiag constraints"

* undirected degrees constraint
nwergm U14, edges gwesp(.5) constraints(degrees) seed(3) mcmcinterval(128)
nwergm simulate, nsim(3) generate(cd) seed(4)
forvalues s = 1/3 {
	qui nwtomata cd_`s', mat(__C)
	mata: assert(rowsum(__C) == rowsum(st_matrix("AU14"))); assert(__C == __C')
}
di "PASS simulation keeps the degrees constraint"

* ---------------------------------------------------------------------------------------------------------------
* two-mode: modes 1..6 and 7..15
nwergm BIP, edges bcov1(x) method(mple)
assert e(N) == 54
* predict: the tie probability depends on the mode-1 endpoint's x only; only the 54 dyads between the modes are informative
predict, frame(FB)
frame FB: assert _N == 54
mata: b = st_matrix("e(b)"); x = st_data(1::15, "x")
frame FB: mata: T = st_data(., ("tail", "head", "p")); m1 = rowmin(T[., 1..2]); m2 = rowmax(T[., 1..2])
frame FB: mata: assert(all(m1 :<= 6) & all(m2 :>= 7)); st_numscalar("dp", max(abs(T[., 3] - invlogit(b[1] :+ b[2] :* x[m1]))))
assert dp < 1e-10
frame drop FB
estat ic
matrix IC = r(S)
assert IC[1,1] == 54
estat gof, nsim(10) seed(4) gofinterval(64)
matrix G1 = r(gof_b1degree)
matrix G2 = r(gof_b2degree)
matrix GS = r(gof_dspartners)
confirm matrix r(gof_distance)
mata: st_numscalar("s1", colsum(st_matrix("G1")[., 1])); st_numscalar("s2", colsum(st_matrix("G2")[., 1])); st_numscalar("ss", colsum(st_matrix("GS")[., 1]))
mata: st_numscalar("k1", colsum((0::rows(st_matrix("G1"))-1) :* st_matrix("G1")[., 1]))
* mode-1 degree counts sum to n1 = 6, mode-2 to n2 = 9; sum of degree x count = ties; dyadwise shared partners over
* same-mode pairs: C(6,2) + C(9,2) = 15 + 36 = 51
assert s1 == 6 & s2 == 9 & ss == 51
assert k1 == `bipties'
capture noisily estat gof, gof(degree) nsim(5)
assert _rc == 198
capture noisily estat gof, gof(espartners) nsim(5)
assert _rc == 198
nwergm simulate, nsim(2) generate(sb) seed(2) burnin(500) interval(50)
matrix SS = r(stats)
forvalues s = 1/2 {
	qui nwsummarize sb_`s'
	assert "`r(mode2)'" == "true" & r(nodes1) == 6 & r(nodes2) == 9
	assert r(edges) == SS[`s', 1]
	qui nwtomata sb_`s', mat(__S)
	mata: assert(sum(__S[1::6, 1::6]) == 0 & sum(__S[7::15, 7::15]) == 0)
}
nwergm simulate, nsim(2) output(edgelist) clear seed(2) burnin(500) interval(50)
assert min(_tail, _head) <= 6 & max(_tail, _head) >= 7
di "PASS two-mode postestimation"

if "$XT_FAILS" != "" {
	di as err "failures:$XT_FAILS"
	exit 9
}
di "ALL PASS"

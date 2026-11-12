cscript

* DRAFT, not yet run.
* xt_mcmle: Monte Carlo maximum likelihood on easy models whose MLE is known in closed form, seed reproducibility
* across sessions-like state changes, offset()/init()/constraints, options that must reach the estimator (stored in e()),
* models with a single free coefficient (1 x 1 matrices in the MCMLE, the covariance and estat mcmcdiag), CD and SA.
* MCMC tolerances are stated next to each check; they are loose on purpose (about 0.5 standard errors).
* Expected runtime: about 1-2 minutes (about 20 short MCMLE fits on 12- and 14-node networks).
* Runs from the repository root; the runner sets PLUS, the adopath and the plugin path.
capture program drop nwinstall
set graphics off
local nwcore : env NWCORE

* D12 (directed, 12 nodes, 28 arcs: 2 mutual dyads, 24 asymmetric dyads, 40 null dyads) and U14 (undirected, 27 ties),
* the networks of xt_mple_crossroute.do (R: set.seed(777) / set.seed(4242), see there)
nwclear
clear
mata: dt = (4,9,3,6,5,7,9,10,11,12,1,10,3,5,9,1,4,6,10,12,3,4,5,10,4,12,9,9)
mata: dh = (1,1,2,2,3,3,3,4,4,4,5,5,6,6,6,7,7,8,8,8,9,9,9,9,10,10,11,12)
mata: B = J(12, 12, 0)
mata: for (k = 1; k <= 28; k++) B[dt[k], dh[k]] = 1
mata: st_matrix("AD12", B)
mata: ui = (1,2,3,1,4,4,5,1,6,1,5,1,6,7,9,10,4,7,10,2,5,6,10,11,2,7,10)
mata: uj = (2,4,4,5,5,6,6,7,8,9,9,10,11,11,11,11,12,12,12,13,13,13,13,13,14,14,14)
mata: A = J(14, 14, 0)
mata: for (k = 1; k <= 27; k++) A[ui[k], uj[k]] = 1
mata: A = A + A'
mata: st_matrix("AU14", A)
nwset, mat(AD12) directed name(D12) nooutput
nwset, mat(AU14) undirected name(U14) nooutput
clear
set obs 14
gen double g = mod(_n - 1, 2) + 1

* ---------------------------------------------------------------------------------------------------------------
* edges + mutual factorises over dyads: P(null) : P(one asymmetric arc) : P(mutual) = 1 : e^te : e^(2te+tm), so the MLE is
* te = ln(24 / (2 * 40)) = -1.2039728043259361, tm = ln(2 / 40) - 2 te = -0.5877866649021186 (derived by hand).
* MCMLE must land within 0.5 standard errors of it (MC error of the adaptive sample is about 0.05 SE, GOTCHA.md).
nwergm D12, edges mutual seed(101)
assert "`e(method)'" == "mcmle"
assert e(converged) == 1
assert abs(_b[edges] - (-1.2039728043259361)) < 0.5 * _se[edges]
assert abs(_b[mutual] - (-0.5877866649021186)) < 0.5 * _se[mutual]
matrix b1 = e(b)
matrix V1 = e(V)
di "PASS MCMLE edges + mutual within 0.5 SE of the closed-form MLE"

* same seed, after other networks were loaded and other models fitted (the core then returns neighbours in another
* order; GOTCHA.md "seed() did not reproduce a fit across sessions"): bit-identical e(b) and e(V)
nwuse `"`nwcore'/data/florentine"', nwappend
qui nwergm flomarriage, edges gwesp(.5) seed(5) mcmcinterval(100)
qui nwergm U14, edges triangle method(mple)
nwergm D12, edges mutual seed(101)
matrix b2 = e(b)
matrix V2 = e(V)
assert mreldif(b1, b2) == 0
assert mreldif(V1, V2) == 0
nwergm D12, edges mutual seed(102)
matrix b3 = e(b)
assert mreldif(b1, b3) > 0
di "PASS seed(): identical after other work, different for another seed"
* nwuse replaced the dataset: the node attribute of U14 again
clear
set obs 14
gen double g = mod(_n - 1, 2) + 1

* offset(mutual 1): the MLE of edges then solves E[arcs] = 28 per 66 dyads, a = 28/66:
* (2 e^te + 2 e^(2te+1)) / (1 + 2 e^te + e^(2te+1)) = a  =>  te = -1.5711811910452254 (quadratic in e^te, by hand)
nwergm D12, edges mutual offset(mutual 1) seed(7)
assert _b[mutual] == 1
assert _se[mutual] == 0
assert e(df_m) == 1
assert abs(_b[edges] - (-1.5711811910452254)) < 0.5 * _se[edges]
matrix V = e(V)
assert V[2,2] == 0 & V[1,2] == 0 & V[2,1] == 0
di "PASS offset() with MCMLE: fixed value, SE 0, free coefficient at the constrained MLE"

* the edges-only model forced to MCMLE (dyad-independent: exact MLE ln(27/64), SE 0.2294821061369209)
* -> a model with ONE coefficient: 1 x 1 e(b), e(V), sample of one column, estat mcmcdiag with 1 x 1 r(ess)/r(geweke)
nwergm U14, edges method(mcmle) seed(3)
assert "`e(method)'" == "mcmle"
assert colsof(e(b)) == 1
assert abs(_b[edges] - ln(27/64)) < 0.5 * 0.2294821061369209
matrix M = e(mcmcsample)
assert colsof(M) == 1 & rowsof(M) > 1
estat mcmcdiag
matrix E = r(ess)
matrix G = r(geweke)
matrix H = r(heidel)
assert colsof(E) == 1 & colsof(G) == 1
assert rowsof(H) == 1 & colsof(H) == 6
assert r(acceptrate) > 0 & r(acceptrate) <= 1
estat mcmcdiag, heidel report
estat gof, gof(model) nsim(10) seed(1)
matrix GM = r(gof_model)
assert rowsof(GM) == 1 & colsof(GM) == 5
assert GM[1,1] == 27
assert GM[1,2] <= GM[1,3] & GM[1,3] <= GM[1,4]
estat ic
di "PASS one-coefficient MCMLE and its postestimation (1 x 1 matrices)"

* edges + nodematch(g), dyad-independent, forced to MCMLE: within 0.5 SE of the exact MLE (the logit fit)
qui nwergm U14, edges nodematch(g)
matrix bx = e(b)
matrix Vx = e(V)
nwergm U14, edges nodematch(g) method(mcmle) seed(9)
assert abs(_b[edges] - bx[1,1]) < 0.5 * sqrt(Vx[1,1])
assert abs(_b[nodematch_g] - bx[1,2]) < 0.5 * sqrt(Vx[2,2])
di "PASS dyad-independent model by MCMLE within 0.5 SE of the exact MLE"

* ---------------------------------------------------------------------------------------------------------------
* options must arrive where they act (stored in e())
nwergm D12, edges mutual mcmcinterval(100) seed(4)
assert e(mcmc_interval) == 100
assert e(mcmc_burnin) == 1600                          // default burn-in = 16 x interval (GOTCHA.md, R: MCMLE.burnin)
nwergm D12, edges mutual mcmcinterval(100) mcmcburnin(500) seed(4)
assert e(mcmc_burnin) == 500
nwergm D12, edges mutual mcmleeffectivesize(0) mcmcsamplesize(500) mcmcinterval(100) seed(4)
assert e(mcmc_samplesize) == 500
matrix M = e(mcmcsample)
assert rowsof(M) == 500 & colsof(M) == 2
nwergm D12, edges mutual proposal(uniform) mcmcinterval(100) seed(4)
assert "`e(proposal)'" == "uniform"
nwergm D12, edges mutual mcmleiterations(1) mcmcinterval(100) seed(4)
assert e(mcmle_iterations) <= 1
nwergm D12, edges mutual nomcmcsample mcmcinterval(100) seed(4)
capture confirm matrix e(mcmcsample)
assert _rc != 0
capture noisily estat mcmcdiag
assert _rc == 498
nwergm D12, edges mutual nologlik mcmcinterval(100) seed(4)
assert missing(e(ll))
di "PASS options stored in e()"

* predict after a fit with nologlik: the help (nwergm_fit) offers predict after every fit except curved ones.
* e(predict) is set in _nwergm_fitstats.ado AFTER "if missing(ll) exit" (line 51-53), so a nologlik fit has no
* e(predict) and predict falls back to Stata's default. Expected to FAIL until fixed (suspected bug).
nwergm D12, edges mutual nologlik mcmcinterval(100) seed(4)
capture noisily predict, matrix(Pn)
local rcp = _rc
// E1 (fixed): e(predict) is set after nologlik too; formerly Stata's default predict ran
global XT_FAILS ""
if `rcp' != 0 {
	di as err "FAIL predict after nologlik: r(`rcp'); e(predict) = `e(predict)'"
	global XT_FAILS "$XT_FAILS E1"
}
else {
	assert rowsof(Pn) == 12
	di "PASS predict after nologlik"
}

* ---------------------------------------------------------------------------------------------------------------
* init(): one value per coefficient, . = estimated (help nwergm_estimation); a wrong count is refused (198)
nwergm D12, edges mutual init(-1.2 .) seed(5)
assert e(converged) == 1
assert abs(_b[edges] - (-1.2039728043259361)) < 0.5 * _se[edges]
nwergm D12, edges mutual init(-1.2 -0.6) seed(5)
assert abs(_b[mutual] - (-0.5877866649021186)) < 0.5 * _se[mutual]
capture noisily nwergm D12, edges mutual init(-1.2)
assert _rc == 198
capture noisily nwergm D12, edges mutual init(-1.2 abc)
assert _rc == 198
di "PASS init()"

* constraints(edges): edges is held constant and dropped with a note, as in R; the fit keeps the tie count
nwergm U14, edges gwesp(0.5) constraints(edges) seed(6) mcmcinterval(256)
assert _b[edges] == 0
assert _se[edges] == 0
nwergm simulate, nsim(3) output(stats) seed(1)
matrix SS = r(stats)
forvalues s = 1/3 {
	assert SS[`s',1] == 27
}
* fixdensity (the older spelling of the same constraint): edges is not estimated
nwergm U14, edges gwesp(0.5) fixdensity seed(6) mcmcinterval(256)
local cn : colnames e(b)
assert strpos("`cn'", "gwesp") > 0
di "PASS constraints(edges) / fixdensity"

* contrastive divergence and stochastic approximation run on a small model and say what they are
nwergm D12, edges mutual method(cd) seed(8)
assert "`e(estimate)'" == "CD"
nwergm D12, edges mutual mainmethod(sa) seed(8) saphase3(200)
assert "`e(estimate)'" == "SA"
assert abs(_b[edges] - (-1.2039728043259361)) < 1.0 * _se[edges]
di "PASS CD and SA"

* curved term by MCMLE: runs, e(curved) = 1, no log-likelihood, predict refused (help: not for curved models)
nwergm U14, edges gwespfree(0.5) seed(12) mcmcinterval(256)
assert e(curved) == 1
assert missing(e(ll))
capture noisily predict, matrix(Pc)
assert _rc != 0
di "PASS curved MCMLE"

if "$XT_FAILS" != "" {
	di as err "failures:$XT_FAILS"
	exit 9
}
di "ALL PASS"

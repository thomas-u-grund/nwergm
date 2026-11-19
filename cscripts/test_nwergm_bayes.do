cscript

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

mata:
void _tb_exact(real scalar E, real scalar Tm, real scalar Nm, real scalar N){
	real colvector A, B
	real matrix LP, W
	real scalar i, j
	A = rangen(-4.5, 1, 451)
	B = rangen(-3, 4, 561)
	LP = J(rows(A), rows(B), .)
	for (i=1; i<=rows(A); i++) for (j=1; j<=rows(B); j++) {
		LP[i,j] = A[i] * E + B[j] * Tm - Nm * ln(1 + exp(A[i] + B[j])) - (N - Nm) * ln(1 + exp(A[i])) - (A[i]^2 + B[j]^2) / 200
	}
	W = exp(LP :- max(LP))
	W = W / sum(W)
	st_numscalar("__tb_ma", sum(rowsum(W) :* A))
	st_numscalar("__tb_mb", sum(colsum(W)' :* B))
	st_numscalar("__tb_sa", sqrt(sum(rowsum(W) :* (A :- sum(rowsum(W) :* A)):^2)))
	st_numscalar("__tb_sb", sqrt(sum(colsum(W)' :* (B :- sum(colsum(W)' :* B)):^2)))
}
end

* Bayesian ERGM, estimate(bayes): the exchange algorithm with adaptive direction sampling (R: Bergm 6.0.0, bergm()).
*  1. exact posterior of a dyad-independent model (numerical integration) against the posterior sample
*  2. reference values of R's Bergm 6.0.0 (two seeds of 20,000 iterations per chain, 4 chains) for dyad-dependent models
*  3. reproducibility, options, stored results, posterior summaries, estat commands
*  4. recovery of known parameters on simulated networks
*  5. error paths

capture program drop _chk
program _chk
	gettoken what 0 : 0
	local ok = `0'
	if `ok' di as txt "PASS: `what'"
	else {
		di as err "FAIL: `what'"
		exit 9
	}
end

nwwebuse florentine, nwclear
nwset
quietly summarize wealth, detail
generate rich = wealth > r(p50)
quietly count if rich == 1
local k = r(N)
local Nm = `k' * (`k' - 1) / 2 + (16 - `k') * (15 - `k') / 2
local N = 120

* ---- 1. exact posterior of edges + nodematch(rich) under the default prior N(0, 100): numerical integration over a grid
quietly nwergm flomarriage, edges nodematch(rich) estimate(bayes) seed(11) chains(6) burnin(200) iterations(5000)
matrix S = e(obs_stats)
local E = S[1, 1]
local Tm = S[1, 2]
mata: _tb_exact(`E', `Tm', `Nm', `N')
display "exact: edges " %8.4f scalar(__tb_ma) " (sd " %6.4f scalar(__tb_sa) ")  nodematch " %8.4f scalar(__tb_mb) " (sd " %6.4f scalar(__tb_sb) ")"
display "fit:   edges " %8.4f e(b)[1,1] " (sd " %6.4f e(sd)[1,1] ")  nodematch " %8.4f e(b)[1,2] " (sd " %6.4f e(sd)[1,2] ")  ESS " e(ess)[1,1] " " e(ess)[1,2]
_chk "exact posterior: edges mean" (abs(e(b)[1,1] - scalar(__tb_ma)) < 4 * e(sd)[1,1] / sqrt(e(ess)[1,1]) + 0.01)
_chk "exact posterior: nodematch mean" (abs(e(b)[1,2] - scalar(__tb_mb)) < 4 * e(sd)[1,2] / sqrt(e(ess)[1,2]) + 0.01)
_chk "exact posterior: edges sd" (abs(e(sd)[1,1] / scalar(__tb_sa) - 1) < 0.06)
_chk "exact posterior: nodematch sd" (abs(e(sd)[1,2] / scalar(__tb_sb) - 1) < 0.06)
_chk "R-hat near 1" (max(e(rhat)[1,1], e(rhat)[1,2]) < 1.05)
local lo = e(ci)[1, 1]
local hi = e(ci)[2, 1]
_chk "credible interval contains the posterior mean" (`lo' < e(b)[1,1] & e(b)[1,1] < `hi')

* ---- 2. Bergm 6.0.0 on the Florentine marriage network (R means of two seeds, 4 chains x 20,000 iterations, burn-in 100)
quietly nwergm flomarriage, edges triangle estimate(bayes) seed(3) burnin(100) iterations(8000)
display "edges + triangle: " %7.4f e(b)[1,1] " " %7.4f e(b)[1,2] "  sd " %6.4f e(sd)[1,1] " " %6.4f e(sd)[1,2] "  acceptance " %5.3f e(accept_rate)
_chk "Bergm: edges mean (R -1.608)" (abs(e(b)[1,1] + 1.608) < 0.08)
_chk "Bergm: triangle mean (R -0.183)" (abs(e(b)[1,2] + 0.183) < 0.15)
_chk "Bergm: edges sd (R 0.330)" (abs(e(sd)[1,1] / 0.330 - 1) < 0.10)
_chk "Bergm: triangle sd (R 0.573)" (abs(e(sd)[1,2] / 0.573 - 1) < 0.10)
_chk "acceptance rate in the range of Bergm (0.1 to 0.35)" (e(accept_rate) > 0.1 & e(accept_rate) < 0.35)
_chk "default number of chains: max(2p, 4)" (e(chains) == 4)

quietly nwergm flomarriage, edges gwespfree(0.5) estimate(bayes) seed(4) burnin(100) iterations(8000)
display "edges + gwesp (free decay): " %7.4f e(b)[1,1] " " %7.4f e(b)[1,2] " " %7.4f e(b)[1,3] "  sd " %6.4f e(sd)[1,1] " " %6.4f e(sd)[1,2] " " %6.4f e(sd)[1,3]
_chk "Bergm, free decay: edges mean (R -1.706)" (abs(e(b)[1,1] + 1.706) < 0.09)
_chk "Bergm, free decay: weight mean (R 0.029)" (abs(e(b)[1,2] - 0.029) < 0.07)
_chk "Bergm, free decay: decay mean (R 0.603)" (abs(e(b)[1,3] - 0.603) < 0.10)
_chk "Bergm, free decay: decay sd (R 0.515)" (abs(e(sd)[1,3] / 0.515 - 1) < 0.15)
_chk "decay positive in every draw" (e(ci)[1,3] > 0)
_chk "curved flag" (e(curved) == 1)

* ---- 3. reproducibility, options, stored results
quietly nwergm flomarriage, edges triangle estimate(bayes) seed(7) iterations(300)
matrix b1 = e(b)
matrix s1 = e(sd)
quietly nwergm flomarriage, edges triangle estimate(bayes) seed(7) iterations(300)
_chk "same seed, same posterior" (mreldif(b1, e(b)) == 0 & mreldif(s1, e(sd)) == 0)
quietly nwergm flomarriage, edges triangle estimate(bayes) seed(8) iterations(300)
_chk "other seed, other posterior" (mreldif(b1, e(b)) > 0)
quietly nwergm flomarriage, edges triangle method(bayes) seed(7) iterations(300)
_chk "method(bayes) is the same as estimate(bayes)" (mreldif(b1, e(b)) == 0)

quietly nwergm flomarriage, edges triangle estimate(bayes) seed(1) chains(5) burnin(50) iterations(200) thin(4) auxiterations(300) noadapt nodelayed ///
	priormean(0 0) priorvar(10) proposalvar(0.01) gamma(0.3) startvals(-1.5 0) targetaccept(0.3)
_chk "chains() and thin(): number of draws" (e(ndraws) == 5 * 50 & e(draws_per_chain) == 50 & e(chains) == 5 & e(thin) == 4)
_chk "noadapt, nodelayed: switched off" (e(adapt) == 0 & e(delayed) == 0 & e(gamma) == 0.3)
_chk "auxiterations() stored" (e(auxiterations) == 300 & e(mcmc_burnin) == 300)
_chk "prior stored" (e(prior_var)[1,1] == 10 & e(prior_mean)[1,2] == 0)
_chk "options stored" (e(proposalvar) == 0.01 & e(targetaccept) == 0.3 & e(burnin) == 50)

quietly nwergm flomarriage, edges triangle estimate(bayes) seed(2) iterations(1000) burnin(200)
_chk "e(cmd) and method" ("`e(cmd)'" == "nwergm" & "`e(method)'" == "bayes" & "`e(estimate)'" == "Bayes")
_chk "e(b) is the posterior mean, e(V) its covariance" (colsof(e(b)) == 2 & rowsof(e(V)) == 2 & e(V)[1,1] > 0)
_chk "e(V) diagonal is the squared e(sd)" (abs(e(V)[1,1] - e(sd)[1,1]^2) < 1e-10)
_chk "e(median), e(ci), e(ess), e(rhat) have one entry per coefficient" (colsof(e(median)) == 2 & colsof(e(ci)) == 2 & rowsof(e(ci)) == 2 & colsof(e(ess)) == 2 & colsof(e(rhat)) == 2)
_chk "frame with the draws" ("`e(post_frame)'" == "nwergm_bayes_draws")
frame nwergm_bayes_draws: quietly count
_chk "frame has one row per draw" (r(N) == e(ndraws))
frame nwergm_bayes_draws: quietly summarize b1
_chk "frame mean equals e(b)" (abs(r(mean) - e(b)[1,1]) < 1e-9)

* custom frame, no frame
quietly nwergm flomarriage, edges triangle estimate(bayes) seed(2) iterations(100) frame(myfr)
frame myfr: quietly count
_chk "frame() names the frame" (r(N) == e(ndraws) & "`e(post_frame)'" == "myfr")
frame drop myfr
quietly nwergm flomarriage, edges triangle estimate(bayes) seed(2) iterations(100) nodraws
_chk "nodraws: no frame named" ("`e(post_frame)'" == "")
quietly nwergm flomarriage, edges triangle estimate(bayes) seed(2) iterations(1000) burnin(200)

* offsets are held and not sampled
quietly nwergm flomarriage, edges triangle estimate(bayes) seed(2) iterations(200) offset(triangle -0.2)
_chk "offset: fixed value, zero sd" (e(b)[1,2] == -0.2 & e(sd)[1,2] == 0 & e(V)[2,2] == 0)

* replay and posterior summaries at another level
quietly nwergm flomarriage, edges triangle estimate(bayes) seed(2) iterations(1000) burnin(200)
local l95 = e(ci)[1,1]
nwergm
nwergm, level(90)
_chk "replay at level(90): narrower interval" (e(ci)[1,1] > `l95' & e(level) == 90)
quietly nwergm flomarriage, edges triangle estimate(bayes) seed(2) iterations(1000) burnin(200)

* estat posterior, estat mcmcdiag
tempfile dr
estat posterior, saving(`"`dr'"') replace plot(both) name(tb_post)
graph drop tb_post
_chk "estat posterior returns the summaries" (colsof(r(mean)) == 2 & colsof(r(median)) == 2 & colsof(r(ci)) == 2)
preserve
use `"`dr'"', clear
quietly count
_chk "saved draws: one row per draw" (r(N) == 4 * 1000)
confirm variable edges triangle chain iter
restore
estat mcmcdiag, plot name(tb_diag)
graph drop tb_diag
_chk "estat mcmcdiag: ESS and R-hat returned" (colsof(r(ess)) == 2 & colsof(r(rhat)) == 2 & rowsof(r(geweke)) == 2)

* estat gof: posterior predictive check
estat gof, nsim(20) gof(degree) seed(1)
_chk "estat gof after a Bayesian fit" (r(nsim) == 20 & r(burnin) == 10000)
estat gof, nsim(20) gof(degree espartners) gofburnin(500) seed(1)
_chk "estat gof: shortened burn-in" (r(burnin) == 500)

* the data and the fitted model are untouched by the sampler
quietly nwergm flomarriage, edges triangle estimate(bayes) seed(2) iterations(100)
quietly nwergm flomarriage, edges triangle seed(2)
_chk "an MCMLE fit after a Bayesian fit" ("`e(method)'" == "mcmle")
quietly nwergm flomarriage, edges triangle estimate(bayes) seed(2) iterations(100)
nwergm simulate 16, edges triangle theta(-1.6 -0.2) nsim(2) generate(tb_sim) seed(1)
_chk "simulation after a Bayesian fit" (1)
nwclear
nwwebuse florentine, nwclear
nwset
quietly nwergm flomarriage, edges triangle estimate(bayes) seed(2) iterations(100)
capture estat ic
_chk "estat ic refused after a Bayesian fit" (_rc == 498)

* ---- 4. recovery on simulated networks: coverage of the 95% credible intervals, bias
local cover = 0
local tot = 0
local bias1 = 0
local bias2 = 0
local R = 16
forvalues r = 1/`R' {
	nwclear
	set seed `=900 + `r''
	quietly nwergm simulate 30, edges mutual directed theta(-2.5 1.0) nsim(1) generate(rsim) mcmcburnin(20000) mcmcinterval(1000)
	quietly nwergm rsim, edges mutual estimate(bayes) seed(`r') burnin(100) iterations(1500)
	local ++tot
	local bias1 = `bias1' + (e(b)[1,1] + 2.5)
	local bias2 = `bias2' + (e(b)[1,2] - 1.0)
	if e(ci)[1,1] < -2.5 & e(ci)[2,1] > -2.5 & e(ci)[1,2] < 1.0 & e(ci)[2,2] > 1.0 local ++cover
}
display "recovery: both intervals cover the truth in `cover' of `tot' networks; mean bias " %6.3f `bias1'/`tot' " " %6.3f `bias2'/`tot'
_chk "recovery: coverage" (`cover' >= 12)
_chk "recovery: mean bias small" (abs(`bias1'/`tot') < 0.15 & abs(`bias2'/`tot') < 0.25)

* ---- 5. error paths
nwclear
nwwebuse florentine, nwclear
nwset
capture nwergm flomarriage, edges triangle estimate(bayes) chains(2)
_chk "chains(2) refused" (_rc == 198)
capture nwergm flomarriage, edges triangle estimate(bayes) iterations(10) thin(20)
_chk "thin() above iterations() refused" (_rc == 198)
capture nwergm flomarriage, edges triangle estimate(bayes) targetaccept(1.5)
_chk "targetaccept() out of range refused" (_rc == 198)
capture nwergm flomarriage, edges triangle estimate(bayes) priorvar(1 2 3)
_chk "priorvar() of the wrong length refused" (_rc == 198)
capture nwergm flomarriage, edges triangle estimate(bayes) priormean(1 2 3)
_chk "priormean() of the wrong length refused" (_rc == 198)
capture nwergm flomarriage, edges triangle estimate(bayes) priorvar(-1)
_chk "negative prior variance refused" (_rc != 0)
capture nwergm flomarriage, edges triangle estimate(bayes) priordecay(0 -1)
_chk "priordecay() with a negative sd refused" (_rc == 198)
capture nwergm flomarriage, edges triangle chains(4)
_chk "Bayesian options without estimate(bayes) refused" (_rc == 198)
capture nwergm flomarriage, edges triangle estimate(bayes) method(mple)
_chk "estimate(bayes) and method(mple) contradict" (_rc == 198)
capture nwergm flomarriage, edges triangle estimate(bayes) init(-1 0)
_chk "init() with estimate(bayes) refused" (_rc == 198)
capture nwergm flomarriage, edges triangle estimate(bayes) fixdensity
_chk "fixdensity with estimate(bayes) refused" (_rc == 198)
capture nwergm flomarriage, edges triangle estimate(bayes) nonative
_chk "nonative with estimate(bayes) refused" (_rc == 198)
capture nwergm flomarriage, edges triangle estimate(bayes) mainmethod(sa)
_chk "mainmethod() with estimate(bayes) refused" (_rc == 198)
matrix PC = (1, 0, 0 \ 0, 1, 0)
capture nwergm flomarriage, edges triangle estimate(bayes) priorcov(PC)
_chk "priorcov() that is not square refused" (_rc != 0)
matrix PC = (1, 2 \ 2, 1)
capture nwergm flomarriage, edges triangle estimate(bayes) priorcov(PC) iterations(50)
_chk "priorcov() that is not positive definite refused" (_rc != 0)
capture nwergm flomarriage, edges gwdegree(0.5) estimate(bayes) iterations(50)
_chk "fixed-decay gwdegree fits" (_rc == 0)
* estat after another kind of fit
quietly nwergm flomarriage, edges triangle seed(1)
capture estat posterior
_chk "estat posterior needs a Bayesian fit" (_rc == 301)

* ---- a full covariance prior and a non-default prior move the posterior in the expected direction
matrix PC = (4, 0 \ 0, 4)
quietly nwergm flomarriage, edges triangle estimate(bayes) seed(9) iterations(4000) priorcov(PC) priormean(-3 2)
local mtri = e(b)[1,2]
quietly nwergm flomarriage, edges triangle estimate(bayes) seed(9) iterations(4000)
_chk "informative prior mean pulls the triangle coefficient up" (`mtri' > e(b)[1,2] + 0.1)

display "ALL OK: test_nwergm_bayes"

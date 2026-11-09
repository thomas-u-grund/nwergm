* =====================================================================
* gen_logs.do: regenerates every log and figure of the nwergm article
* from the RELEASED software: nwcommands (core) 3.17.2 and nwergm 1.5.4.
* Run from the paper folder with Stata 18 (the Mata libraries are built with Stata 17):
*   /Applications/Stata/StataBE.app/Contents/MacOS/StataBE -e do gen_logs.do
* hdr_local.do (this folder) uses the installed packages, or source trees named by globals
* (see the comments in hdr_local.do). sjlog (Stata Journal) must be installed.
* =====================================================================
do "hdr_local.do"
set linesize 80
set scheme stsj
nwergm version

* ---------------------------------------------------------------------
* Example 1: the Florentine marriage network (16 families)
* ---------------------------------------------------------------------
sjlog using flo_edges, replace
nwwebuse florentine, nwclear
nwergm flomarriage, edges
sjlog close, replace

sjlog using flo_nodecov, replace
nwergm flomarriage, edges nodecov(wealth)
sjlog close, replace

sjlog using flo_gwesp, replace
nwergm flomarriage, edges nodecov(wealth) gwesp(.5) seed(2026)
sjlog close, replace

sjlog using flo_constr, replace
nwergm flomarriage, edges nodecov(wealth) triangle constraints(edges) seed(2026)
sjlog close, replace

sjlog using flo_methods, replace
quietly nwergm flomarriage, edges nodecov(wealth) triangle seed(2026)
estimates store mcmle
quietly nwergm flomarriage, edges nodecov(wealth) triangle mainmethod(sa) seed(2026)
estimates store sa
quietly nwergm flomarriage, edges nodecov(wealth) triangle estimate(cd) seed(2026)
estimates store cd
quietly nwergm flomarriage, edges nodecov(wealth) triangle estimate(mple)
estimates store mple
estimates table mple mcmle sa cd, b(%8.3f) se(%8.3f)
sjlog close, replace

sjlog using flo_missing, replace
nwtomata flomarriage, mat(A)
mata: A[1,2] = A[2,1] = A[3,5] = A[5,3] = .
mata: st_matrix("M", A)
nwset, mat(M) undirected name(flo_na)
nwergm flo_na, edges nodecov(wealth)
display "informative dyads: " e(N) "   missing dyads: " e(nmissing)
sjlog close, replace

* a valued network is fitted as the binary graph in which a tie is present when its value is not zero
sjlog using flo_valued, replace
nwtomata flomarriage, mat(A)
mata: V = A :* (1 :+ mod((1::16)*J(1,16,1) + J(16,1,1)*(1..16), 3))
mata: st_matrix("V", V)
nwset, mat(V) undirected name(flo_val)
nwsummarize flo_val
nwergm flo_val, edges nodecov(wealth)
sjlog close, replace

* ---------------------------------------------------------------------
* Example 2: the Lazega law firm, advice network (directed, covariates)
* ---------------------------------------------------------------------
sjlog using lazega_load, replace
nwwebuse lazega, nwclear
nwsummarize lazega_adv
foreach v in office practice status {
    encode `v', generate(`v'n)
}
nwdyads lazega_adv
sjlog close, replace

sjlog using lazega_m1, replace
nwergm lazega_adv, edges nodematch(officen practicen) nodeofactor(statusn) nodeifactor(statusn)
estimates store m1
sjlog close, replace

quietly nwergm lazega_adv, edges mutual nodematch(officen practicen) nodeofactor(statusn) nodeifactor(statusn) seed(12345)
estimates store m2

timer clear 1
timer on 1
sjlog using lazega_m3, replace
nwergm lazega_adv, edges mutual nodematch(officen practicen) nodeofactor(statusn) nodeifactor(statusn) gwesp(.5) seed(12345)
estimates store m3
sjlog close, replace
timer off 1
quietly timer list 1
display "LAZEGA_M3_SECONDS " r(t1)

* effective sample size: the fixed-size algorithm of nwergm 1.2.3 (mcmleeffectivesize(0)) against the default that follows ergm
sjlog using lazega_ess, replace
quietly nwergm lazega_adv, edges mutual nodematch(officen practicen) nodeofactor(statusn) nodeifactor(statusn) gwesp(.5) seed(12345) mcmleeffectivesize(0)
quietly estat mcmcdiag
matrix ess_old = r(ess)
quietly nwergm lazega_adv, edges mutual nodematch(officen practicen) nodeofactor(statusn) nodeifactor(statusn) gwesp(.5) seed(12345)
quietly estat mcmcdiag
matrix ess_new = r(ess)
matrix E = ess_old \ ess_new
matrix rownames E = "fixed" "adaptive"
matrix colnames E = edges mutual office practice partner_out partner_in gwesp
matrix list E, format(%7.1f) noheader
sjlog close, replace

* the final fit is the active estimation result again
quietly nwergm lazega_adv, edges mutual nodematch(officen practicen) nodeofactor(statusn) nodeifactor(statusn) gwesp(.5) seed(12345)
sjlog using lazega_diag, replace
estat mcmcdiag
sjlog close, replace
estat mcmcdiag, plot name(fig_mcmcdiag)
graph display fig_mcmcdiag, xsize(7) ysize(10)
graph export fig_mcmcdiag.pdf, replace name(fig_mcmcdiag)

sjlog using lazega_ic, replace
estimates stats m1 m2 m3
lrtest m2 m3
sjlog close, replace

sjlog using lazega_gof, replace
estat gof, gof(model distance) seed(12345)
sjlog close, replace
estat gof, gof(odegree idegree distance) seed(12345) plot name(fig_gof)
graph export fig_gof.pdf, replace name(fig_gof)

sjlog using lazega_sim, replace
nwergm simulate, nsim(100) output(stats) seed(12345)
matrix S = r(stats)
preserve
clear
set obs 100
svmat double S, names(s)
summarize s1-s7
restore
sjlog close, replace

* ---------------------------------------------------------------------
* Example 3: a two-mode network, Davis's southern women (18 women, 14 events)
* ---------------------------------------------------------------------
nwwebuse davis, nwclear
encode title, generate(titlen)
nwergm davis, edges bfactor1(titlen)
estimates store d1
nwergm davis, edges bfactor1(titlen) bgwdegree2(1) seed(1)
estimates store d2
sjlog using davis_fit, replace
nwergm davis, edges bfactor1(titlen) bgwdsp1(.5) seed(1)
estimates store d3
estimates stats d1 d2 d3
sjlog close, replace

sjlog using davis_gof, replace
estat gof, seed(1)
sjlog close, replace

* ---------------------------------------------------------------------
* Example 4: curved terms and operators
* ---------------------------------------------------------------------
sjlog using mesa_curved, replace
nwwebuse mesa, nwclear
encode race, generate(racen)
nwergm mesa, edges nodematch(grade racen) gwespfree(.25) seed(1)
sjlog close, replace

sjlog using lazega_sym, replace
nwwebuse lazega, nwclear
foreach v in office practice status {
    encode `v', generate(`v'n)
}
nwergm lazega_fr, edges mutual nodematch(practicen) operators(Symmetrize(triangle, rule(strong))) seed(1)
sjlog close, replace

* ---------------------------------------------------------------------
* Example 5: simulating from given coefficients
* ---------------------------------------------------------------------
sjlog using sim_demo, replace
nwergm simulate 16, edges gwesp(.5) theta(-2 .5) seed(42) nsim(3)
nwsummarize ergmsim_1
sjlog close, replace

display "=== Article reproduction complete ==="

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

* estat gof after a two-mode fit showed the observed value 0 for the mode-specific terms of the model-statistics
* block (the graph that holds the observed network was not marked two-mode).  Reference: the observed statistics
* are those of the data (R: summary(nw ~ ...), gof(fit, GOF = ~model).model).
nwclear
clear
mata: rseed(13); B = runiform(8,10) :< 0.3; st_matrix("Bbip", B)
nwset, mat(Bbip) bipartite name(bip) nooutput
qui nwergm bip, edges bdegree1(1) bdegree2(2) bgwdegree2(0.5) mcmcsamplesize(300) mcmcburnin(500) mcmcinterval(20) mcmleiterations(3) seed(1)
qui estat gof, gof(model) nsim(10)
matrix G = r(gof_model)
* expected values from the 8 x 10 incidence matrix (columns = mode 1)
mata: B = st_matrix("Bbip"); d1 = colsum(B)'; d2 = rowsum(B); n1 = cols(B); ///
	st_numscalar("e_edges", sum(B)); st_numscalar("e_b1", sum(d1 :== 1)); st_numscalar("e_b2", sum(d2 :== 2)); ///
	w = 0; for (i = 1; i <= n1; i++) w = w + (1 - (1 - exp(-0.5))^i) * sum(d2 :== i); ///
	st_numscalar("e_gw", exp(0.5) * w)
assert G[1,1] == e_edges
assert G[2,1] == e_b1
assert G[3,1] == e_b2
assert e_b1 > 0 & e_b2 > 0
assert abs(G[4,1] - e_gw) < 1e-6
assert G[4,1] > 0
di "PASS test_nwergm_gofmodelbip"

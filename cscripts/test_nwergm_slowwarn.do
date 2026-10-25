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

* The Mata fallback is far slower than the plugin, so a run without the plugin prints one warning line before the long
* computation; a run with the plugin must not print it.  The output is captured with log text.
nwclear
clear
mata: rseed(4); n = 20; R = runiform(n,n) :< 0.15; R = R :* (1 :- I(n)); R = ((R + R') :> 0); st_matrix("A", R)
nwset, mat(A) undirected name(un) nooutput
local o mcmcsamplesize(100) mcmcburnin(200) mcmcinterval(10) mcmleiterations(2) seed(1)
* with the plugin: no warning
tempfile l1 l2
log using `l1', text replace name(w1)
nwergm un, edges triangle `o'
estat gof, nsim(5)
log close w1
* option nonative: the warning appears once for the fit, and again for estat gof
log using `l2', text replace name(w2)
nwergm un, edges triangle nonative `o'
estat gof, nsim(5)
log close w2
mata: f1 = cat(st_local("l1")); f2 = cat(st_local("l2")); st_numscalar("n1", sum(strpos(f1, "compiled plugin is not used") :> 0)); st_numscalar("n2", sum(strpos(f2, "compiled plugin is not used") :> 0)); st_numscalar("nn", sum(strpos(f2, "option nonative") :> 0))
assert scalar(n1) == 0
assert scalar(n2) == 2
assert scalar(nn) == 1
di "PASS test_nwergm_slowwarn"

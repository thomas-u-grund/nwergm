cscript

* The help files must not say that degree and egocentric constraints are unsupported (constraints() has them), and the
* author's affiliation is RWTH Aachen University everywhere.
local nwcore : env NWCORE
adopath ++ `"`nwcore'"'
adopath ++ `"`c(pwd)'"'
quietly do `"`nwcore'/unw_core.do"'
do unw_ergm.do
local files : dir "." files "*.sthlp"
local files `"`files' nwergm.pkg CITATION.cff README.md NOTICE.md"'
mata: L = J(0, 1, ""); fl = tokens(st_local("files")); for (i = 1; i <= cols(fl); i++) L = L \ cat(fl[i])
mata: L = strlower(L)
mata: assert(sum(strpos(L, "dublin") :> 0) == 0)
mata: assert(sum((strpos(L, "egocentric") :> 0) :& (strpos(L, "not yet") :> 0)) == 0)
mata: assert(sum((strpos(L, "degree constraints") :> 0) :& (strpos(L, "not yet") :> 0)) == 0)
mata: assert(sum(strpos(L, "roadmap items, not yet supported") :> 0) == 0)
* and the options really run
nwclear
clear
mata: rseed(4); n = 20; R = runiform(n,n) :< 0.15; R = R :* (1 :- I(n)); R = ((R + R') :> 0); st_matrix("A", R)
nwset, mat(A) undirected name(un) nooutput
qui nwergm un, edges triangle constraints(degrees) mcmcsamplesize(100) mcmcburnin(200) mcmcinterval(10) mcmleiterations(2) seed(1)
assert "`e(constraints)'" != ""
di "PASS test_nwergm_helptext"

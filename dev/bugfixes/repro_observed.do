* header: sysdir PLUS scratch, adopath this repo + lib/plugins/macos + core, then do unw_ergm.do; see cscripts/test_nwergm_obsbdeg.do for the two-mode data
local d "/Users/tgrund/FILES_NEW/SOFTWARE/nwergm_fix/dev/ergm_missing"
import delimited using "`d'/u_adj.csv", clear varnames(nonames)
mkmat v*, matrix(A)
nwclear
nwset, mat(A) undirected name(un)
mata: A0 = st_matrix("A"); A0 = editmissing(A0, 0); st_matrix("A0", A0)
nwset, mat(A0) undirected name(comp) nooutput
local o mcmcsamplesize(1000) mcmcburnin(2000) mcmcinterval(50) mcmleiterations(10) seed(1)
capture noisily nwergm un, edges triangle constraints(observed) `o'
nwergm un, edges triangle obsconstraints(observed) `o'
nwergm comp, edges triangle constraints(observed) `o'
nwergm comp, edges triangle obsconstraints(observed) `o'
nwergm comp, edges triangle `o'

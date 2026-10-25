do dev/bugfixes2/pre.do
local nwcore "/Users/tgrund/FILES_NEW/SOFTWARE/nwcommands_main"
adopath ++ `"`nwcore'"'
quietly do `"`nwcore'/unw_core.do"'
do unw_ergm.do
nwclear
clear
mata: rseed(13); B = runiform(8,10) :< 0.3; st_matrix("Bbip", B)
nwset, mat(Bbip) bipartite name(bip) nooutput
qui nwergm bip, edges bdegree1(1) mcmcsamplesize(300) mcmcburnin(500) mcmcinterval(20) mcmleiterations(3) seed(1)
nwergm simulate, output(network) nsim(3) generate(sm) seed(5)
nwset
nwsummarize sm_1

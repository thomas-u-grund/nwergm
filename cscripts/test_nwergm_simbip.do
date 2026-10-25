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

* nwergm simulate from a two-mode fit with output(network) created one-mode undirected networks; R's simulate()
* returns a bipartite network.  Check mode sizes, the tie count against the statistics and ties only between modes.
nwclear
clear
mata: rseed(13); B = runiform(8,10) :< 0.3; st_matrix("Bbip", B)
nwset, mat(Bbip) bipartite name(bip) nooutput
qui nwergm bip, edges bdegree1(1) mcmcsamplesize(300) mcmcburnin(500) mcmcinterval(20) mcmleiterations(3) seed(1)
nwergm simulate, output(network) nsim(3) generate(sm) seed(5)
matrix S = r(stats)
forvalues s = 1/3 {
	qui nwsummarize sm_`s'
	assert "`r(mode2)'" == "true"
	assert r(nodes) == 18 & r(nodes1) == 10 & r(nodes2) == 8
	local ne = r(edges)
	assert r(edges) == S[`s',1]
	assert "`r(directed)'" == "false"
	* every tie joins a first-mode node (1..10) to a second-mode node (11..18)
	qui nwtomata sm_`s', mat(__sm)
	mata: assert(rows(__sm) == 18 & cols(__sm) == 18); assert(sum(__sm[1::10,1::10]) == 0 & sum(__sm[11::18,11::18]) == 0); assert(sum(__sm) == 2 * `ne')
}
di "PASS test_nwergm_simbip"

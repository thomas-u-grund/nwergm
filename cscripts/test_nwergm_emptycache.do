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
* The statistics of a network of 500 or more nodes come from the plugin plus the statistics of the empty network,
* which are kept on the model after the first call. They must equal the Mata statistics on the first and later
* calls, after the network changes and for a network of a different size.
set seed 4021
mata: B = (runiform(200, 400) :< 0.01)
nwset, mat(B) bipartite name(bipbig) nooutput
clear
set obs 600
gen g = ceil(3*runiform())
nwergm bipbig, edges bdsp1(0 1 2) bdsp2(1 2) bnodematch1(g) method(mple)
mata:
void _ec_check(string scalar what, class ErgmModel scalar M, class ErgmGraph scalar G)
{
	real rowvector a, b
	st_global("NWERGM_MATASTAT", "")
	a = ergm_full_stat(M, G)
	b = M.full_statistic(G)
	if (cols(a) != cols(b) | max(abs(a - b)) > 0) {
		printf("{err}FAIL %s\n", what)
		a
		b
		exit(9)
	}
	printf("ok %s: %s\n", what, invtokens(strofreal(a)))
}
_ec_check("first call", __nwergm_last_M, __nwergm_last_G)
if (cols(__nwergm_last_M.empty_stat) != __nwergm_last_M.nparam()) exit(9)
_ec_check("second call", __nwergm_last_M, __nwergm_last_G)
__nwergm_last_G.toggle(__nwergm_last_G.mode1nodes[1], __nwergm_last_G.mode2nodes[1])
__nwergm_last_G.toggle(__nwergm_last_G.mode1nodes[5], __nwergm_last_G.mode2nodes[7])
_ec_check("after two toggles", __nwergm_last_M, __nwergm_last_G)
end
* a model kept for one network size must not reuse its empty statistics for another
mata: __ec_save = __nwergm_last_M.empty_key
mata: __nwergm_last_M.empty_key[1] = 999
mata: _ec_check("stale key", __nwergm_last_M, __nwergm_last_G)
mata: assert(__nwergm_last_M.empty_key == __ec_save)
di "ALL OK"

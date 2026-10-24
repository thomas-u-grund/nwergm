clear all
set more off
adopath ++ "."
adopath ++ "lib/plugins/macos"
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
foreach nm in und_a dir_a {
	local d = cond("`nm'"=="dir_a","directed","undirected")
	import delimited "dev/E3/`nm'_adj.csv", clear
	qui mkmat v*, mat(A)
	import delimited "dev/E3/`nm'_x.csv", clear
	qui mkmat v*, mat(X)
	qui nwclear
	qui clear
	qui nwset, mat(X) undirected name(xnet)
	qui nwset, mat(A) `d' name(g)
	qui nwergm g, edges structural(localtriangle(x=xnet)) method(mple)
	mata: __nwergm_last_M.full_statistic(__nwergm_last_G)
}

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
qui nwergm simulate 30, edges structural(m2star) directed theta(-2.5 -0.05) nsim(2) mcmcburnin(2000) mcmcinterval(50) generate(ssim) seed(5)
nwsummarize ssim_1
nwergm ssim_1, edges structural(m2star) seed(3)
estat gof, nsim(5)

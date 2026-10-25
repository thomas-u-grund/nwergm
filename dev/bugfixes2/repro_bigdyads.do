* usage: stata -e do dev/bugfixes2/repro_bigdyads.do   with global NBIG set via a wrapper (default 5000)
do dev/bugfixes2/pre.do
local nwcore "/Users/tgrund/FILES_NEW/SOFTWARE/nwcommands_main"
adopath ++ `"`nwcore'"'
adopath ++ `"`c(pwd)'"'
quietly do `"`nwcore'/unw_core.do"'
do unw_ergm.do
if "$NBIG" == "" global NBIG 5000
nwclear
clear
set seed 20261025
mata: n = $NBIG; m = round(3 * n); i = ceil(runiform(m, 1) * n); j = ceil(runiform(m, 1) * n); k = selectindex(i :< j); E = i[k], j[k]; E = uniqrows(E); st_matrix("EE", E)
svmat double EE, names(e)
drop if missing(e1)
nwfromedge e1 e2, undirected name(rnet)
clear
timer on 1
capture noisily nwergm rnet, edges gwesp(0.5) mcmcsamplesize(100) mcmcburnin(1000) mcmcinterval(100) mcmleiterations(1) seed(1)
local rc = _rc
timer off 1
timer list 1
di "RESULT n=$NBIG rc=`rc' native=" e(native)

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

* nwergm simulate N with node attributes made by set obs, after an earlier fit (up to 1.7.1 it stopped with r(198)
* "observation numbers out of range": the check for missing attribute values read the number of nodes of the graph
* of the earlier fit, 71 here, instead of the 8 of the simulation)

* 1. a fit on 71 nodes, then a simulation on 8 nodes with node attributes made by set obs
nwuse `"`nwcore'/data/lazega"', nwclear
quietly nwergm lazega_adv, edges nodematch(office) seed(1)
nwclear
clear
set obs 8
gen x = _n / 8
gen byte g = mod(_n, 2)
nwergm simulate 8, edges nodecov(x) nodematch(g) theta(-1 .5 .5) nsim(2) generate(s) seed(5)
assert _N == 8 & x == _n / 8
nwsummarize s_1
assert r(nodes) == 8
nwtomata s_1, mat(A1)
di "PASS a simulation on 8 nodes after a fit on 71 nodes"

* 2. the same seed gives the same draws (after the fit and in a fresh session state)
nwergm simulate 8, edges nodecov(x) nodematch(g) theta(-1 .5 .5) nsim(2) generate(t) seed(5)
nwtomata t_1, mat(A2)
mata: assert(A1 == A2)
di "PASS the same seed gives the same draws"

* 3. a simulation on 5 nodes, then one on 12 nodes with a missing attribute value in row 12: the check reads all 12
* rows (it read the 5 nodes of the earlier graph, so the missing value was not seen)
nwclear
clear
set obs 5
gen x = _n
nwergm simulate 5, edges nodecov(x) theta(-1 .1) nsim(1) generate(a) seed(1)
clear
set obs 12
gen x = _n
replace x = . in 12
rcof "nwergm simulate 12, edges nodecov(x) theta(-1 .1) nsim(1) generate(m) seed(1)" == 416
di "PASS a missing attribute value in a row beyond the earlier graph is refused"

* 4. fewer rows than nodes: a clear message (r(198))
nwclear
clear
set obs 6
gen x = _n
rcof "nwergm simulate 8, edges nodecov(x) theta(-1 .1) nsim(1) generate(f) seed(1)" == 198
di "PASS fewer rows than nodes is refused"

di "ALL TESTS PASSED"

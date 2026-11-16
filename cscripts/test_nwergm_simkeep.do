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

* nwergm simulate keeps the data in memory when the draws are on its nodes (up to 1.7.1 simulate with a number of
* nodes replaced it by the node data of the draws: after a simulation with basis() only _nwnode and _nwinclude
* were left). Another number of nodes replaces the data as before.

* 1. no network in memory, the node attributes made with set obs: they stay
clear
set obs 40
gen grp = ceil(_n / 10)
nwergm simulate 40, edges nodematch(grp) theta(-3 1.5) directed seed(7) generate(art)
assert _N == 40 & grp == ceil(_n / 10)
nwsummarize art
assert r(nodes) == 40
di "PASS simulate N with set obs data: the attributes stay"

* 2. basis(): all variables and the order of the rows stay; the draws keep the degrees and the names
nwuse `"`nwcore'/data/lazega"', nwclear
local k0 = c(k)
gen long __row = _n
tempfile before
qui save `before'
nwergm simulate 71, edges theta(0) basis(lazega_adv) constraints(degrees) directed nsim(3) generate(deg) seed(12345)
assert c(k) == `k0' + 1 & _N == 71
confirm string variable status
assert __row == _n
cf _all using `before'
qui nwdegree lazega_adv, generate(od id)
forvalues s = 1/3 {
	qui nwdegree deg_`s', generate(od`s' id`s')
	assert od == od`s' & id == id`s'
	_nwsyntax deg_`s'
	mata: st_local("nm", invtokens((`netobj'->get_nodenames())))
	mata: st_local("rw", invtokens(st_sdata(., "_nwnode")'))
	assert "`nm'" == "`rw'"
}
* the same seed gives the same draws
nwtomata deg_1, mat(A1)
nwergm simulate 71, edges theta(0) basis(lazega_adv) constraints(degrees) directed nsim(1) generate(again) seed(12345)
nwtomata again, mat(A2)
mata: assert(A1 == A2)
* a model with a node attribute on the kept data
nwergm deg_1, edges nodematch(status) mutual seed(1)
di "PASS simulate N with basis(): the data stays (variables, order), the draws keep degrees and names"

* 3. inside the user's own preserve/restore (as earlier versions needed)
nwdrop deg_*
local k1 = c(k)
preserve
nwergm simulate 71, edges theta(0) basis(lazega_adv) constraints(degrees) directed nsim(2) generate(deg) seed(12345)
assert c(k) == `k1'
restore
assert c(k) == `k1'
nwdegree deg_1, generate(pod pid)
assert od == pod & id == pid
di "PASS simulate within preserve/restore"

* 4. without basis(), networks in memory on the same nodes: the data stays, the draws are named after the rows
nwergm simulate 71, edges nodematch(officenum) theta(-3 1) directed generate(nb) seed(5)
assert _N == 71
confirm variable status officenum
_nwsyntax nb
mata: st_local("nm", invtokens((`netobj'->get_nodenames())))
mata: st_local("rw", invtokens(st_sdata(., "_nwnode")'))
assert "`nm'" == "`rw'"
di "PASS simulate N without basis() on the nodes of the data"

* 5. another number of nodes: the data is replaced by the node data of the draws, as before
nwergm simulate 20, edges theta(-2) generate(small) seed(5)
assert _N == 20
capture confirm variable status
assert _rc
di "PASS simulate on another number of nodes replaces the data"

* 6. after a fit, output(network): the data stays
nwuse `"`nwcore'/data/lazega"', nwclear
local k0 = c(k)
nwergm lazega_adv, edges mutual seed(1)
nwergm simulate, nsim(2) output(network) seed(3)
assert c(k) == `k0' & _N == 71
confirm string variable status
di "PASS simulate after a fit keeps the data"
di "ALL TESTS PASSED"

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

* Simulated networks carry the node names of their starting network (bug up to 1.3.6). The lawyers' network
* stores its nodes as n1, n10, n11, ..., n19, n2, ...; the draws were named n1, n2, ..., n71 in that order, so
* the degrees of every lawyer but one were attached to another lawyer. After a fit, basis() was also ignored
* unless nosequential was given: the chain went on from the fit's last network.
nwuse `"`nwcore'/data/lazega"', nwclear

* 1. nwergm simulate N, theta() basis() constraints(degrees): every lawyer keeps the out- and in-degree
nwergm simulate 71, edges theta(0) basis(lazega_adv) constraints(degrees) directed nsim(3) generate(deg) seed(12345)
* (simulate with a number of nodes replaces the data in memory: the degrees are taken afterwards)
qui nwdegree lazega_adv, generate(od id)
forvalues s = 1/3 {
	qui nwdegree deg_`s', generate(od`s' id`s')
	assert od == od`s' & id == id`s'
}
di "PASS simulate N, basis() constraints(degrees): the degrees stay with the names"

* 2. after a fit, basis() is the start of the chain: one step from the basis changes at most one dyad
nwergm lazega_adv, edges mutual seed(1)
nwergm simulate, basis(lazega_adv) nsim(1) burnin(0) interval(1) seed(2) generate(s0)
qui nwdegree s0, generate(od0 id0)
gen dif = abs(od - od0) + abs(id - id0)
qui sum dif
assert r(sum) <= 2
qui nwcorrelate lazega_adv s0
assert r(corr) > .99
nwergm simulate, basis(lazega_adv) nsim(1) burnin(0) interval(1) seed(2) generate(s1) nosequential
qui nwcorrelate lazega_adv s1
assert r(corr) > .99
di "PASS simulate after a fit starts at basis(), with and without nosequential"

* 3. without basis() the draws have the names of the fitted network, in its order
nwergm simulate, nsim(1) seed(3) generate(s2)
_nwsyntax s2
mata: st_local("nm", invtokens((`netobj'->get_nodenames())[1..3]))
assert "`nm'" == "n1 n10 n11"
di "PASS simulate without basis(): names of the fitted network"

* 4. two-mode: the names of both modes
nwuse `"`nwcore'/data/davis"', nwclear
qui nwdegree davis, generate(dv) raw
nwergm davis, edges seed(1)
nwergm simulate, basis(davis) nsim(1) burnin(0) interval(1) seed(2) generate(b0)
qui nwdegree b0, generate(dv0) raw
gen dd = abs(dv - dv0)
qui sum dd
assert r(sum) <= 2
di "PASS two-mode simulate: names of both modes"

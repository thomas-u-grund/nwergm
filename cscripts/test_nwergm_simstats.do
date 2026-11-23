cscript

* nwergm simulate, output(stats): the statistics of the draws in a frame, without storing the draws as networks.
* The same seed gives the same draws as output(network), so the statistics must equal those counted on the stored networks.
local nwcore : env NWCORE
if `"`nwcore'"' == "" {
	di as error "set the environment variable NWCORE to the directory of the nwcommands (core) package"
	exit 198
}
adopath ++ `"`nwcore'"'
adopath ++ `"`c(pwd)'"'
quietly do `"`nwcore'/unw_core.do"'
do unw_ergm.do

* 1. directed edges + mutual, native sampler, with and without burn-in
foreach b in 0 200 {
	clear
	nwclear
	nwergm simulate 20, edges mutual theta(-2 0.8) directed nsim(15) mcmcburnin(`b') mcmcinterval(50) seed(11) generate(net)
	matrix S = J(15, 2, .)
	forvalues i = 1/15 {
		nwtomata net_`i', mat(A)
		mata: st_matrix("__row", (sum(A), sum(A :* A')/2))
		matrix S[`i', 1] = __row[1,1]
		matrix S[`i', 2] = __row[1,2]
	}
	nwclear
	nwergm simulate 20, edges mutual theta(-2 0.8) directed nsim(15) mcmcburnin(`b') mcmcinterval(50) seed(11) generate(st) output(stats)
	frame st {
		assert _N == 15
		confirm numeric variable edges mutual
		forvalues i = 1/15 {
			assert edges[`i'] == S[`i', 1] & mutual[`i'] == S[`i', 2]
		}
	}
	frame drop st
	* no network was stored
	local nn 0
	capture mata: st_local("nn", strofreal(__nw.nws.get_number()))
	assert real("`nn'") == 0
}
di as text "  PASS: stats equal the statistics of the stored networks"

* 2. an undirected model with a covariate and gwesp, and the Mata sampler
clear
set obs 30
gen grp = ceil(_n / 10)
nwergm simulate 30, edges nodematch(grp) gwesp(.5) theta(-3 .8 .4) nsim(6) mcmcburnin(100) mcmcinterval(20) seed(3) generate(m1) output(stats)
assert _N == 30 & grp == ceil(_n / 10)
frame m1: assert _N == 6 & c(k) == 3
nwergm simulate 30, edges nodematch(grp) gwesp(.5) theta(-3 .8 .4) nsim(6) mcmcburnin(100) mcmcinterval(20) seed(3) generate(m2) output(stats) nonative
frame m2: assert _N == 6
* an existing frame is replaced
nwergm simulate 30, edges nodematch(grp) gwesp(.5) theta(-3 .8 .4) nsim(4) mcmcburnin(100) mcmcinterval(20) seed(3) generate(m2) output(stats)
frame m2: assert _N == 4

* more draws than a Stata matrix can hold (c(max_matdim) is 800 in Stata/BE)
nwergm simulate 12, edges theta(-2) nsim(1000) mcmcburnin(0) mcmcinterval(1) seed(2) generate(big) output(stats)
frame big: assert _N == 1000 & !missing(edges)
di as text "  PASS: undirected, covariate, curved term, both samplers"

* 3. errors
capture nwergm simulate 10, edges theta(-2) nsim(2) output(foo)
assert _rc == 198
capture nwergm simulate 10, edges theta(-2) nsim(2) output(stats) generate(1bad)
assert _rc == 198
capture nwergm simulate 10, edges theta(-2) nsim(2) output(stats) generate(default)
assert _rc == 198
di as text "  PASS: errors"
di as text "ALL TESTS PASSED"

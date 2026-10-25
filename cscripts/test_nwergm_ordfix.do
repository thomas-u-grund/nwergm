cscript

* Regression test: results must not depend on the state of the random-number generator or on earlier calls that sort
* (Mata's sort() and order() break ties by that state), and the MPLE must not depend on the order of the nodes.
local nwcore : env NWCORE
if `"`nwcore'"' == "" {
	di as error "set the environment variable NWCORE to the directory of the nwcommands (core) package"
	exit 198
}
adopath ++ `"`nwcore'"'
adopath ++ `"`c(pwd)'"'
quietly do `"`nwcore'/unw_core.do"'
do unw_ergm.do
capture adopath ++ "lib/plugins/macos"
capture adopath ++ "lib/plugins/unix"
capture adopath ++ "lib/plugins/windows"

local model "edges mutual nodematch(prac) gwesp(0.5)"

nwwebuse lazega, nwclear
encode practice, generate(prac)

* A: MPLE under different seeds and after random sorts
nwergm lazega_fr, `model' method(mple)
matrix bref = e(b)
forvalues s = 1/4 {
	set seed `s'
	mata: junk = sort(round(runiform(500, 1) * 3), 1); junk = order(round(runiform(500, 1) * 3), 1)
	quietly nwergm lazega_fr, `model' method(mple)
	assert mreldif(e(b), bref) < 1e-10
}
di "PASS: MPLE is the same under 4 seeds"

* B: the MCMLE with seed() is the same whatever the generator did before
local opts "seed(1) mcmleiterations(2) mcmcsamplesize(500) nologlik"
set seed 99
quietly nwergm lazega_fr, `model' `opts'
matrix bm = e(b)
forvalues s = 1/3 {
	set seed `s'
	mata: junk = sort(round(runiform(1000, 1) * 3), 1); junk = order(round(runiform(1000, 1) * 3), 1)
	quietly nwergm lazega_fr, `model' `opts'
	assert mreldif(e(b), bm) < 1e-12
}
di "PASS: seeded MCMLE is the same whatever the generator did before"

* C: the MPLE is invariant to the order of the nodes
forvalues s = 1/3 {
	set seed `s'
	quietly nwpermute lazega_fr, generate(perm`s')
	quietly nwergm perm`s', edges mutual gwesp(0.5) method(mple)
	matrix bp`s' = e(b)
}
quietly nwergm lazega_fr, edges mutual gwesp(0.5) method(mple)
matrix b0 = e(b)
forvalues s = 1/3 {
	assert mreldif(bp`s', b0) < 1e-6
}
di "PASS: MPLE is invariant to the order of the nodes"
di "ALL TESTS PASSED"

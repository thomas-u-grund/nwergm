* Repeated nwergm simulate with the same generate() name replaces the draws and simulates the same model (bug in 1.15.2 and 1.16.0):
* the lookup of the stored draw name used to overwrite the local directed of nwergm simulate, so that every draw after the first of a repeated
* call was simulated as a directed network (about half as many edges, asymmetric matrices).

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

* 1. undirected, curved term: the draws of the second call equal those of the first (same seed) and are symmetric
forvalues call = 1/3 {
	nwergm simulate 40, edges gwesp(.5) theta(-3 .5) nsim(3) mcmcburnin(5000) mcmcinterval(200) seed(7) generate(rr)
	forvalues s = 1/3 {
		qui nwtomata rr_`s', mat(M`call'_`s')
		mata: st_numscalar("asym", sum(abs(M`call'_`s' - M`call'_`s''')))
		assert asym == 0
		if `call' > 1 {
			mata: st_numscalar("dif", sum(abs(M`call'_`s' - M1_`s')))
			assert dif == 0
		}
	}
}

* 2. fewer draws in the second call: draws 1 and 2 are replaced, draw 3 of the first call stays, and the draws are still undirected
nwergm simulate 40, edges gwesp(.5) theta(-3 .5) nsim(2) mcmcburnin(5000) mcmcinterval(200) seed(7) generate(rr)
forvalues s = 1/2 {
	qui nwtomata rr_`s', mat(N`s')
	mata: st_numscalar("asym", sum(abs(N`s' - N`s'')))
	assert asym == 0
	mata: st_numscalar("dif", sum(abs(N`s' - M1_`s')))
	assert dif == 0
}

* 3. a single draw, called twice with the same name
forvalues call = 1/2 {
	nwergm simulate 40, edges gwesp(.5) theta(-3 .5) nsim(1) mcmcburnin(5000) mcmcinterval(200) seed(9) generate(one)
	qui nwtomata one, mat(O`call')
	mata: st_numscalar("asym", sum(abs(O`call' - O`call'')))
	assert asym == 0
}
mata: st_numscalar("dif", sum(abs(O1 - O2)))
assert dif == 0

* 4. directed draws are replaced too (the directed flag is still set when it is asked for)
forvalues call = 1/2 {
	nwergm simulate 40, edges mutual theta(-3 .5) directed nsim(2) mcmcburnin(5000) mcmcinterval(200) seed(7) generate(dd)
	forvalues s = 1/2 {
		qui nwtomata dd_`s', mat(D`call'_`s')
	}
}
forvalues s = 1/2 {
	mata: st_numscalar("dif", sum(abs(D1_`s' - D2_`s')))
	assert dif == 0
}
mata: st_numscalar("asym", sum(abs(D1_1 - D1_1')))
assert asym > 0

di as text "  PASS: repeated generate() names replace the draws and keep the model undirected"

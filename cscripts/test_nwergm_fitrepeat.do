cscript

* Repeated fits in one Stata session must not get slower: the graph of the previous fit (and its backup copy) used to stay
* alive during the next fit and slowed down every later Mata statement (the second and later fits took about twice as long).
* Ten fits of the same model: the estimates are identical, the median time of fits 6 to 10 stays below 1.7 times the
* first fit, and a refused call after a fit leaves the graph of that fit in place. The fault that this guards against made
* every later fit about twice as slow as the first; the limit of 1.7 leaves room for the noise of timing (the ratio was 0.75 to 2.0
* on a busy machine and 1.3 to 1.4 alone in Stata 18 with the limit of 1.25 that failed on correct code). Expected runtime: about 25 seconds.
local nwcore : env NWCORE
if `"`nwcore'"' == "" {
	di as error "set the environment variable NWCORE to the directory of the nwcommands (core) package"
	exit 198
}
adopath ++ `"`nwcore'"'
adopath ++ `"`c(pwd)'"'
quietly do `"`nwcore'/unw_core.do"'
do unw_ergm.do

nwclear
clear
set seed 12345
local n 1000
capture mata: mata drop fitrepeat_mk()
mata:
void fitrepeat_mk(real scalar n, real scalar dens)
{
	real scalar i, j, k
	real colvector eg, al, va
	k = n*(n-1)
	eg = J(k,1,.); al = J(k,1,.); va = J(k,1,.)
	k = 0
	for (i=1; i<=n; i++) for (j=1; j<=n; j++) {
		if (i==j) continue
		k++
		eg[k] = i; al[k] = j; va[k] = (runiform(1,1) < dens)
	}
	st_addobs(k)
	st_addvar("double", ("ego","alter","value"))
	st_store(., ("ego","alter","value"), (eg,al,va))
}
end
mata: fitrepeat_mk(`n', 0.01)
nwset ego alter value, edgelist directed name(bnet)
quietly generate double grp = ceil(runiform()*3) in 1/`n'

forvalues r = 1/10 {
	timer clear 1
	timer on 1
	quietly nwergm bnet, edges mutual nodematch(grp) method(mple) seed(1)
	timer off 1
	quietly timer list 1
	local t`r' = r(t1)
	matrix b`r' = e(b)
	di "fit `r': " %6.3f `t`r'' " s"
}
* the estimates do not change between fits
forvalues r = 2/10 {
	assert mreldif(b1, b`r') < 1e-12
}
* median of fits 6 to 10
mata: st_local("med", strofreal(sort((`t6', `t7', `t8', `t9', `t10')', 1)[3]))
di "first fit " %6.3f `t1' ", median of fits 6-10 " %6.3f `med' ", ratio " %5.2f `med'/`t1'
assert `med' < 1.7 * `t1'

* a refused call leaves the graph of the last fit in place (and a later estat works)
mata: st_local("nt0", strofreal(__nwergm_last_G.nties))
capture nwergm bnet, edges nosuchterm(1) method(mple)
assert _rc != 0
mata: st_local("nt1", strofreal(__nwergm_last_G.nties))
assert `nt0' == `nt1'
mata: st_local("nn", strofreal(__nwergm_last_G.n))
assert `nn' == `n'
di "PASS test_nwergm_fitrepeat"

cscript

* Repeated fits in one Stata session must not get slower: the graph of the previous fit (and its backup copy) used to stay
* alive during the next fit and slowed down every later Mata statement (the second and later fits took about twice as long).
* Eight fits of the same model: the estimates are identical, the median time of fits 6 to 8 stays below 1.25 times the
* first fit (timing is noisy on a busy machine: the check uses the medians of three), and a refused call after a fit leaves
* the graph of that fit in place. Expected runtime: about 20 seconds.
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

forvalues r = 1/8 {
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
forvalues r = 2/8 {
	assert mreldif(b1, b`r') < 1e-12
}
* medians of fits 6 to 8
mata: st_local("med", strofreal(sort((`t6', `t7', `t8')', 1)[2]))
di "first fit " %6.3f `t1' ", median of fits 6-8 " %6.3f `med' ", ratio " %5.2f `med'/`t1'
assert `med' < 1.25 * `t1'

* a refused call leaves the graph of the last fit in place (and a later estat works)
mata: st_local("nt0", strofreal(__nwergm_last_G.nties))
capture nwergm bnet, edges nosuchterm(1) method(mple)
assert _rc != 0
mata: st_local("nt1", strofreal(__nwergm_last_G.nties))
assert `nt0' == `nt1'
mata: st_local("nn", strofreal(__nwergm_last_G.n))
assert `nn' == `n'
di "PASS test_nwergm_fitrepeat"

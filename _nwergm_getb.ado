*! version 1.15.1  22nov2026 _nwergm_getb.ado -- copy e(b) into a Stata matrix through Mata (works above c(max_matdim))
* Copy e(b) into a Stata matrix through Mata. `matrix X = e(b)' refuses a
* matrix wider than c(max_matdim) (800 in Stata/BE), although Mata can create
* it and ereturn post accepts it: a model with one coefficient per node
* (sender, receiver) on a network of more than about 400 nodes has more.
program _nwergm_getb
	version 14
	args name
	mata: st_matrix("`name'", st_matrix("e(b)"))
	mata: st_matrixcolstripe("`name'", st_matrixcolstripe("e(b)"))
	mata: st_matrixrowstripe("`name'", st_matrixrowstripe("e(b)"))
	// an egocentric fit (nwergm ego) reports the coefficient of edges for the population; the chain runs on the
	// pseudopopulation with the network size adjustment added to it
	if "`e(estimate)'" == "Ego" {
		local __cn : colnames e(b)
		local __k : list posof "edges" in __cn
		if `__k' > 0 matrix `name'[1, `__k'] = `name'[1, `__k'] + e(egoshift)
	}
end

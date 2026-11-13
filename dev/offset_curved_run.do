* Stata side of the offset() comparison for models with a curved term (see offset_curved_ref.R).
* usage: from the repository root, with NWCORE set and adopaths to the core, this tree, lib and lib/plugins/<platform>:
*   do dev/offset_curved_run.do   -> dev/offset_curved_stata.csv
set more off
tempname fh
file open `fh' using "dev/offset_curved_stata.csv", write replace
file write `fh' "case,est,seed,pos,term,coef,se,ll" _n
capture program drop oc_fit
program oc_fit
	args fh case est seed net opts
	if "`est'" == "mple" quietly nwergm `net', `opts' estimate(mple)
	else quietly nwergm `net', `opts' seed(`seed')
	local names : colnames e(b)
	local k = 0
	foreach t of local names {
		local ++k
		file write `fh' "`case',`est',`seed',`k',`t'," %21.15g (_b[`t']) "," %21.15g (sqrt(el(e(V), `k', `k'))) "," %21.15g (e(ll)) _n
	}
end
nwwebuse florentine, nwclear
local fA "edges gwespfree(0.5) offset(gwesp_weight 0.5 gwesp_decay 0.3)"
local fB "edges gwespfree(0.5) offset(gwesp_decay 0.3)"
local fC "edges gwespfree(0.5) offset(gwesp_weight 0.5)"
local fD "edges gwespfree(0.5) offset(edges -2)"
local fE "edges gwesp(0.5) offset(gwesp_0.5 0.5)"
foreach c in fA fB fC fD fE {
	oc_fit `fh' `c' mple 0 flomarriage "``c''"
}
foreach c in fA fB fE {
	forvalues s = 1/3 {
		oc_fit `fh' `c' mcmle `s' flomarriage "``c''"
	}
}
nwwebuse lazega, nwclear
local lB "edges mutual gwespfree(0.5) offset(gwesp_decay 0.5)"
local lA "edges mutual gwespfree(0.5) offset(gwesp_weight 0.8 gwesp_decay 0.5)"
local lD "edges mutual gwespfree(0.5) offset(mutual 2)"
local lC "edges mutual gwespfree(0.5) offset(mutual 2 gwesp_weight 0.8)"
foreach c in lB lA lD lC {
	oc_fit `fh' `c' mple 0 lazega_fr "``c''"
}
foreach c in lB lA {
	forvalues s = 1/3 {
		oc_fit `fh' `c' mcmle `s' lazega_fr "``c''"
	}
}
file close `fh'

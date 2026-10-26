*! version 1.2.4  26oct2026 _nwergm_coeflabel: rename coefficients (R's Label() operator)
* Copyright (C) 2026 Thomas U. Grund
* This file is part of nwergm, a Stata package derived from the R package 'ergm (statnet)' (Mark S. Handcock, David R. Hunter, Carter T. Butts, Steven M. Goodreau, Pavel N. Krivitsky, Martina Morris and contributors; GPL-3 (+ file LICENSE)).
* nwergm is free software: you can redistribute it and/or modify it under the terms of the GNU General
* Public License, version 3, as published by the Free Software Foundation. It is distributed in the hope
* that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
* or FITNESS FOR A PARTICULAR PURPOSE. See the file LICENSE for the full text.
capture program drop _nwergm_coeflabel
program _nwergm_coeflabel
	version 14
	local n : word count `0'
	if mod(`n', 2) {
		di "{err}option {bf:coeflabel()} needs oldname/newname pairs; got an odd number of words."
		error 198
	}
	forvalues k = 1(2)`n' {
		local old : word `k' of `0'
		local new : word `=`k'+1' of `0'
		capture confirm name `new'
		if _rc {
			di "{err}option {bf:coeflabel()}: {bf:`new'} is not a valid coefficient name."
			error 198
		}
		mata: st_local("__pos", strofreal(__nwergm_last_M.findcoef("`old'")))
		if `__pos' == 0 {
			di "{err}option {bf:coeflabel()}: `old' is not a coefficient name in this model."
			error 198
		}
		mata: __nwergm_last_M.coefnames[`__pos'] = "`new'"
	}
end


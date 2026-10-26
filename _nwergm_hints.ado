*! version 1.2.3  26oct2026 _nwergm_hints: validate nwergm's mcmcprop() (R ergm's control MCMC.prop hint formula)
* Copyright (C) 2026 Thomas U. Grund
* This file is part of nwergm, a Stata package derived from the R package 'ergm (statnet)' (Mark S. Handcock, David R. Hunter, Carter T. Butts, Steven M. Goodreau, Pavel N. Krivitsky, Martina Morris and contributors; GPL-3 (+ file LICENSE)).
* nwergm is free software: you can redistribute it and/or modify it under the terms of the GNU General
* Public License, version 3, as published by the Free Software Foundation. It is distributed in the hope
* that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
* or FITNESS FOR A PARTICULAR PURPOSE. See the file LICENSE for the full text.
capture program drop _nwergm_hints
program _nwergm_hints
	version 14
	syntax , SPEC(string asis)
	mata: _ergm_con_split(`"`spec'"')
	local unmet ""
	forvalues t = 1/`__cn' {
		local nm `__cnm`t''
		if !inlist("`nm'", "sparse", "TNT", "triadic", "strat", "Strat", ".triadic") {
			di as err "Sample space constraint '`nm'' not found."
			error 198
		}
		if inlist("`nm'", "triadic", "strat", "Strat", ".triadic") local unmet "`unmet' '`nm''"
	}
	if "`unmet'" != "" {
		di "{txt}Best valid proposal 'TNT' cannot take into account hint(s)`unmet'."
	}
end

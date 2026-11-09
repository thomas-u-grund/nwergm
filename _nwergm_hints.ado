*! version 1.5.4  09nov2026 _nwergm_hints: validate nwergm's mcmcprop() (R ergm's control MCMC.prop hint formula)
* Copyright (C) 2026 Thomas U. Grund
* This file is part of nwergm, a Stata package derived from the R package 'ergm (statnet)' (Mark S. Handcock, David R. Hunter, Carter T. Butts, Steven M. Goodreau, Pavel N. Krivitsky, Martina Morris and contributors; GPL-3 (+ file LICENSE)).
* nwergm is free software: you can redistribute it and/or modify it under the terms of the GNU General
* Public License, version 3, as published by the Free Software Foundation. It is distributed in the hope
* that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
* or FITNESS FOR A PARTICULAR PURPOSE. See the file LICENSE for the full text.
capture program drop _nwergm_hints
program _nwergm_hints
	version 14
	syntax [, SPEC(string asis)]
	// R's default MCMC.prop is ~sparse + .triadic: the SPDyad proposal (TNT mixed with a proposal of dyads that
	// have a shared partner, triFocus = 0.25). Returns in the caller: __spdfocus (triFocus, or -1 without a triadic
	// hint) and __spdstrict (1 for triadic(), which R refuses on a two-mode network; 0 for .triadic)
	if `"`spec'"' == "" {
		c_local __spdfocus 0.25
		c_local __spdstrict 0
		exit
	}
	mata: _ergm_con_split(`"`spec'"')
	local unmet ""
	local focus -1
	local strict 0
	forvalues t = 1/`__cn' {
		local nm `__cnm`t''
		if !inlist("`nm'", "sparse", "TNT", "triadic", "strat", "Strat", ".triadic") {
			di as err "Sample space constraint '`nm'' not found."
			error 198
		}
		if inlist("`nm'", "strat", "Strat") local unmet "`unmet' '`nm''"
		if inlist("`nm'", "triadic", ".triadic") {
			local focus 0.25
			if "`nm'" == "triadic" local strict 1
			local ar `"`__car`t''"'
			local ar : subinstr local ar "," " ", all
			local ar : subinstr local ar " =" "=", all
			local ar : subinstr local ar "= " "=", all
			local k 0
			foreach a of local ar {
				local ++k
				local a : subinstr local a `"""' "", all
				if strpos("`a'", "=") {
					gettoken key val : a, parse("=")
					local val : subinstr local val "=" ""
				}
				else {
					local key = cond(`k' == 1, "triFocus", "type")
					local val "`a'"
				}
				if "`key'" == "triFocus" {
					capture confirm number `val'
					if _rc | !inrange(real("`val'"), 0, 1) {
						di as err "triadic(): triFocus must be a number between 0 and 1."
						error 198
					}
					local focus `val'
				}
				else if "`key'" == "type" {
					if !inlist(upper("`val'"), "OTP", "UTP") {
						di as err "triadic(): nwergm implements the triadic proposal for shared partners of type OTP (the default; UTP on an undirected network) only."
						error 198
					}
				}
				else {
					di as err "triadic(): unknown argument `key'."
					error 198
				}
			}
		}
	}
	if "`unmet'" != "" {
		di "{txt}Best valid proposal '`=cond(`focus' >= 0, "SPDyad", "TNT")'' cannot take into account hint(s)`unmet'."
	}
	c_local __spdfocus `focus'
	c_local __spdstrict `strict'
end

*! version 1.3.5  28oct2026 _nwergm_constr: parse nwergm's constraints() / obsconstraints() formula (R ergm's sample-space constraints)
* Copyright (C) 2026 Thomas U. Grund
* This file is part of nwergm, a Stata package derived from the R package 'ergm (statnet)' (Mark S. Handcock, David R. Hunter, Carter T. Butts, Steven M. Goodreau, Pavel N. Krivitsky, Martina Morris and contributors; GPL-3 (+ file LICENSE)).
* nwergm is free software: you can redistribute it and/or modify it under the terms of the GNU General
* Public License, version 3, as published by the Free Software Foundation. It is distributed in the hope
* that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
* or FITNESS FOR A PARTICULAR PURPOSE. See the file LICENSE for the full text.
capture program drop _nwergm_constr
program _nwergm_constr
	version 14
	syntax , SPEC(string asis) NODES(integer) DIRECTED(string) TWOMODE(string) MATOBJ(string) [WEIGHTS(string) PREFIX(string)]
	if "`weights'" == "" local weights "default"
	local dir = ("`directed'" == "true")
	local bip = ("`twomode'" == "true")
	if `bip' {
		mata: _ergm_con_init(`nodes', `dir', `bip', strtoreal(`matobj'->get_modes())', *(`matobj'->get_matrix_mod(0,`dir')))
	}
	else {
		mata: _ergm_con_init(`nodes', `dir', `bip', J(`nodes',1,1), *(`matobj'->get_matrix_mod(0,`dir')))
	}
	local __con_observed ""
	mata: _ergm_con_split(`"`spec'"')
	forvalues t = 1/`__cn' {
		local sg  `__cs`t''
		local nm  `__cnm`t''
		local ar `"`__car`t''"'
		if inlist("`nm'", "fixedas", "fixallbut") {
			forvalues k = 1/3 {
				local __cb`k' ""
			}
			mata: _ergm_con_netnames(`"`nm'"', `"`ar'"')
			forvalues k = 1/`__cbn' {
				if `"`__cb`k''"' != "" {
					_nwsyntax `__cb`k'', max(1) other(cb)
					if `cbnodes' != `nodes' {
						di "{txt}Warning: network size of argument {bf:`__cb`k''} differs from that of the response network."
					}
					mata: __ncon_net`k' = *(`cbnetobj'->get_matrix_mod(0,`dir'))
				}
			}
		}
		mata: _ergm_con_apply(`"`nm'"', `sg', `"`ar'"')
	}
	mata: _ergm_con_finish("`weights'")
	if `"`__con_err'"' != "" {
		di as err `"`__con_err'"'
		error 198
	}
	foreach v in code dind implies maxonly hasdyad hasbd observed {
		c_local `prefix'con_`v' `"`__con_`v''"'
	}
end

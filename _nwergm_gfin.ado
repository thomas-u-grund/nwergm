*! version 1.10.0  19nov2026 _nwergm_gfin.ado -- saving() and export() of the plots of estat
* Copyright (C) 2026 Thomas U. Grund
* This file is part of nwergm, a Stata package derived from the R package 'ergm (statnet)' (Mark S. Handcock, David R. Hunter, Carter T. Butts, Steven M. Goodreau, Pavel N. Krivitsky, Martina Morris and contributors; GPL-3 (+ file LICENSE)).
* nwergm is free software: you can redistribute it and/or modify it under the terms of the GNU General
* Public License, version 3, as published by the Free Software Foundation. It is distributed in the hope
* that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
* or FITNESS FOR A PARTICULAR PURPOSE. See the file LICENSE for the full text.
* saves the graph held under the name to saving() and exports it with export(), as the plot commands of the other nw packages do
capture program drop _nwergm_gfin
program define _nwergm_gfin
	syntax anything(name=gname) [, SAVing(string) EXPort(string asis)]
	if `"`saving'"' != "" {
		quietly graph save `gname' `"`saving'"', replace
	}
	if `"`export'"' != "" {
		gettoken __fn __ex : export, parse(",")
		local __ex = trim(substr(`"`__ex'"', 2, .))
		quietly graph export `__fn', name(`gname') replace `__ex'
	}
end

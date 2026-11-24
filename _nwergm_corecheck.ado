*! version 1.16.1  24nov2026 _nwergm_corecheck.ado -- the plots need the shared graph helper of the core (nwcommands 3.29.0 or later)
* Copyright (C) 2026 Thomas U. Grund
* This file is part of nwergm, a Stata package derived from the R package 'ergm (statnet)' (Mark S. Handcock, David R. Hunter, Carter T. Butts, Steven M. Goodreau, Pavel N. Krivitsky, Martina Morris and contributors; GPL-3 (+ file LICENSE)).
* nwergm is free software: you can redistribute it and/or modify it under the terms of the GNU General
* Public License, version 3, as published by the Free Software Foundation. It is distributed in the hope
* that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
* or FITNESS FOR A PARTICULAR PURPOSE. See the file LICENSE for the full text.
* called at plot time only: a clear message instead of "unrecognized command" when the installed core is older
capture program drop _nwergm_corecheck
program define _nwergm_corecheck
	args what
	capture _nw_gfinish version
	local rc = _rc
	local api = cond(`rc', 0, r(api))
	if `rc' | `api' < 1 {
		di as err `"{p 0 0 2}`what' needs nwcommands 3.29.0 or later (the installed core is older). Update it with {bf:ado update nwcommands} or {bf:nwinstall}.{p_end}"'
		exit 199
	}
end

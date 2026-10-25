*! version 1.1.2  25oct2026 _nwergm_libcheck: clear message when the core and nwergm Mata libraries do not match
* Copyright (C) 2026 Thomas U. Grund
* This file is part of nwergm, a Stata package derived from the R package 'ergm (statnet)' (Mark S. Handcock, David R. Hunter, Carter T. Butts, Steven M. Goodreau, Pavel N. Krivitsky, Martina Morris and contributors; GPL-3 (+ file LICENSE)).
* nwergm is free software: you can redistribute it and/or modify it under the terms of the GNU General
* Public License, version 3, as published by the Free Software Foundation. It is distributed in the hope
* that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
* or FITNESS FOR A PARTICULAR PURPOSE. See the file LICENSE for the full text.
* _nwergm_slowwarn: one warning line before a long computation that runs on the Mata fallback sampler (the
* _nwergm_libcheck: the Mata library of nwergm (lnwergm.mlib) is compiled against the classes of the core nwcommands.
* If the installed core was built at a different time, Mata stops with r(3021) "class compiled at different times"
* (or r(3260)) at the first call. This program makes that first call and replaces the raw Mata error by a plain message.
capture program drop _nwergm_libcheck
program _nwergm_libcheck
	// Stata indexes the Mata libraries once, early in a session; a library installed by net install can be missing from that
	// index (r(3499) "not found", "class ErgmGraph undefined"). Index once when the library function is not visible.
	capture mata: mata which ergm_libcheck()
	if _rc {
		capture mata: mata mlib index
	}
	capture mata: ergm_libcheck()
	local rc = _rc
	if inlist(`rc', 3021, 3260) {
		di as err "The installed core nwcommands and nwergm were built for different versions (their Mata libraries do not match)."
		di as err "Reinstall the package: {bf:nwinstall, models} or {bf:net install nwergm, from(https://raw.githubusercontent.com/thomas-u-grund/nwergm/main/) replace}."
		exit `rc'
	}
end

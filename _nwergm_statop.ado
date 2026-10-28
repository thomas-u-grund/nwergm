*! version 1.3.4  28oct2026 _nwergm_statop: in-place log/exp transform of coefficient statistics (R's Log()/Exp())
* Copyright (C) 2026 Thomas U. Grund
* This file is part of nwergm, a Stata package derived from the R package 'ergm (statnet)' (Mark S. Handcock, David R. Hunter, Carter T. Butts, Steven M. Goodreau, Pavel N. Krivitsky, Martina Morris and contributors; GPL-3 (+ file LICENSE)).
* nwergm is free software: you can redistribute it and/or modify it under the terms of the GNU General
* Public License, version 3, as published by the Free Software Foundation. It is distributed in the hope
* that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
* or FITNESS FOR A PARTICULAR PURPOSE. See the file LICENSE for the full text.
// kind = "log" or "exp"; args: "coefname [coefname ...] [, log0(#)]".
capture program drop _nwergm_statop
program _nwergm_statop
	version 14
	gettoken kind 0 : 0
	syntax anything(name=names) [, LOG0(string)]
	if "`log0'" == "" local log0 = -1/sqrt(c(epsdouble))
	confirm number `log0'
	mata: st_local("__np", strofreal(__nwergm_last_M.nparam()))
	mata: _ergm_op_init(__nwergm_last_M)
	foreach nm of local names {
		mata: st_local("__pos", strofreal(__nwergm_last_M.findcoef("`nm'")))
		if `__pos' == 0 {
			di "{err}option {bf:`kind'stat()}: `nm' is not a coefficient name in this model."
			error 198
		}
		mata: st_local("__prev", strofreal(__nwergm_last_M.opkind[`__pos']))
		if `__prev' != 0 {
			di "{err}option {bf:`kind'stat()}: `nm' already has a statistic transform."
			error 198
		}
		mata: __nwergm_last_M.opkind[`__pos'] = `=cond("`kind'"=="log", 1, 2)'
		mata: __nwergm_last_M.opparam[`__pos'] = `log0'
		mata: __nwergm_last_M.coefnames[`__pos'] = "`kind'_" + __nwergm_last_M.coefnames[`__pos']
	}
end

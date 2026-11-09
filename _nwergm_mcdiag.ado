*! version 1.5.5  09nov2026 _nwergm_mcdiag.ado -- the report of R's mcmc.diagnostics() for the final MCMC sample of an nwergm fit
* Copyright (C) 2026 Thomas U. Grund
* This file is part of nwergm, a Stata package derived from the R package 'ergm (statnet)' (Mark S. Handcock, David R. Hunter, Carter T. Butts, Steven M. Goodreau, Pavel N. Krivitsky, Martina Morris and contributors; GPL-3 (+ file LICENSE)).
* nwergm is free software: you can redistribute it and/or modify it under the terms of the GNU General
* Public License, version 3, as published by the Free Software Foundation. It is distributed in the hope
* that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
* or FITNESS FOR A PARTICULAR PURPOSE. See the file LICENSE for the full text.
capture program drop _nwergm_mcdiag
program _nwergm_mcdiag, rclass
	version 14
	syntax [, PLOT NAME(string) PVALUE(real 0.05) EPS(real 0.1)]
	if `"`e(cmd)'"' != "nwergm" | `"`e(method)'"' != "mcmle" exit
	capture confirm matrix e(mcmcsample)
	if _rc exit
	if e(curved) == 1 {
		di as txt "(R-style sample diagnostics are not shown for models with curved terms)"
		exit
	}
	capture mata: __nwergm_last_M.nparam()
	if _rc exit
	local depvar `"`e(depvar)'"'
	capture _nwsyntax `depvar', max(1)
	if _rc {
		di as txt "(network `depvar' is no longer loaded; the R-style sample diagnostics need it for the observed statistics)"
		exit
	}
	local dir = ("`e(directed)'" == "true")
	tempname obsG obsstat C
	mata: `obsG' = ErgmGraph()
	mata: `obsG'.init(`nodes', `dir')
	mata: st_local("__isbip", strofreal(__nwergm_last_G.bipartite))
	if `__isbip' mata: `obsG'.set_bipartite(__nwergm_last_G.mode)
	mata: ergm_bridge_obs(`netobj', `obsG', `dir')
	mata: `obsstat' = ergm_full_stat(__nwergm_last_M, `obsG')
	mata: mata drop `obsG'
	mata: `C' = st_matrix("e(mcmcsample)") :- `obsstat'
	mata: `C' = `C'[., selectindex(__nwergm_last_M.isfixed :== 0)]
	local names : colnames e(b)
	mata: st_local("keepnames", invtokens(tokens("`names'")[selectindex(__nwergm_last_M.isfixed :== 0)]))
	local thin = e(mcmc_interval)
	if "`e(mcmc_interval_final)'" != "" local thin = e(mcmc_interval_final)
	mata: st_local("n", strofreal(rows(`C'), "%18.0g"))
	mata: st_local("p", strofreal(cols(`C'), "%18.0g"))
	if `p' == 0 {
		mata: mata drop `obsstat' `C'
		exit
	}

	// The tables are printed with matlist, which splits wide tables into panels that
	// fit the line size. The numbers are those of R's mcmc.diagnostics().
	local w = 12
	foreach nm of local keepnames {
		local w = max(`w', min(28, udstrlen("`nm'")))
	}

	// ---- 1. summary (coda)
	tempname SUM Q
	mata: ergm_mcdiag_summary(`C', "`SUM'", "`Q'")
	matrix rownames `SUM' = `keepnames'
	matrix rownames `Q' = `keepnames'
	matrix colnames `SUM' = Mean SD "Naive SE" "TS SE"
	matrix colnames `Q' = 2.5% 25% 50% 75% 97.5%
	di
	di as txt "{p 0 0 2}Report of mcmc.diagnostics() in R for the final sample, centered at the observed statistics{p_end}"
	di
	di as txt "Mean and standard deviation, standard error of the mean (naive and time series)"
	matlist `SUM', format(%9.4g) twidth(`w') rowtitle("Statistic") border(top bottom)
	di
	di as txt "Quantiles"
	matlist `Q', format(%9.4g) twidth(`w') rowtitle("Statistic") border(top bottom)

	// ---- 2. are the sample statistics different from observed?
	tempname DT DTt
	mata: ergm_mcdiag_obstest(`C', "`DT'")
	matrix rownames `DT' = diff. test_stat. P-val.
	matrix `DTt' = `DT''
	matrix colnames `DTt' = Diff. Test p-value
	matrix rownames `DTt' = `keepnames' Omnibus
	di
	di as txt "Difference between the sample and the observed statistics"
	matlist `DTt', format(%9.4g) twidth(`w') rowtitle("Statistic") border(top bottom)

	// ---- 3. cross-correlations and autocorrelation
	tempname XC AC ACt
	mata: ergm_mcdiag_corr(`C', "`XC'", "`AC'")
	matrix colnames `XC' = `keepnames'
	matrix rownames `XC' = `keepnames'
	di
	di as txt "Cross-correlations"
	matlist `XC', format(%9.3f) twidth(`w') border(top bottom) lines(oneline)
	matrix colnames `AC' = `keepnames'
	local lags ""
	forvalues l = 0/5 {
		local lags "`lags' `=`l'*`thin''"
	}
	matrix rownames `AC' = `lags'
	matrix `ACt' = `AC'[2..6, 1...]'
	di
	di as txt "Autocorrelation at lag (in proposals)"
	matlist `ACt', format(%9.3f) twidth(`w') rowtitle("Statistic") border(top bottom)

	// ---- 4. Geweke burn-in diagnostic
	tempname GW GWt
	mata: ergm_mcdiag_geweke(`C', "`GW'")
	matrix `GWt' = `GW'[1..2, 1..`p']'
	matrix rownames `GWt' = `keepnames'
	matrix colnames `GWt' = z p-value
	di
	di as txt "Geweke test (first 10% against last 50% of the sample)"
	matlist `GWt', format(%9.3f) twidth(`w') rowtitle("Statistic") border(top bottom)
	di as txt "Joint p-value = " as res %5.3f `GW'[2,`p'+1]
	di
	di as txt "{p 0 0 2}Note: the sample comes from the last simulation, run before the final estimates were computed, so these diagnostics may understate how well the final model fits its statistics; {cmd:estat gof} assesses the final model directly.{p_end}"

	return matrix mc_summary = `SUM'
	return matrix mc_quantiles = `Q'
	return matrix mc_obstest = `DT'
	return matrix mc_crosscorr = `XC'
	return matrix mc_autocorr = `AC'
	return matrix mc_geweke = `GW'
	mata: mata drop `obsstat' `C'
end

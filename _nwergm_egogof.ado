*! version 1.14.0  22nov2026 _nwergm_egogof.ado -- estat gof after nwergm ego, following R's gof.ergm.ego(): the statistics of the model and the degree distribution of the egos against simulations from the fitted model
* Copyright (C) 2026 Thomas U. Grund
* This file is part of nwergm, a Stata package derived from the R package 'ergm (statnet)' (Mark S. Handcock, David R. Hunter, Carter T. Butts, Steven M. Goodreau, Pavel N. Krivitsky, Martina Morris and contributors; GPL-3 (+ file LICENSE)).
* nwergm is free software: you can redistribute it and/or modify it under the terms of the GNU General
* Public License, version 3, as published by the Free Software Foundation. It is distributed in the hope
* that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
* or FITNESS FOR A PARTICULAR PURPOSE. See the file LICENSE for the full text.
capture program drop _nwergm_egogof
program _nwergm_egogof, rclass
	syntax [, NSIM(integer 100) SEED(string) GOFBURNIN(integer -1) GOFINTERVAL(integer -1) GOF(string) PLOT NAME(string) SAVing(string) EXPort(string asis) * ]
	if `"`e(cmd)'"' != "nwergm" | "`e(estimate)'" != "Ego" {
		di as err "last nwergm ego estimates not found"
		exit 301
	}
	if `"`options'"' != "" {
		di as err `"{p 0 0 2}option(s) {bf:`options'} not allowed with {bf:estat gof} after {bf:nwergm ego}; the options are nsim(), seed(), gof(), gofburnin(), gofinterval(), plot, name(), saving() and export().{p_end}"'
		exit 198
	}
	if "`plot'" != "" | `"`saving'`export'"' != "" {
		_nwergm_corecheck "estat gof, plot"
		local __exopt ""
		if `"`export'"' != "" local __exopt `"export(`"`export'"')"'
		_nw_gfinish check, plot(`plot') name(`name') saving(`saving') `__exopt' default(gof) nameok cmd(estat gof)
		local name `"`r(name)'"'
		local saving `"`r(saving)'"'
	}
	capture mata: __nwergm_last_G.n
	if _rc {
		di as err "{p 0 0 2}no fitted nwergm model available for simulation - re-run nwergm ego before estat gof.{p_end}"
		exit 498
	}
	if `nsim' < 2 {
		di as err "option nsim() must be at least 2."
		exit 198
	}
	capture mata: st_local("__ftag", __nwergm_last_tag)
	if _rc | `"`__ftag'"' == "" | `"`__ftag'"' != `"`e(fittag)'"' {
		di as err "{p 0 0 2}the model of these nwergm estimates is no longer in memory (another nwergm call replaced it, or the estimates were restored); re-fit the model with nwergm ego first.{p_end}"
		exit 498
	}
	if `"`seed'"' != "" {
		capture confirm integer number `seed'
		if _rc | real(`"`seed'"') < 0 | real(`"`seed'"') > 2147483647 {
			di as error "seed() must be an integer between 0 and 2147483647"
			exit 198
		}
	}
	// R: GOF = ~ model + degree (+ espartners, which needs the ties among the alters: not available here)
	if `"`gof'"' == "" local gof "model degree"
	local gof = subinstr(subinstr(`"`gof'"', "~", " ", .), "+", " ", .)
	local wantmodel 0
	local wantdeg 0
	foreach tok of local gof {
		if strpos("model", "`tok'") == 1 local wantmodel 1
		else if strpos("degree", "`tok'") == 1 local wantdeg 1
		else {
			di as err "{p 0 0 2}estat gof after nwergm ego: unknown statistic {bf:`tok'}; choose from model and degree.{p_end}"
			exit 198
		}
	}
	if `gofburnin' < 0 {
		local gofburnin = 16384
		if "`e(mcmc_burnin)'" != "" local gofburnin = e(mcmc_burnin)
	}
	if `gofinterval' < 0 {
		local gofinterval = 1024
		if "`e(mcmc_interval_final)'" != "" local gofinterval = e(mcmc_interval_final)
		else if "`e(mcmc_interval)'" != "" local gofinterval = e(mcmc_interval)
		// R: the fit's interval, rescaled by (estimation sample size / gof sample size)
		if "`e(mcmc_samplesize)'" != "" local gofinterval = max(ceil(`gofinterval' * e(mcmc_samplesize) / `nsim'), 1)
	}
	if `"`seed'"' != "" set seed `seed'
	local pp = e(ppopsize)
	local md = e(maxdeg)

	mata: st_local("__hasmask", strofreal(__nwergm_last_G.has_dyadmask))
	if e(trifocus) < . {
		local propfn "&ergm_propose_spdyad()"
		mata: __nwergm_last_G.spd_focus = `=e(trifocus)'
	}
	else if "`e(proposal)'" == "uniform" local propfn "&ergm_propose_uniform()"
	else local propfn "&ergm_propose_tnt()"
	mata: st_local("__gnat", strofreal(__nwergm_last_M.native_enabled_sample))
	if !`__gnat' _nwergm_slowwarn "estat gof" "fit"
	tempname bmat Afit
	_nwergm_getb `bmat'
	// the chain changes the network the fit leaves behind: put it back exactly afterwards
	mata: `Afit' = __nwergm_last_G.all_ties()
	mata: ergm_ego_gof(__nwergm_last_M, __nwergm_last_G, st_matrix("`bmat'"), `nsim', `gofburnin', `gofinterval', `propfn', `md', "__egog")
	mata: ergm_graph_set_ties(__nwergm_last_G, `Afit')
	mata: mata drop `Afit'
	tempname Sm Sd T Dd
	matrix `Sm' = __egog_smodel
	matrix `Sd' = __egog_sdeg
	capture matrix drop __egog_smodel
	capture matrix drop __egog_sdeg
	matrix `T' = e(target) / `pp'
	matrix `Dd' = e(degdist)
	local cn : colnames e(b)

	if `wantmodel' {
		tempname P
		_nwergm_egogof_table `Sm' `T', names(`cn') title("model statistics, per capita") first("Statistic") nsim(`nsim') matname(`P')
		return matrix gof_model = `P'
	}
	if `wantdeg' {
		tempname P
		local labs ""
		forvalues d = 0/`=`md'-1' {
			local labs "`labs' `d'"
		}
		local labs "`labs' `md'+"
		_nwergm_egogof_table `Sd' `Dd', names(`labs') title("degree, share of the nodes") first("Degree") nsim(`nsim') matname(`P')
		return matrix gof_degree = `P'
		if "`plot'" != "" {
			// _nwergm_gofplot takes Mata matrices (the Stata matrices of the first version failed with r(3499))
			tempname M5 S
			mata: `S' = st_matrix("`Dd'")
			mata: `M5' = ergm_gof_sum5(st_matrix("`Sd'"))
			mata: st_local("__ncat", strofreal(cols(`S')))
			tempname __pg
			_nwergm_gofplot `S' `M5' "Degree" "`__pg'" 0 `__ncat' "`=`__ncat'-1'+"
			// the panel is drawn with nodraw; graph export needs a drawn graph on a computer without a display (Linux, r(693)), so, as for the
			// other estat gof plots, the graph is made by graph combine
			graph combine `__pg', cols(1) name(`name', replace)
			capture graph drop `__pg'
			mata: mata drop `M5' `S'
			_nw_gfinish save, name(`name') saving(`saving') export(`"`export'"')
			di as txt "{p 0 0 2}(plot saved as {bf:`name'}; box and whiskers summarize the simulated draws, the red line with circles is the estimate from the egos){p_end}"
		}
	}
	return scalar nsim = `nsim'
	return scalar burnin = `gofburnin'
	return scalar interval = `gofinterval'
end

// prints the table (observed from the egos, min, mean, max of the draws, MC p-value) and returns it in the matrix matname
capture program drop _nwergm_egogof_table
program _nwergm_egogof_table
	syntax anything(name=args), NAMES(string) TITLE(string) FIRST(string) NSIM(integer) MATNAME(name)
	tokenize `args'
	local S `1'
	local O `2'
	local k = colsof(`S')
	tempname P
	matrix `P' = J(`k', 5, .)
	forvalues j = 1/`k' {
		mata: st_matrix("`P'", ergm_ego_gofrow(st_matrix("`S'"), st_matrix("`O'"), `j', st_matrix("`P'")))
	}
	matrix colnames `P' = obs min mean max MC_p-value
	matrix rownames `P' = `names'
	local w = 12
	foreach lb of local names {
		local w = max(`w', min(28, udstrlen("`lb'")))
	}
	di
	di as txt "Goodness of fit: `title' (" as res `nsim' as txt " simulated networks)"
	di as txt "{hline `=`w'+1'}{c TT}{hline 52}"
	di as txt %`w's "`first'" " {c |}" %10s "Estimate" %10s "Min" %10s "Mean" %10s "Max" %12s "MC p-value"
	di as txt "{hline `=`w'+1'}{c +}{hline 52}"
	local i 0
	foreach lb of local names {
		local ++i
		if `P'[`i',1] == 0 & `P'[`i',2] == 0 & `P'[`i',4] == 0 continue
		di as txt %`w's abbrev("`lb'", `w') " {c |}" as res %10.4f `P'[`i',1] %10.4f `P'[`i',2] %10.4f `P'[`i',3] %10.4f `P'[`i',4] %12.2f `P'[`i',5]
	}
	di as txt "{hline `=`w'+1'}{c BT}{hline 52}"
	matrix `matname' = `P'
end

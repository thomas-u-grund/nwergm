*! version 1.7.1  13nov2026 _nwergm_gof.ado -- estat gof after nwergm, following R's gof.ergm(): observed values against simulations from the fitted model
* Copyright (C) 2026 Thomas U. Grund
* This file is part of nwergm, a Stata package derived from the R package 'ergm (statnet)' (Mark S. Handcock, David R. Hunter, Carter T. Butts, Steven M. Goodreau, Pavel N. Krivitsky, Martina Morris and contributors; GPL-3 (+ file LICENSE)).
* nwergm is free software: you can redistribute it and/or modify it under the terms of the GNU General
* Public License, version 3, as published by the Free Software Foundation. It is distributed in the hope
* that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
* or FITNESS FOR A PARTICULAR PURPOSE. See the file LICENSE for the full text.
capture program drop _nwergm_gof
program _nwergm_gof, rclass
	syntax [, NSIM(integer 100) SEED(string) GOFBURNIN(integer -1) GOFINTERVAL(integer -1) ///
		PLOT MAXDEG(integer 15) MAXDIST(integer 6) NAME(string) GOF(string) ]
	if `"`e(cmd)'"' != "nwergm" {
		di as err "last nwergm estimates not found"
		exit 301
	}
	capture mata: __nwergm_last_G.n
	if _rc {
		di as err "{p 0 0 2}no fitted nwergm model available for simulation - re-run nwergm before estat gof.{p_end}"
		exit 498
	}
	if `nsim' < 2 {
		di as err "option nsim() must be at least 2."
		exit 198
	}
	// the model held in Mata must be the one of these estimates (another nwergm call, or estimates restore of an
	// earlier fit, replaces or mismatches it)
	capture mata: st_local("__ftag", __nwergm_last_tag)
	if _rc | `"`__ftag'"' == "" | `"`__ftag'"' != `"`e(fittag)'"' {
		di as err "{p 0 0 2}the model of these nwergm estimates is no longer in memory (another nwergm call replaced it, or the estimates were restored); re-fit the model with nwergm first.{p_end}"
		exit 498
	}
	if `"`seed'"' != "" {
		capture confirm integer number `seed'
		if _rc | real(`"`seed'"') < 0 | real(`"`seed'"') > 2147483647 {
			di as error "seed() must be an integer between 0 and 2147483647"
			exit 198
		}
	}

	if `gofburnin' < 0 {
		local gofburnin = 16384
		if "`e(mcmc_burnin)'" != "" local gofburnin = e(mcmc_burnin)
	}
	if `gofinterval' < 0 {
		// R: the fit's interval, rescaled by (estimation sample size / gof sample size)
		// after MPLE there is no MCMC sample: R's gof.ergm() uses its default interval of 1024
		local gofinterval = 1024
		if "`e(mcmc_interval_final)'" != "" local gofinterval = e(mcmc_interval_final)
		else if "`e(mcmc_interval)'" != "" local gofinterval = e(mcmc_interval)
		if "`e(mcmc_samplesize)'" != "" & "`e(method)'" != "mple" {
			local gofinterval = max(ceil(`gofinterval' * e(mcmc_samplesize) / `nsim'), 1)
		}
	}
	if `"`seed'"' != "" set seed `seed'

	local depvar `"`e(depvar)'"'
	local edirected `"`e(directed)'"'
	capture _nwsyntax `depvar', max(1)
	if _rc {
		di as err "{p 0 0 2}network `depvar' (the network nwergm was fitted on) is no longer loaded - estat gof needs it for the observed comparison statistics.{p_end}"
		exit 498
	}
	if `nodes' != e(nodes) | ("`directed'"=="true") != ("`edirected'"=="true") {
		di as err "{p 0 0 2}network `depvar' no longer matches the network nwergm was fitted on (nodes or directedness differ) - re-fit before running estat gof.{p_end}"
		exit 498
	}
	local dir = ("`edirected'" == "true")
	mata: st_local("n1", strofreal(__nwergm_last_G.bipartite ? rows(__nwergm_last_G.mode1nodes) : 0, "%18.0g"))
	local bip = ("`n1'" != "0")

	// ---- which statistics (R: GOF = ~ degree + espartners + ... ; "-model" drops the model statistics)
	local allterms "model distance odegree idegree degree b1degree b2degree espartners dspartners triadcensus"
	local gcode_model model
	local gcode_distance dist
	local gcode_odegree odeg
	local gcode_idegree ideg
	local gcode_degree deg
	local gcode_b1degree b1deg
	local gcode_b2degree b2deg
	local gcode_espartners espart
	local gcode_dspartners dspart
	local gcode_triadcensus triad
	local want ""
	local hasmodel 1
	if `"`gof'"' == "" {
		if `bip' local gof "b1degree b2degree dspartners distance"
		else if `dir' local gof "idegree odegree espartners distance"
		else local gof "degree espartners distance"
	}
	local gof = subinstr(subinstr(`"`gof'"', "~", " ", .), "+", " ", .)
	local nmodel 0
	foreach tok of local gof {
		local sign 1
		if substr("`tok'", 1, 1) == "-" {
			local sign -1
			local tok = substr("`tok'", 2, .)
		}
		local found ""
		foreach t of local allterms {
			if "`tok'" == "`t'" local found "`t'"
		}
		if "`found'" == "" {
			// R matches partially
			local nm 0
			foreach t of local allterms {
				if strpos("`t'", "`tok'") == 1 {
					local found "`t'"
					local ++nm
				}
			}
			if `nm' != 1 local found ""
		}
		if "`found'" == "" {
			di as err "{p 0 0 2}estat gof: unknown statistic `tok'; choose from degree idegree odegree b1degree b2degree espartners dspartners distance triadcensus model.{p_end}"
			exit 198
		}
		if "`found'" == "model" local nmodel = `nmodel' + `sign'
		else {
			if `sign' < 0 continue
			if !`dir' & inlist("`found'", "idegree", "odegree") {
				di as err "estat gof: `found' needs a directed network."
				exit 198
			}
			if `dir' & "`found'" == "degree" {
				di as err "estat gof: degree is for undirected networks; use idegree and odegree."
				exit 198
			}
			if !`bip' & inlist("`found'", "b1degree", "b2degree") {
				di as err "estat gof: `found' needs a two-mode network."
				exit 198
			}
			if `bip' & inlist("`found'", "degree", "espartners", "triadcensus") {
				di as err "estat gof: `found' is not defined for a two-mode network."
				exit 198
			}
			local want "`want' `found'"
		}
	}
	local hasmodel = (`nmodel' >= 0)
	if `hasmodel' local want "model `want'"

	// ---- observed network
	tempname obsG obsmat obsstat
	mata: `obsG' = ErgmGraph()
	mata: `obsG'.init(`nodes', `dir')
	mata: st_local("__isbip", strofreal(__nwergm_last_G.bipartite))
	if `__isbip' mata: `obsG'.set_bipartite(__nwergm_last_G.mode)
	mata: ergm_bridge_obs(`netobj', `obsG', `dir')
	mata: `obsmat' = `obsG'.to_dense()
	mata: `obsstat' = ergm_full_stat(__nwergm_last_M, `obsG')
	mata: mata drop `obsG'

	// groups simulated: the requested ones plus what the summary returns need
	local groups ""
	foreach t of local want {
		local groups "`groups' `gcode_`t''"
	}
	local extra ""
	local extradeg = cond(`dir', "ideg", "deg")
	if `bip' local extradeg ""
	foreach x in `extradeg' dist triad {
		if `bip' & "`x'" == "triad" continue
		local have 0
		foreach g of local groups {
			if "`g'" == "`x'" local have 1
		}
		if !`have' {
			if "`x'" == "triad" & `nodes' > 100 continue
			local extra "`extra' `x'"
		}
	}
	local simgroups "`groups'`extra'"
	local simgroups : list clean simgroups
	mata: st_local("__hasmask", strofreal(__nwergm_last_G.has_dyadmask))
	if e(trifocus) < . {
		local propfn "&ergm_propose_spdyad()"
		mata: __nwergm_last_G.spd_focus = `=e(trifocus)'
	}
	else if `__hasmask' {
		if "`e(proposal)'" == "tnt" local propfn "&ergm_propose_tnt_masked()"
		else local propfn "&ergm_propose_uniform_masked()"
	}
	else if "`e(proposal)'" == "uniform" local propfn "&ergm_propose_uniform()"
	else local propfn "&ergm_propose_tnt()"

	mata: st_local("__gnat", strofreal(__nwergm_last_M.native_enabled_sample))
	if !`__gnat' _nwergm_slowwarn "estat gof" "fit"
	tempname bmat
	_nwergm_getb `bmat'
	mata: __gof_groups = tokens("`simgroups'")
	// the chain changes the network the fit leaves behind (and the order of its ties steers the TNT proposal): put it
	// back exactly afterwards, so that a later estat gof or nwergm simulate starts where the fit ended
	tempname Afit
	mata: `Afit' = __nwergm_last_G.all_ties()
	mata: ergm_gof_run(__nwergm_last_M, __nwergm_last_G, `obsmat', `obsstat', st_matrix("`bmat'"), `nsim', `gofburnin', `gofinterval', `propfn', `dir', `n1', __gof_groups, "__gofE7")
	mata: ergm_graph_set_ties(__nwergm_last_G, `Afit')
	mata: mata drop `Afit'
	mata: mata drop __gof_groups `obsmat' `obsstat'

	// ---- print in R's order
	local order "model distance odegree idegree degree b1degree b2degree espartners dspartners triadcensus"
	local desc_model "model statistics"
	local desc_distance "minimum geodesic distance"
	local desc_odegree "out-degree"
	local desc_idegree "in-degree"
	local desc_degree "degree"
	local desc_b1degree "bipartition 1 degree"
	local desc_b2degree "bipartition 2 degree"
	local desc_espartners "edgewise shared partner"
	local desc_dspartners "dyadwise shared partner"
	local desc_triadcensus "triad census"
	local dtri "003 012 102 021D 021U 021C 111D 111U 030T 030C 201 120D 120U 120C 210 300"
	foreach t of local order {
		local inwant 0
		foreach w of local want {
			if "`w'" == "`t'" local inwant 1
		}
		if !`inwant' continue
		local g "`gcode_`t''"
		tempname P
		matrix `P' = __gofE7_p_`g'
		local k = rowsof(`P')
		local labs ""
		forvalues i = 1/`k' {
			if "`t'" == "model" {
				mata: st_local("lb", __nwergm_last_M.coefnames[`i'])
			}
			else if "`t'" == "distance" local lb = cond(`i' == `k', "Inf", "`i'")
			else if "`t'" == "triadcensus" & `dir' local lb : word `i' of `dtri'
			else if "`t'" == "triadcensus" local lb = `i' - 1
			else if "`t'" == "b1degree" | "`t'" == "b2degree" | inlist("`t'", "degree", "idegree", "odegree", "espartners", "dspartners") local lb = `i' - 1
			local labs "`labs' `lb'"
		}
		matrix colnames `P' = obs min mean max MC_p-value
		matrix rownames `P' = `labs'
		// header of the first column, and its width: the longest label, 12 to 28 characters
		local hd "Statistic"
		if inlist("`t'", "degree", "idegree", "odegree") local hd = cond("`t'"=="idegree", "In-degree", cond("`t'"=="odegree", "Out-degree", "Degree"))
		else if inlist("`t'", "b1degree", "b2degree") local hd "Degree"
		else if "`t'" == "espartners" local hd "ESP"
		else if "`t'" == "dspartners" local hd "DSP"
		else if "`t'" == "distance" local hd "Distance"
		else if "`t'" == "triadcensus" local hd "Triad type"
		local w = 12
		foreach lb of local labs {
			local w = max(`w', min(28, udstrlen("`lb'")))
		}
		di
		di as txt "Goodness of fit: `desc_`t'' (" as res `nsim' as txt " simulated networks)"
		di as txt "{hline `=`w'+1'}{c TT}{hline 52}"
		di as txt %`w's "`hd'" " {c |}" %10s "Observed" %10s "Min" %10s "Mean" %10s "Max" %12s "MC p-value"
		di as txt "{hline `=`w'+1'}{c +}{hline 52}"
		forvalues i = 1/`k' {
			if `P'[`i',1] == 0 & `P'[`i',2] == 0 & `P'[`i',4] == 0 continue
			local lb : word `i' of `labs'
			// counts print as integers; a row with a non-integer value (gwesp and other weighted terms) prints with two decimals
			local fm "%10.0f"
			if `P'[`i',1] != floor(`P'[`i',1]) | `P'[`i',2] != floor(`P'[`i',2]) | `P'[`i',4] != floor(`P'[`i',4]) local fm "%10.2f"
			di as txt %`w's abbrev("`lb'", `w') " {c |}" as res `fm' `P'[`i',1] `fm' `P'[`i',2] %10.2f `P'[`i',3] `fm' `P'[`i',4] %12.2f `P'[`i',5]
		}
		di as txt "{hline `=`w'+1'}{c BT}{hline 52}"
		return matrix gof_`t' = `P'
	}

	// ---- summary scalars (as before)
	local obs_meandeg = 2*e(ties)/e(nodes)
	mata: st_numscalar("__gofE7_nn", `nodes')
	if !`bip' {
		tempname S
		if `dir' {
			mata: st_numscalar("__gofE7_md", 2 * mean(rowsum(st_matrix("__gofE7_s_ideg") :* (0..cols(st_matrix("__gofE7_s_ideg"))-1))) / `nodes')
		}
		else {
			mata: st_numscalar("__gofE7_md", mean(rowsum(st_matrix("__gofE7_s_deg") :* (0..cols(st_matrix("__gofE7_s_deg"))-1))) / `nodes')
		}
		return scalar sim_meandeg = scalar(__gofE7_md)
		return scalar obs_meandeg = `obs_meandeg'
		// average geodesic distance (connected draws only; -1 = observed network disconnected)
		mata: st_numscalar("__gofE7_op", ergm_gof_avgpath(st_matrix("__gofE7_o_dist")))
		mata: st_numscalar("__gofE7_sp", ergm_gof_avgpath_sim(st_matrix("__gofE7_s_dist")))
		return scalar obs_avgpath = scalar(__gofE7_op)
		return scalar sim_avgpath = scalar(__gofE7_sp)
		capture confirm matrix __gofE7_o_triad
		if _rc == 0 {
			if `dir' {
				local cats "_003 _012 _102 _021D _021U _021C _111D _111U _030T _030C _201 _120D _120U _120C _210 _300"
			}
			else local cats "_003 _102 _201 _300"
			local ci 0
			foreach c of local cats {
				local ++ci
				mata: st_numscalar("__gofE7_x", st_matrix("__gofE7_o_triad")[1, `ci'])
				return scalar obs_triad`c' = scalar(__gofE7_x)
				mata: st_numscalar("__gofE7_x", mean(st_matrix("__gofE7_s_triad")[., `ci']))
				return scalar sim_triad`c' = scalar(__gofE7_x)
			}
			local ci : list posof "_300" in cats
			mata: st_numscalar("__gofE7_x", st_matrix("__gofE7_o_triad")[1, `ci'])
			return scalar obs_triad300 = scalar(__gofE7_x)
			mata: st_numscalar("__gofE7_x", mean(st_matrix("__gofE7_s_triad")[., `ci']))
			return scalar sim_triad300 = scalar(__gofE7_x)
		}
	}
	return scalar nsim = `nsim'
	return scalar burnin = `gofburnin'
	return scalar interval = `gofinterval'

	if "`plot'" != "" & !`bip' {
		if "`name'" == "" local name "gof"
		tempname obsdeg obsgeo degsumm geosumm panel1 panel2
		local dg = cond(`dir', "ideg", "deg")
		mata: `obsdeg' = ergm_gof_collapse(st_matrix("__gofE7_o_`dg'"), `maxdeg'+1, `nodes')
		mata: `degsumm' = ergm_gof_sum5(ergm_gof_collapse(st_matrix("__gofE7_s_`dg'"), `maxdeg'+1, `nodes'))
		mata: `obsgeo' = ergm_gof_collapse(st_matrix("__gofE7_o_dist"), `maxdist', 0)
		mata: `geosumm' = ergm_gof_sum5(ergm_gof_collapse(st_matrix("__gofE7_s_dist"), `maxdist', 0))
		_nwergm_gofplot `obsdeg' `degsumm' "Degree" "`panel1'" 0 `=`maxdeg'+2' "`maxdeg'+"
		_nwergm_gofplot `obsgeo' `geosumm' "Geodesic distance" "`panel2'" 1 `=`maxdist'+1' "NR"
		graph combine `panel1' `panel2', cols(2) ///
			title("Goodness of fit: observed vs. `nsim' simulated draws", size(medium)) ///
			name(`name', replace)
		capture graph drop `panel1'
		capture graph drop `panel2'
		mata: mata drop `obsdeg' `obsgeo' `degsumm' `geosumm'
		di as txt "{p 0 0 2}(plot saved as {bf:`name'}; box and whiskers summarize the simulated draws, the red line with circles is the observed network){p_end}"
	}
	capture mata: mata drop __gofE7_x
	foreach m in p s o {
		foreach g in model deg ideg odeg b1deg b2deg espart dspart dist triad {
			capture matrix drop __gofE7_`m'_`g'
		}
	}
	capture scalar drop __gofE7_nn __gofE7_md __gofE7_op __gofE7_sp __gofE7_x
end

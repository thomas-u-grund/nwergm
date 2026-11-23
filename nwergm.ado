*! version 1.16.0  23nov2026 nwergm
* Copyright (C) 2026 Thomas U. Grund
* This file is part of nwergm, a Stata package derived from the R package 'ergm (statnet)' (Mark S. Handcock, David R. Hunter, Carter T. Butts, Steven M. Goodreau, Pavel N. Krivitsky, Martina Morris and contributors; GPL-3 (+ file LICENSE)).
* nwergm is free software: you can redistribute it and/or modify it under the terms of the GNU General
* Public License, version 3, as published by the Free Software Foundation. It is distributed in the hope
* that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
* or FITNESS FOR A PARTICULAR PURPOSE. See the file LICENSE for the full text.

capture program drop nwergm
program nwergm
	version 14
	* egocentrically sampled data: nwergm ego, ... (the data in memory are the egos; no network is named). A network
	* called ego still works: the subcommand is taken only when an option of the ego fit is given
	gettoken __ego_t0 : 0, parse(" ,")
	if `"`__ego_t0'"' == "ego" & regexm(`"`0'"', "(egoid|alters|egodegree)[ ]*\(") {
		_nwergm_run `0'
		exit
	}
	* String node attributes (1.5.11). A string variable named, with its full name, in a
	* categorical term (nodematch(), nodefactor(), nodemix() and their relatives) is
	* replaced for the duration of the call by a numeric variable of the same name that
	* holds the codes -encode- would give (strings in sorted order, value label = the
	* strings); afterwards the string variable is put back where it was. Terms that use
	* the values as numbers (nodecov() etc.) still refuse a string variable. A call
	* without string variables runs exactly as before. Variables whose names start
	* with _nw (node names, bookkeeping) are never touched.
	local __cat "nodematchdiff|nodematch|nodefactordistinct|nodeofactordistinct|nodeifactordistinct|nodefactor|nodeofactor|nodeifactor|nodemix|mm|bfactordistinct1|bfactordistinct2|bfactor1|bfactor2|bnodematch1|bnodematch2|blockdiag"
	local __re "(?i)(?<![A-Za-z0-9_])(`__cat')\(([^()]*(?:\([^()]*\)[^()]*)*)\)"
	local __rest `"`0'"'
	local __args
	while ustrregexm(`"`__rest'"', "`__re'") {
		local __a = ustrregexs(2)
		local __args `"`__args' `__a'"'
		local __rest = ustrregexrf(`"`__rest'"', "`__re'", " ")
	}
	local __toks = ustrregexra(`"`__args'"', "[^A-Za-z0-9_]", " ")
	local __toks : list uniq __toks
	local __sv
	foreach __t of local __toks {
		if substr("`__t'", 1, 3) == "_nw" continue
		capture confirm string variable `__t', exact
		if !_rc local __sv `__sv' `__t'
	}
	if "`__sv'" == "" {
		_nwergm_run `0'
		exit
	}
	local __i = 0
	foreach __v of local __sv {
		local ++__i
		tempvar __s`__i'
		tempname __l`__i'
		rename `__v' `__s`__i''
		quietly encode `__s`__i'', generate(`__v') label(`__l`__i'')
		order `__v', after(`__s`__i'')
	}
	capture noisily _nwergm_run `0'
	local __rc = _rc
	local __i = 0
	foreach __v of local __sv {
		local ++__i
		capture confirm variable `__s`__i'', exact
		if !_rc {
			capture drop `__v'
			rename `__s`__i'' `__v'
		}
		capture label drop `__l`__i''
	}
	exit `__rc'
end

capture program drop _nwergm_run
program _nwergm_run, eclass
	version 14
	* an option given twice (edgecov(a) edgecov(b)) gets a clear error instead of "option edgecov() not allowed"
	_nwergm_dupopt `0'
	gettoken __ergm_t1 : 0, parse(" ,")
	if word(`"`0'"', 1) == "version" {
		nwergm_version
		exit
	}
	_nwergm_libcheck
	// replay: nwergm with no arguments, or with display options only (ci, level(), noci, nopvalues, cformat() and the
	// other options of Stata's ereturn display), after an nwergm fit; also what estimates replay runs
	if replay() {
		capture _nwergm_tabopts __ergm_t check `0'
		if !_rc {
			if "`e(cmd)'" != "nwergm" error 301
			_nwergm_replay `0'
			exit
		}
	}
	if `"`__ergm_t1'"' == "ego" & regexm(`"`0'"', "(egoid|alters|egodegree)[ ]*\(") {
		gettoken __ergm_sub 0 : 0, parse(" ,")
		_nwergm_hold save
		capture noisily _nwergm_ego `0'
		local __ergm_rc = _rc
		if `__ergm_rc' {
			_nwergm_hold restore
			exit `__ergm_rc'
		}
		_nwergm_hold drop
		exit
	}
	if `"`__ergm_t1'"' == "simulate" {
		gettoken __ergm_sub 0 : 0, parse(" ,")
		gettoken __ergm_first : 0, parse(" ,")
		if `"`__ergm_first'"' == "" | `"`__ergm_first'"' == "," {
			_nwergm_simfit `0'
			exit
		}
		// simulating from a given model builds its own model in the Mata objects of the last fit: the fit is put
		// back afterwards, so that estat gof, nwergm simulate and predict still refer to it
		_nwergm_hold save
		capture noisily nwergm_simulate `0'
		local __ergm_rc = _rc
		_nwergm_hold restore
		exit `__ergm_rc'
	}
	// a fit that is refused leaves the model of the previous fit in place (operator sub-models are handled by
	// _nwergm_ops)
	if strpos(`"`0'"', "submodel(") {
		_nwergm_fit `0'
		exit
	}
	_nwergm_hold save compact
	capture noisily _nwergm_fit `0'
	local __ergm_rc = _rc
	if `__ergm_rc' {
		_nwergm_hold restore
		exit `__ergm_rc'
	}
	_nwergm_hold drop
end

capture program drop _nwergm_fit
program _nwergm_fit, eclass
	version 14
	local __ne_n = 0
	syntax [anything(name=netname)] [, edges mutual ///
		NODEMATCH(string) NODEMATCHDIFF(string) NODECOV(string) NODEICOV(string) NODEOCOV(string) ///
		EDGECOV(string) ABSDIST(string) NODEFACTOR(string) NODEMIX(string) ///
		ABSDIFFCAT(string) DIFF(string) SMALLDIFF(string) SOCIALITY(string) ATTRCOV(string) DYADCOV(string) MM(string) ///
		NODECOVRANGE(string) NODEOCOVRANGE(string) NODEICOVRANGE(string) NODEFACTORDISTINCT(string) NODEOFACTORDISTINCT(string) NODEIFACTORDISTINCT(string) ///
		GWESP(string) GWDSP(string) GWNSP(string) GWDEGREE(string) GWODEGREE(string) GWIDEGREE(string) ///
		GWESPFREE(string) GWDEGREEFREE(string) GWDSPFREE(string) GWODEGREEFREE(string) GWIDEGREEFREE(string) GWNSPFREE(string) ///
		DEGREE(string) ODEGREE(string) IDEGREE(string) CONCURRENT TRIANGLE CTRIPLE ///
		NODEIFACTOR(string) NODEOFACTOR(string) ///
		KSTAR(string) ISTAR(string) OSTAR(string) ///
		DEGRANGE(string) DEGRANGETO(string) ODEGRANGE(string) ODEGRANGETO(string) ///
		IDEGRANGE(string) IDEGRANGETO(string) ESP(string) DSP(string) ///
		TRANSITIVETIES CYCLICALTIES HAMMING(string) SENDER RECEIVER ///
		BCOV1(string) BCOV2(string) BFACTOR1(string) BFACTOR2(string) ///
		BDEGREE1(string) BDEGREE2(string) BSTAR1(string) BSTAR2(string) ///
		BNODEMATCH1(string) BNODEMATCH2(string) BGWDEGREE1(string) BGWDEGREE2(string) ///
		BCONCURRENT1(string) BCONCURRENT2(string) BMINDEGREE1(string) BMINDEGREE2(string) ///
		BDEGRANGE1(string) BDEGRANGE2(string) BCOVRANGE1(string) BCOVRANGE2(string) ///
		BFACTORDISTINCT1(string) BFACTORDISTINCT2(string) BSOCIALITY1(string) BSOCIALITY2(string) ///
		BSTARMIX1(string) BSTARMIX2(string) BTWOSTAR1(string) BTWOSTAR2(string) COINCIDENCE(string) ///
		BDSP1(string) BDSP2(string) BGWDSP1(string) BGWDSP2(string) ///
		BGWDEGREEFREE1(string) BGWDEGREEFREE2(string) BGWDSPFREE1(string) BGWDSPFREE2(string) ///
		TYPE(string) GWCUToff(integer 30) FREEDYADS(string) BLOCKDIAG(string) FIXDENSITY ///
		METHOD(string) MCMCBURNIN(integer -1) MCMCINTERVAL(integer 1024) ///
		MCMCSAMPLESIZE(integer -1) MCMLEITERATIONS(integer 60) ///
		PROPOSAL(string) SEED(string) VERBOSE SPCACHE NOMCMCSAMPLE NONATIVE ///
		OFFSET(string) COEFLABEL(string) LOGSTAT(string) EXPSTAT(string) STRUCTURAL(string asis) OPERATORS(string asis) SUBMODEL(string) NOLOGLIK EXACTLL MCLL BRIDGESTEPS(integer 16) BRIDGESAMPLESIZE(integer 0) BRIDGEINTERVAL(integer 0) ///
		INIT(string) MPLETYPE(string) MPLECHECK(string) MPLECOVariance(string) ESTimate(string) MAINMETHOD(string) ///
		MCMLETERMination(string) MCMLECONFidence(real 0.99) MCMLESTEPLength(real 1) MCMLESTEPMargin(real 0.05) ///
		MCMLEEFFectivesize(real -1) CDNSteps(integer 8) CDSAMPLEsize(integer 0) SABURNin(integer 16384) SAINTERval(integer 1024) SAPHASE3(integer 1000) SAGAIN(real 0.1) SANSUB(integer 4) ///
		CONSTRAINTS(string asis) OBSCONSTRAINTS(string asis) MCMCMAXEDGES(integer 0) MCMCPROP(string asis) ///
		EGOTARGET(string) EGONAMES(string) EGOVT(string) EGOSHIFT(real 0) * ]
	// the target statistics of an egocentric fit (nwergm ego) must not outlive a refused call
	capture mata: mata drop ergm_target
	local __ego = ("`egotarget'" != "")
	if `__ego' local nologlik "nologlik"
	// the options of estimate(bayes) (chains(), burnin(), iterations(), thin(), priormean(), ...) are split off here
	local __bopts
	if `"`options'"' != "" _nwergm_bayes_split __bopts options `"`options'"'
	local __bayes 0
	if lower("`estimate'") == "bayes" | lower("`method'") == "bayes" {
		if "`estimate'" != "" & "`method'" != "" & lower("`estimate'") != lower("`method'") {
			di as err "options estimate() and method() contradict each other; use one of them."
			exit 198
		}
		local __bayes 1
		local method "mcmle"
		local estimate ""
		foreach __bo in mainmethod init constraints obsconstraints structural operators submodel logstat expstat mcmcprop {
			if `"``__bo''"' != "" {
				di as err "{p 0 0 2}estimate(bayes) cannot be combined with option {bf:`__bo'()}.{p_end}"
				exit 198
			}
		}
		foreach __bo in fixdensity nonative {
			if "``__bo''" != "" {
				di as err "{p 0 0 2}estimate(bayes) cannot be combined with option {bf:`__bo'}.{p_end}"
				exit 198
			}
		}
	}
	else if `"`__bopts'"' != "" {
		di as err "{p 0 0 2}the option(s) {bf:`__bopts'} belong to {bf:estimate(bayes)}.{p_end}"
		exit 198
	}
	// display options of the coefficient table (ci, level(), noci, nopvalues, cformat(), ...); any other option is
	// refused here with Stata's usual message
	local __ergm_tabopts `"`options'"'
	_nwergm_tabopts __ergm_chk check, `__ergm_tabopts'
	set more off
	if `"`seed'"' != "" _nwergm_seed `seed', check
	_nwergm_decaycheck, gwesp(`gwesp') gwdsp(`gwdsp') gwnsp(`gwnsp') gwdegree(`gwdegree') gwodegree(`gwodegree') gwidegree(`gwidegree') ///
		gwespfree(`gwespfree') gwdegreefree(`gwdegreefree') gwdspfree(`gwdspfree') gwodegreefree(`gwodegreefree') gwidegreefree(`gwidegreefree') ///
		gwnspfree(`gwnspfree') bgwdegree1(`bgwdegree1') bgwdegree2(`bgwdegree2') bgwdsp1(`bgwdsp1') bgwdsp2(`bgwdsp2') ///
		bgwdegreefree1(`bgwdegreefree1') bgwdegreefree2(`bgwdegreefree2') bgwdspfree1(`bgwdspfree1') bgwdspfree2(`bgwdspfree2')
	// R: MCMLE.burnin = MCMLE.interval * 16 - an unset burn-in follows the interval
	if `mcmcburnin' < 0 local mcmcburnin = 16 * `mcmcinterval'
	local __ergm_cutact 0
	if `gwcutoff' < 1 {
		di as err "{p 0 0 2}option {bf:gwcutoff()} takes an integer of at least 1.{p_end}"
		exit 198
	}
	_nwergm_est opts, estimate(`estimate') method(`method') mainmethod(`mainmethod') mpletype(`mpletype') ///
		mplecovariance(`mplecovariance') mcmletermination(`mcmletermination') mplecheck(`mplecheck')
	local method "`s(method)'"
	local mainmethod "`s(mainmethod)'"
	local mpletype "`s(mpletype)'"
	local mplecovariance "`s(mplecovariance)'"
	local mcmletermination "`s(mcmletermination)'"
	local mplecheck "`s(mplecheck)'"
	// numlist-valued options accept ranges such as degree(0/3), as in R's d=0:3
	foreach __ergm_o in degree odegree idegree kstar ostar istar degrange degrangeto odegrange odegrangeto idegrange idegrangeto esp dsp bdegree1 bdegree2 bstar1 bstar2 {
		if `"``__ergm_o''"' != "" & strpos(`"``__ergm_o''"', ",") == 0 {
			capture numlist "``__ergm_o''"
			if !_rc local `__ergm_o' `r(numlist)'
		}
	}

	// altkstar without fixed is the curved term (R's default): taken out of structural() here
	local __altk 0
	if `"`structural'"' != "" mata: ergm_altk_extract()
	// edges may be left out only when density or meandeg (collinear with it) stands in for it
	local __sub = (`"`submodel'"' != "")
	if `__sub' {
		// a model of an operator term (built by _nwergm_ops): name, term-name base, nodes, directed, twomode ("." = as the network)
		tokenize `submodel'
		local __sub_name "`1'"
		local __ne_n = `2'
	}
	local __ns_noedges = ("`edges'" == "" & (strpos(" " + subinstr(`"`structural'"', "(", " (", .) + " ", " density ") > 0 | strpos(" " + subinstr(`"`structural'"', "(", " (", .) + " ", " meandeg ") > 0))
	if `__sub' & "`edges'" == "" local __ns_noedges 1
	if "`edges'" == "" & !`__ns_noedges' {
		di "{err}option {bf:edges} is required - every v1 nwergm model includes an edges term."
		error 198
	}
	// fixdensity (constraints, third piece - see the development notes'
	// "Constraints beyond v1's free binary dyad space" row): R ergm's
	// own `constraints=~edges'. Unlike freedyads()/blockdiag() (which
	// restrict WHICH single dyad the ordinary proposal may touch),
	// this holds the total tie COUNT invariant via a compound tie/
	// non-tie swap move (ergm_propose_swap()/ErgmMCMCSampleSwap(),
	// unw_ergm.do) - a genuinely different proposal shape, not a masked
	// variant of the existing one, so it cannot be combined with
	// freedyads()/blockdiag() in v1 (each is its own self-contained
	// dyad-space restriction). `edges' itself becomes uninformative
	// under this constraint (its statistic never changes across the
	// whole chain, so it carries zero information about theta) -
	// mimicking real R ergm's own observed behavior here (confirmed
	// directly: R fits `edges' anyway and reports its coefficient fixed
	// at exactly 0 with a "will be ignored" warning) is not attempted
	// via this project's own still-incomplete general isfixed-through-
	// MCMLE machinery (the development notes' own disclosed gap) -
	// instead, `edges' is simply never registered as an estimated term
	// for a fixdensity model (the user must still type `edges' per the
	// check just above, for a consistent model-specification syntax,
	// but at least one OTHER term is required, checked below).
	if "`fixdensity'" != "" {
		if "`freedyads'" != "" | "`blockdiag'" != "" {
			di "{p 0 0 2}{err}fixdensity cannot currently be combined with freedyads()/blockdiag() - v1 supports one dyad-space constraint at a time.{p_end}"
			error 198
		}
		if "`method'" != "" & "`method'" != "mcmle" {
			di "{p 0 0 2}{err}fixdensity requires {bf:method(mcmle)} - a fixed-density fit cannot be a plain MPLE (that never runs MCMC at all, so there is no proposal for the constraint to restrict).{p_end}"
			error 198
		}
		local method "mcmle"
	}
	// freedyads() now has a masked TNT variant too (ergm_propose_tnt_masked(),
	// the development notes' "Constraints beyond v1's free binary dyad
	// space" row) - freedyads() alone no longer needs its own special
	// default, `proposal()' defaults to `tnt' exactly as it does without
	// freedyads().
	if "`proposal'" == "" local proposal "tnt"
	_opts_oneof "uniform random tnt" "proposal" "`proposal'" 198
	if "`proposal'" == "random" local proposal "uniform"
	_nwergm_hints, spec(`mcmcprop')
	if "`method'" != "" {
		_opts_oneof "mple mcmle cd" "method" "`method'" 198
	}
	local __ergm_type_explicit = ("`type'" != "")
	local type = upper("`type'")
	if "`type'" == "" local type "OTP"
	_opts_oneof "OTP ITP OSP ISP RTP" "type" "`type'" 198

	_nwsyntax `netname', max(1)
	// node attributes are read by row position; see _nwrowalign.ado
	if !`__sub' | "`3'" == "." _nwrowalign `netname'
	_nwsyntax `netname', max(1)
	if `"`operators'"' != "" & (`"`constraints'`obsconstraints'"' != "" | "`freedyads'`blockdiag'`fixdensity'" != "") {
		di "{p 0 0 2}{err}operators() cannot be combined with constraints(), obsconstraints(), freedyads(), blockdiag() or fixdensity.{p_end}"
		error 198
	}
	if `__sub' {
		if "`3'" != "." local nodes = `3'
		if "`4'" != "." local directed "`4'"
		if "`5'" != "." local is2mode "`5'"
		if "`freedyads'`blockdiag'`fixdensity'" != "" | `"`constraints'`obsconstraints'"' != "" {
			di "{err}constraints cannot be used inside an operator term."
			error 198
		}
	}

	// --- network-type validation (Part IV/XXII/XXIII/XXIV): reject,
	// never silently reinterpret.
	//
	// Bipartite (two-mode) support (harmonisation unit 155 Stage 1 +
	// unit 156 Stage 2): R's own ergm
	// package requires bipartite networks to be undirected
	// (the development notes:401) - a real modeling constraint (a
	// directed two-mode dyad space has no standard ERGM treatment in
	// the reference implementation this package studies), not a v1
	// simplification - so directed+two-mode is rejected unconditionally
	// below, not merely "not yet implemented". v1's own bipartite term
	// scope is `edges' plus the dyad-independent bcov1()/bcov2()/
	// bfactor1()/bfactor2() family (Stage 2 - Stata option names for R
	// ergm's own b1cov()/b2cov()/b1factor()/b2factor() terms; the digit
	// had to move to the END of the option name because Stata's own
	// `syntax' command rejects any option name with a digit followed by
	// a letter - confirmed directly: a literal `B1COV(string)' syntax
	// declaration fails with "option b1cov() not allowed" at the FIRST
	// call, a genuine Stata-language constraint discovered empirically
	// mid-implementation, not a design choice. Every internal name that
	// is NOT a Stata option identifier - the Mata function names
	// (stat_b1cov()/change_b1cov()/etc.), the term registry's own name
	// string ("b1cov" passed to addterm()), and the fitted coefficient's
	// own display name ("b1cov_<var>") - is NOT subject to this
	// constraint and keeps R's own exact naming, so a fitted model's
	// coefficient table still reads `b1cov_age' etc., matching what an
	// R ergm user would recognize; only the four OPTION names a caller
	// types on the nwergm command line differ.), plus the dyad-
	// DEPENDENT bdegree1()/bdegree2()/bstar1()/bstar2() family (Stage 3,
	// unit 157 - same digit-at-the-end option-name rename, for the same
	// Stata `syntax' reason, as R's own b1degree()/b2degree()/
	// b1star()/b2star()). Every ONE-MODE-ONLY term (mutual/triangle/
	// gwesp/nodematch/nodecov/degree/kstar/etc.) is rejected explicitly
	// so a bipartite model never silently gets a one-mode term's change
	// statistic applied to a rectangular dyad space it was never
	// derived for.
	if "`is2mode'" == "true" & "`directed'" == "true" {
		di "{p 0 0 2}{err}nwergm does not support directed two-mode (bipartite) networks; {bf:`netname'} is directed and two-mode.{p_end}"
		di "{p 0 0 2}{err}Bipartite ERGMs are undirected only, matching the reference implementation this package studies (R's ergm package) - there is no standard directed two-mode dyad-space treatment to fall back to.{p_end}"
		error 198
	}
	if "`is2mode'" == "true" {
		// R's ergm accepts the undirected one-mode terms on a bipartite network (statistics are defined on
		// the whole node set) but refuses the directed-only terms and the one-mode degree distribution terms
		foreach __ergm_bo in mutual nodeicov nodeocov nodeifactor nodeofactor sender receiver odegree idegree ostar istar ctriple odegrange odegrangeto idegrange idegrangeto gwodegree gwidegree gwodegreefree gwidegreefree {
			if `"``__ergm_bo''"' != "" {
				di "{err}In term {bf:`__ergm_bo'}: Term may not be used with networks with directed==FALSE."
				error 198
			}
		}
		foreach __ergm_bo in gwdegree gwdegreefree {
			if `"``__ergm_bo''"' != "" {
				di "{err}In term {bf:`__ergm_bo'}: Term may not be used with networks with bipartite > 0."
				error 198
			}
		if `"`structural'"' != "" {
			di "{p 0 0 2}{err}structural() terms are not available for a two-mode network; use the bipartite terms.{p_end}"
			error 198
		}
		}
	}
	else {
		// bcov1()/bcov2()/bfactor1()/bfactor2()/bdegree1()/bdegree2()/
		// bstar1()/bstar2()/bnodematch1()/bnodematch2()/bgwdegree1()/
		// bgwdegree2() (R ergm's own b1cov()/b2cov()/b1factor()/
		// b2factor()/b1degree()/b2degree()/b1star()/b2star()/
		// b1nodematch()/b2nodematch()/gwb1degree()/gwb2degree()) are
		// bipartite-only by their own real R ergm definition (confirmed
		// directly from R's own current Rd docs before implementing,
		// not guessed: b1cov's own description literally states "This
		// term may only be used with bipartite networks", and
		// b1degree()/b1star()/b1nodematch()/gwb1degree() likewise) -
		// rejected on a one-mode network with the same "reject, never
		// silently reinterpret" discipline `mutual' (directed-only)
		// already uses below.
		local __ergm_bipall ""
		foreach __ergm_bo in bconcurrent1 bconcurrent2 bmindegree1 bmindegree2 bdegrange1 bdegrange2 bcovrange1 bcovrange2 bfactordistinct1 bfactordistinct2 bsociality1 bsociality2 bstarmix1 bstarmix2 btwostar1 btwostar2 coincidence bdsp1 bdsp2 bgwdsp1 bgwdsp2 {
			local __ergm_bipall `"`__ergm_bipall'``__ergm_bo''"'
		}
		if "`__ergm_bipall'" != "" {
			foreach __ergm_bo in bconcurrent1 bconcurrent2 bmindegree1 bmindegree2 bdegrange1 bdegrange2 bcovrange1 bcovrange2 bfactordistinct1 bfactordistinct2 bsociality1 bsociality2 bstarmix1 bstarmix2 btwostar1 btwostar2 coincidence bdsp1 bdsp2 bgwdsp1 bgwdsp2 {
				if `"``__ergm_bo''"' != "" {
					di "{err}In term {bf:`__ergm_bo'}: Term may not be used with networks with bipartite==FALSE."
					error 198
				}
			}
		}
		if "`bcov1'`bcov2'`bfactor1'`bfactor2'`bdegree1'`bdegree2'`bstar1'`bstar2'`bnodematch1'`bnodematch2'`bgwdegree1'`bgwdegree2'" != "" {
			di "{p 0 0 2}{err}options {bf:bcov1()}/{bf:bcov2()}/{bf:bfactor1()}/{bf:bfactor2()}/{bf:bdegree1()}/{bf:bdegree2()}/{bf:bstar1()}/{bf:bstar2()}/{bf:bnodematch1()}/{bf:bnodematch2()}/{bf:bgwdegree1()}/{bf:bgwdegree2()} require a two-mode (bipartite) network; {bf:`netname'} is one-mode.{p_end}"
			di "{p 0 0 2}{err}Use {bf:nodematch()}/{bf:nodecov()}/{bf:nodefactor()}/{bf:degree()}/{bf:kstar()}/{bf:gwdegree()} for a one-mode network's own analogous effect.{p_end}"
			error 198
		}
	}
	if "`istemporal'" == "true" {
		di "{err}nwergm estimates static ERGMs only; {bf:`netname'} carries temporal metadata."
		di "{p 0 0 2}{err}nwergm never silently collapses a temporal network to a single slice - build an explicit static network first (e.g. via nwattime) and estimate on that.{p_end}"
		error 198
	}
	// since nwcommands 3.6.0 the Valued flag is set at creation (a network made with a value variable is valued also when every
	// value is 1); a valued network whose ties all equal 1 holds a binary graph and loses nothing, so it is estimated
	local __ergm_valok = 0
	if "`valued'" == "true" mata: st_local("__ergm_valok", strofreal(`netobj'->get_arcs_count() == 0 | (`netobj'->get_maximum() <= 1 & `netobj'->get_minimum() >= 0 & `netobj'->get_arcs_sum() == `netobj'->get_arcs_count())))
	// a valued network with other tie values is fitted as the binary graph (R: ergm without response= ignores the values; a tie is present when the value is non-zero), with one note
	if "`valued'" == "true" & !`__ergm_valok' & !`__sub' di "{txt}(note: tie values are ignored; the model is fitted to the binary network)"
	if "`mutual'" != "" & "`directed'" != "true" {
		di "{err}option {bf:mutual} requires a directed network; {bf:`netname'} is undirected."
		error 198
	}
	// v1 scope: at most one curved term per model (harmonisation unit
	// 141 - refactored from unit 140's own pairwise "cannot combine
	// with X" checks, which stopped scaling once a 5th curved option
	// (gwodegreefree()/gwidegreefree(), this unit) would have needed
	// 10 pairwise checks total instead of one count). Computed ONCE,
	// before any of the five options' own validation blocks below, so
	// each block can just check `` `__ergm_ncurved' > 1 `` instead of
	// naming every other curved option individually.
	local __ergm_ncurved = ("`gwespfree'"!="") + ("`gwdegreefree'"!="") + ("`gwdspfree'"!="") + ("`gwodegreefree'"!="") + ("`gwidegreefree'"!="") + ("`gwnspfree'"!="") + ("`bgwdegreefree1'`bgwdegreefree2'`bgwdspfree1'`bgwdspfree2'"!="") + `__altk'

	// gwespfree() (harmonisation unit 136 MPLE, unit 138 MCMLE): curved
	// (free-decay) gwesp - the first user-facing curved term. Dyad-
	// dependent like any other gwesp-family term, so method() auto-
	// selection (below, unchanged) already picks mcmle by default and
	// mple only when explicitly requested - no special-casing needed
	// here now that both methods are actually implemented. Directed
	// networks are now supported too, under any of the five type()
	// definitions (harmonisation unit 169 shipped type(OTP) alone
	// first, mirroring gwodegreefree()/gwidegreefree()'s own unit-141
	// precedent that the curved-MPLE pipeline never assumed
	// undirected-ness anywhere; unit 170 widened it to ITP/OSP/ISP/RTP,
	// each individually R-certified - see the development notes unit
	// 170). gwdspfree()/gwnspfree() gained the identical directed
	// extension in unit 171 (see their own registration sites below).
	if "`gwespfree'" != "" {
		if "`gwesp'" != "" {
			di "{p 0 0 2}{err}options {bf:gwesp()} and {bf:gwespfree()} cannot both be specified - a gwesp term is either fixed-decay or curved (free-decay), not both.{p_end}"
			error 198
		}
		if "`esp'" != "" {
			di "{p 0 0 2}{err}options {bf:esp()} and {bf:gwespfree()} cannot both be specified - gwespfree() already spans every achievable shared-partner count, so combining it with an explicit esp() subset would be redundant/collinear.{p_end}"
			error 198
		}
		if `__ergm_ncurved' > 1 {
			di "{p 0 0 2}{err}option {bf:gwespfree()} cannot be combined with another curved option - v1 scope supports at most one curved term per model.{p_end}"
			error 198
		}
		if `nodes' < 3 {
			di "{p 0 0 2}{err}option {bf:gwespfree()} needs at least 3 nodes (gwesp itself needs a real shared-partner count to be achievable).{p_end}"
			error 198
		}
		// method(mcmle) LIFTED (harmonisation unit - Hummel/Hunter/
		// Handcock 2012 steplength): the previous method(mple)-only
		// restriction here was never a scope limitation of the curved
		// plumbing itself (ErgmMCMLE()'s per-iteration eta->theta
		// snap-back, delta-method SEs, missing-value degeneracy guard
		// all already worked) - it was a genuine convergence failure of
		// the OUTER Newton step's damping, which capped the SIZE of the
		// eta-space step but never checked whether the resulting target
		// was a statistic value the MCMC sample actually supported, so
		// it could (and on two independent real networks, did) drive
		// the chain to 0% Metropolis-Hastings acceptance - the same
		// root cause independently confirmed on a plain (non-curved)
		// gwesp() fit too (see the development notes). Replaced with
		// R's own actual mechanism: damp the TARGET STATISTIC (shrink
		// it into the convex hull of what the current MCMC sample
		// explored) rather than the raw parameter step - agnostic to
		// curved vs. non-curved by construction. method() now
		// auto-selects mcmle for a curved term exactly as for any
		// other dyad-dependent term (below); method(mple) remains
		// available too. No longer restricted here - the check that
		// used to force method(mple)/reject method(mcmle) is removed.
	}
	// gwdegreefree() (harmonisation unit 139): curved (free-decay)
	// gwdegree, mirroring gwespfree()'s own exact pattern - reuses the
	// already-certified stat_degree()/change_degree() machinery
	// (degree(d)=0 always contributes exactly zero to the geometric
	// sum by construction, gw_kernel(0,alpha)=exp(alpha)*(1-1)=0
	// regardless of alpha, so d=1..(nodes-1) already covers every
	// value that can matter). method(mple) only, same reasoning as
	// gwespfree(). Undirected v1 scope only, matching gwdegree() itself.
	if "`gwdegreefree'" != "" {
		if "`gwdegree'" != "" {
			di "{p 0 0 2}{err}options {bf:gwdegree()} and {bf:gwdegreefree()} cannot both be specified - a gwdegree term is either fixed-decay or curved (free-decay), not both.{p_end}"
			error 198
		}
		if `__ergm_ncurved' > 1 {
			di "{p 0 0 2}{err}option {bf:gwdegreefree()} cannot be combined with another curved option - v1 scope supports at most one curved term per model.{p_end}"
			error 198
		}
		if "`degree'" != "" {
			di "{p 0 0 2}{err}options {bf:degree()} and {bf:gwdegreefree()} cannot both be specified - gwdegreefree() already spans every achievable degree value, so combining it with an explicit degree() subset would be redundant/collinear.{p_end}"
			error 198
		}
		if "`directed'" == "true" {
			di "{p 0 0 2}{err}option {bf:gwdegreefree()} (v1 scope) is undirected only; {bf:`netname'} is directed. Use {bf:gwodegreefree()}/{bf:gwidegreefree()} for a directed curved model, or {bf:gwodegree()}/{bf:gwidegree()} for a fixed decay.{p_end}"
			error 198
		}
		if `nodes' < 2 {
			di "{err}option {bf:gwdegreefree()} needs at least 2 nodes."
			error 198
		}
		// method(mcmle) LIFTED here too - same fix, see gwespfree()'s
		// own comment above for the full account.
	}
	// gwdspfree() (harmonisation unit 140): curved (free-decay)
	// gwdsp, mirroring gwespfree()'s/gwdegreefree()'s own exact
	// pattern - reuses the already-certified stat_dsp()/change_dsp()
	// machinery directly. Unlike gwesp's own d=1..(nodes-2) range,
	// gwdsp examines shared partners over EVERY dyad (tied or not),
	// but the achievable shared-partner COUNT for any one dyad is
	// still bounded by nodes-2 (every other node is a candidate
	// shared partner) - same maxd formula as gwespfree(), different
	// underlying dyad universe. method(mple) only, same reasoning as
	// the other two curved options. Directed networks, under any of
	// the five type() definitions, supported since harmonisation unit
	// 171 (mirroring gwespfree()'s own unit 169/170 directed rollout -
	// stat_dsp()/change_dsp() already dispatch on td.sptype, unit 91).
	if "`gwdspfree'" != "" {
		if "`gwdsp'" != "" {
			di "{p 0 0 2}{err}options {bf:gwdsp()} and {bf:gwdspfree()} cannot both be specified - a gwdsp term is either fixed-decay or curved (free-decay), not both.{p_end}"
			error 198
		}
		if `__ergm_ncurved' > 1 {
			di "{p 0 0 2}{err}option {bf:gwdspfree()} cannot be combined with another curved option - v1 scope supports at most one curved term per model.{p_end}"
			error 198
		}
		if "`dsp'" != "" {
			di "{p 0 0 2}{err}options {bf:dsp()} and {bf:gwdspfree()} cannot both be specified - gwdspfree() already spans every achievable shared-partner count, so combining it with an explicit dsp() subset would be redundant/collinear.{p_end}"
			error 198
		}
		if `nodes' < 3 {
			di "{p 0 0 2}{err}option {bf:gwdspfree()} needs at least 3 nodes (gwdsp itself needs a real shared-partner count to be achievable).{p_end}"
			error 198
		}
		// method(mcmle) LIFTED here too - same fix, see gwespfree()'s
		// own comment above for the full account.
	}
	// gwnspfree() (harmonisation unit 152): curved (free-decay) gwnsp -
	// the last of the five fixed-decay GW terms this package implements
	// to gain a curved counterpart (gwespfree/gwdegreefree/gwdspfree/
	// gwodegreefree/gwidegreefree already done). Deferred out of the
	// original units 136-141 mechanical-reuse pass because gwnsp itself
	// (unlike gwesp/gwdsp/gwdegree/gwodegree/gwidegree) has no
	// standalone per-count statistic of its own - stat_gwnsp() is a
	// thin composition (stat_gwdsp() - stat_gwesp()) with nothing to
	// hand the curved eta-space machinery directly. This unit added the
	// missing piece, stat_nsp()/change_nsp() (unw_ergm.do), built the
	// same way: nsp(d) = dsp(d) - esp(d), a definitional tautology (a
	// dyad with d shared partners is either tied - esp's own domain -
	// or untied - nsp's own domain - never both, never neither),
	// certified against an independent direct-enumeration oracle before
	// use. Same maxd formula as gwdspfree() (nsp, like dsp, is defined
	// over EVERY dyad, tied or not, but the achievable per-dyad count is
	// still bounded by nodes-2). method(mple) only. Directed networks,
	// under any of the five type() definitions, supported since
	// harmonisation unit 171 (mirroring gwdspfree()'s own same-unit
	// directed rollout - stat_nsp()/change_nsp() inherit td.sptype
	// dispatch for free from stat_dsp()/stat_esp()).
	if "`gwnspfree'" != "" {
		if "`gwnsp'" != "" {
			di "{p 0 0 2}{err}options {bf:gwnsp()} and {bf:gwnspfree()} cannot both be specified - a gwnsp term is either fixed-decay or curved (free-decay), not both.{p_end}"
			error 198
		}
		if `__ergm_ncurved' > 1 {
			di "{p 0 0 2}{err}option {bf:gwnspfree()} cannot be combined with another curved option - v1 scope supports at most one curved term per model.{p_end}"
			error 198
		}
		if `nodes' < 3 {
			di "{p 0 0 2}{err}option {bf:gwnspfree()} needs at least 3 nodes (gwnsp itself needs a real shared-partner count to be achievable).{p_end}"
			error 198
		}
		// method(mcmle) LIFTED here too - same fix, see gwespfree()'s
		// own comment above for the full account.
	}
	// gwodegreefree()/gwidegreefree() (harmonisation unit 141): the
	// first DIRECTED curved terms - every curved option so far
	// (gwespfree/gwdegreefree/gwdspfree) has been undirected-only, but
	// stat_odegree()/change_odegree()/stat_idegree()/change_idegree()
	// already exist (unit 90's own degree-count family) and the whole
	// curved-MPLE pipeline (ErgmCurvedMPLEFit, theta_to_eta, the
	// Jacobian) never actually assumed undirected-ness anywhere - it
	// operates purely on eta-space design-matrix columns, agnostic to
	// what network-level property they came from. Registered under
	// "odegree"/"idegree" respectively; d ranges 1..(nodes-1) (an
	// out-/in-degree is bounded by the number of OTHER nodes, same
	// bound as total degree).
	if "`gwodegreefree'" != "" {
		if "`gwodegree'" != "" {
			di "{p 0 0 2}{err}options {bf:gwodegree()} and {bf:gwodegreefree()} cannot both be specified - a gwodegree term is either fixed-decay or curved (free-decay), not both.{p_end}"
			error 198
		}
		if `__ergm_ncurved' > 1 {
			di "{p 0 0 2}{err}option {bf:gwodegreefree()} cannot be combined with another curved option - v1 scope supports at most one curved term per model.{p_end}"
			error 198
		}
		if "`odegree'" != "" {
			di "{p 0 0 2}{err}options {bf:odegree()} and {bf:gwodegreefree()} cannot both be specified - gwodegreefree() already spans every achievable out-degree value, so combining it with an explicit odegree() subset would be redundant/collinear.{p_end}"
			error 198
		}
		if "`directed'" != "true" {
			di "{p 0 0 2}{err}option {bf:gwodegreefree()} requires a directed network; {bf:`netname'} is undirected. Use {bf:gwdegreefree()} for an undirected network.{p_end}"
			error 198
		}
		if `nodes' < 2 {
			di "{err}option {bf:gwodegreefree()} needs at least 2 nodes."
			error 198
		}
		// method(mcmle) LIFTED here too - same fix, see gwespfree()'s
		// own comment above for the full account.
	}
	if "`gwidegreefree'" != "" {
		if "`gwidegree'" != "" {
			di "{p 0 0 2}{err}options {bf:gwidegree()} and {bf:gwidegreefree()} cannot both be specified - a gwidegree term is either fixed-decay or curved (free-decay), not both.{p_end}"
			error 198
		}
		if `__ergm_ncurved' > 1 {
			di "{p 0 0 2}{err}option {bf:gwidegreefree()} cannot be combined with another curved option - v1 scope supports at most one curved term per model.{p_end}"
			error 198
		}
		if "`idegree'" != "" {
			di "{p 0 0 2}{err}options {bf:idegree()} and {bf:gwidegreefree()} cannot both be specified - gwidegreefree() already spans every achievable in-degree value, so combining it with an explicit idegree() subset would be redundant/collinear.{p_end}"
			error 198
		}
		if "`directed'" != "true" {
			di "{p 0 0 2}{err}option {bf:gwidegreefree()} requires a directed network; {bf:`netname'} is undirected. Use {bf:gwdegreefree()} for an undirected network.{p_end}"
			error 198
		}
		if `nodes' < 2 {
			di "{err}option {bf:gwidegreefree()} needs at least 2 nodes."
			error 198
		}
		// method(mcmle) LIFTED here too - same fix, see gwespfree()'s
		// own comment above for the full account.
	}
	if ("`nodeicov'" != "" | "`nodeocov'" != "") & "`directed'" != "true" {
		di "{p 0 0 2}{err}options {bf:nodeicov()}/{bf:nodeocov()} require a directed network; {bf:`netname'} is undirected.{p_end}"
		error 198
	}
	// gwesp()/gwdsp()/gwnsp()/esp()/dsp() now support directed networks
	// too (harmonisation unit 91) via one of five directed shared-
	// partner definitions - OTP ("outgoing two-path", i->k->j, R ergm's
	// own default), ITP ("incoming two-path", i<-k<-j), OSP ("outgoing
	// shared partner", i->k<-j), ISP ("incoming shared partner",
	// i<-k->j), or RTP ("reciprocated two-path", i<->k<->j - a shared
	// partner only through a mutual tie on each leg) - selected by the
	// shared `type()' option and applied uniformly to every one of these
	// five terms present in the same model (a per-term `type=' the way R
	// ergm's own arglist allows is not offered - nwergm's own
	// option-string convention for these terms is already just a bare
	// decay/numlist, not a nested sub-syntax, and one shared-partner
	// definition per model covers the realistic use case without that
	// added parsing complexity). `nwergm.ado' sets `td.sptype' to the
	// resolved `type' automatically for these terms whenever
	// `directed'=="true", leaving the undirected/UTP path (`td.sptype'
	// left blank) completely untouched for undirected networks -
	// matching R ergm's own documented override ("if and only if the
	// network is undirected, the UTP routine is used ... irrespective of
	// the user's selection"). All five directed types R ergm itself
	// offers are now implemented - none remain outstanding.
	if `__ergm_type_explicit' & "`directed'" != "true" {
		di "{p 0 0 2}{err}note: option {bf:type()} only affects directed networks; {bf:`netname'} is undirected, so the undirected shared-partner definition is used regardless.{p_end}"
	}
	if `__ergm_type_explicit' & "`gwesp'`gwdsp'`gwnsp'`esp'`dsp'`gwespfree'`gwdspfree'`gwnspfree'" == "" {
		di "{p 0 0 2}{err}note: option {bf:type()} has no effect - no {bf:gwesp()}/{bf:gwdsp()}/{bf:gwnsp()}/{bf:esp()}/{bf:dsp()}/{bf:gwespfree()}/{bf:gwdspfree()}/{bf:gwnspfree()} term was requested.{p_end}"
	}
	if ("`gwodegree'" != "" | "`gwidegree'" != "") & "`directed'" != "true" {
		di "{p 0 0 2}{err}options {bf:gwodegree()}/{bf:gwidegree()} require a directed network; {bf:`netname'} is undirected. Use {bf:gwdegree()} for an undirected network.{p_end}"
		error 198
	}
	if "`gwdegree'" != "" & "`directed'" == "true" {
		di "{p 0 0 2}{err}In term {bf:gwdegree}: term may not be used with directed networks. Use {bf:gwodegree()}/{bf:gwidegree()} for a directed network.{p_end}"
		error 198
	}
	if "`degree'" != "" & "`directed'" == "true" {
		di "{p 0 0 2}{err}option {bf:degree()} is undirected only; {bf:`netname'} is directed. Use {bf:odegree()}/{bf:idegree()} for a directed network.{p_end}"
		error 198
	}
	if ("`odegree'" != "" | "`idegree'" != "") & "`directed'" != "true" {
		di "{p 0 0 2}{err}options {bf:odegree()}/{bf:idegree()} require a directed network; {bf:`netname'} is undirected. Use {bf:degree()} for an undirected network.{p_end}"
		error 198
	}
	if "`concurrent'" != "" & "`directed'" == "true" {
		di "{err}option {bf:concurrent} (v1 scope) is undirected only; {bf:`netname'} is directed."
		error 198
	}
	// triangle on a directed network: R's directed triangle (transitive plus cyclic triples), computed by the
	// structural() term triangle
	if "`triangle'" != "" & "`directed'" == "true" {
		local structural `"`structural' triangle"'
		local triangle ""
	}
	if "`ctriple'" != "" & "`directed'" != "true" {
		di "{p 0 0 2}{err}option {bf:ctriple} requires a directed network; {bf:`netname'} is undirected. Use {bf:triangle} for an undirected network.{p_end}"
		error 198
	}
	if ("`nodeifactor'" != "" | "`nodeofactor'" != "") & "`directed'" != "true" {
		di "{p 0 0 2}{err}options {bf:nodeifactor()}/{bf:nodeofactor()} require a directed network; {bf:`netname'} is undirected. Use {bf:nodefactor()} for an undirected network.{p_end}"
		error 198
	}
	if "`kstar'" != "" & "`directed'" == "true" {
		di "{p 0 0 2}{err}option {bf:kstar()} is undirected only; {bf:`netname'} is directed. Use {bf:ostar()}/{bf:istar()} for a directed network.{p_end}"
		error 198
	}
	if ("`ostar'" != "" | "`istar'" != "") & "`directed'" != "true" {
		di "{p 0 0 2}{err}options {bf:ostar()}/{bf:istar()} require a directed network; {bf:`netname'} is undirected. Use {bf:kstar()} for an undirected network.{p_end}"
		error 198
	}
	if "`degrange'" != "" & "`directed'" == "true" {
		di "{p 0 0 2}{err}option {bf:degrange()} is undirected only; {bf:`netname'} is directed. Use {bf:odegrange()}/{bf:idegrange()} for a directed network.{p_end}"
		error 198
	}
	if ("`odegrange'" != "" | "`idegrange'" != "") & "`directed'" != "true" {
		di "{p 0 0 2}{err}options {bf:odegrange()}/{bf:idegrange()} require a directed network; {bf:`netname'} is undirected. Use {bf:degrange()} for an undirected network.{p_end}"
		error 198
	}
	// esp()/dsp() now support directed networks too (wave 5) via the
	// same automatic OTP default as gwesp()/gwdsp()/gwnsp() above.
	if ("`transitiveties'" != "" | "`cyclicalties'" != "") & "`directed'" != "true" {
		di "{p 0 0 2}{err}options {bf:transitiveties}/{bf:cyclicalties} require a directed network; {bf:`netname'} is undirected.{p_end}"
		error 198
	}
	if ("`sender'" != "" | "`receiver'" != "") & "`directed'" != "true" {
		di "{err}options {bf:sender}/{bf:receiver} require a directed network; {bf:`netname'} is undirected."
		error 198
	}

	if `"`seed'"' != "" {
		_nwergm_seed `seed'
	}

	// --- build the ErgmGraph from the current NWdef network (one-time
	// read via the already-established sparse accessors; ErgmGraph
	// itself never touches NWdef again after this point - it is, by
	// design, fully decoupled from NWdef; see unw_ergm.do's own header
	// comment). The bridge itself (ergm_bridge_from_netobj(), defined
	// once at file scope below) lives here, in the .ado integration
	// layer, not in either decoupled Mata subsystem.
	// every Mata-side tempname created below is appended to this list
	// (in expanded, literal-name form) so it can be dropped in one shot
	// at the end of the program - a one-line interactive `mata: X = ...'
	// call creates a permanent, top-level Mata variable that is NEVER
	// garbage-collected on its own (unlike a proper Mata function's own
	// locals), so without this bookkeeping every nwergm call leaks one
	// object per term instance into the ambient Mata workspace. Left
	// unfixed, this eventually collides with Mata objects Stata's own
	// machinery creates internally (e.g. `estimates table'/`esttab'),
	// surfacing as a baffling "Mata object __NNNNNN already exists".
	local __ergm_matatemps ""

	// __nwergm_last_G/__nwergm_last_M are DELIBERATE fixed-name Mata
	// singletons, not tempnames - `estat gof' (nwergm_estat.ado) needs to
	// find this call's own fitted graph/model again later, in a SEPARATE
	// program invocation with no access to this program's own locals.
	// Each new nwergm call replaces (never accumulates) the previous
	// call's singleton, guarded exactly like ergm_bridge_from_netobj()'s
	// own redefinition guard below - this is a single, well-managed
	// object, not the unmanaged per-call accumulation unit 73 fixed.
	if !`__sub' {
		_nwergm_tag clear
		capture mata: mata drop __nwergm_last_G
		mata: __nwergm_last_G = ErgmGraph()
		mata: __nwergm_last_G.init(`nodes', ("`directed'"=="true"))
		mata: ergm_bridge_from_netobj(`netobj', __nwergm_last_G, ("`directed'"=="true"))
	}
	// harmonisation unit 155 (bipartite Stage 1): set_bipartite() is
	// called AFTER ergm_bridge_from_netobj() (order does not matter for
	// correctness - set_bipartite() only touches the new mode fields,
	// never G.elist/G.edgepos - but matches enable_sp_cache()'s own
	// established "opt-in flag set right after the graph is populated"
	// placement below). get_modes() returns a string rowvector of
	// "1"/"2" keyed by NWdef's own node index - the SAME index
	// ergm_bridge_from_netobj() just used via netobj->neighbors(i), so
	// no reordering is needed or performed (this package's own
	// deliberate no-reordering convention - see the approved plan's own
	// "Key architecture decision" section).
	if "`is2mode'" == "true" & !`__sub' {
		mata: __nwergm_last_G.set_bipartite(strtoreal(`netobj'->get_modes())')
	}
	// freedyads(netname) (constraints, first piece - see
	// the development notes' "Constraints beyond v1's free binary dyad
	// space" row): R ergm's own `constraints=~fixallbut(free)` - `free'
	// is a SECOND network whose own ties mark which dyads of `netname'
	// are eligible to vary during MCMC; every dyad NOT tied in `free' is
	// held fixed at its OBSERVED value in `netname' for the rest of this
	// fit. Deliberately only touches __nwergm_last_G (the proposal-time
	// object) via set_dyadmask() below - never __nwergm_last_M or its
	// own full_statistic()/MPLE design-matrix machinery, which must keep
	// reading the network's real observed ties regardless of the mask
	// (a fixed dyad still contributes its true observed state to every
	// term's sufficient statistic; only the MCMC PROPOSAL is restricted
	// from ever touching it) - this is the whole point of "fixed", not
	// "deleted". Same _nwsyntax()-based resolution as edgecov()/hamming()
	// above, reusing get_matrix_mod(0,...) as hamming() does (a binary
	// tie-presence matrix is exactly a boolean eligibility mask).
	if "`freedyads'" != "" {
		local __ergm_fd_n : word count `freedyads'
		if `__ergm_fd_n' > 1 {
			di "{err}freedyads() takes exactly one network (got `__ergm_fd_n': `freedyads'')."
			error 198
		}
		_nwsyntax `freedyads', max(1) other(fd)
		if `fdnodes' != `nodes' {
			di "{err}freedyads() network {bf:`freedyads'} has a different number of nodes than {bf:`netname'}."
			error 198
		}
		mata: __nwergm_last_G.set_dyadmask(*(`fdnetobj'->get_matrix_mod(0,("`directed'"=="true"))))
	}
	// blockdiag(varname) (constraints, second piece - see
	// the development notes' "Constraints beyond v1's free binary dyad
	// space" row): R ergm's own `constraints=~blockdiag(attr)` - `varname'
	// is a categorical node attribute; only same-block dyads (equal
	// varname value) are eligible to vary during MCMC. Builds its own
	// eligibility mask (_ergm_blockdiag_mask()) and feeds it through the
	// EXACT SAME set_dyadmask()/masked-proposal/native machinery
	// freedyads() already uses - not a parallel constraint mechanism.
	// v1 supports one dyad-eligibility constraint at a time (matching
	// freedyads()'s own initial narrow scope) rather than an arbitrary
	// intersection of several.
	if "`blockdiag'" != "" {
		if "`freedyads'" != "" {
			di "{p 0 0 2}{err}blockdiag() cannot currently be combined with freedyads() - v1 supports one dyad-eligibility constraint at a time.{p_end}"
			error 198
		}
		confirm variable `blockdiag'
		mata: __nwergm_last_G.set_dyadmask(_ergm_blockdiag_mask(st_data(1::`nodes', "`blockdiag'")))
	}
	// constraints(): R ergm's constraints= formula (see _nwergm_constr.ado)
	local __con_active 0
	if `"`constraints'"' != "" {
		if "`freedyads'" != "" | "`blockdiag'" != "" | "`fixdensity'" != "" {
			di "{err}constraints() cannot be combined with freedyads(), blockdiag() or fixdensity."
			error 198
		}
		local __con_w "default"
		if "`proposal'" == "uniform" local __con_w "random"
		_nwergm_constr, spec(`constraints') nodes(`nodes') directed(`directed') twomode(`is2mode') matobj(`netobj') weights(`__con_w')
		if "`con_observed'" == "miss" {
			di "{p 0 0 2}{err}constraints(observed) cannot be used on a network with missing dyads: R's ergm stops on it with an internal error ('types' and 'constraints' are not the same length). Use {bf:obsconstraints(observed)}, which fits on the observed dyads and lets only the missing dyads vary.{p_end}"
			error 198
		}
		if "`con_observed'" == "none" di "{p 0 0 2}{txt}Note: network `netname' has no missing dyads, so the {bf:observed} constraint leaves every dyad free (as in R's ergm); the model is fitted without it.{p_end}"
		local __con_active 1
		if `con_hasdyad' mata: __nwergm_last_G.set_dyadmask(__ncon_free)
		mata: __nwergm_c1_par = __ncon_par
		mata: __nwergm_c1_cols = __ncon_cols
		mata: __nwergm_c1_free = __ncon_free
		local __c1_hasdyad `con_hasdyad'
	}
	// the SPDyad proposal (R's default hint .triadic) where R uses it: a one-mode network and the tie/no-tie
	// weighting, without a constraint or with dyad constraints and degree bounds that are not maximum-only bounds
	// (R: SPDyad; with maximum-only bounds BDStratTNT, with the other constraints their own proposals)
	if `__spdstrict' & "`is2mode'" == "true" {
		di as err "{p 0 0 2}The triadic() hint cannot be used with a bipartite network (use .triadic, which R skips on a bipartite network).{p_end}"
		error 198
	}
	local __spd 0
	if `__spdfocus' >= 0 & "`proposal'" == "tnt" & "`is2mode'" != "true" & "`fixdensity'" == "" {
		if !`__con_active' local __spd 1
		else if "`con_code'" == "10" & "`con_maxonly'" != "1" local __spd 1
	}
	local __spdcode = cond(`__spd', 3 + `__spdfocus' / 2, cond("`proposal'" == "tnt", 2, 1))
	if `__spd' mata: __nwergm_last_G.spd_focus = `__spdfocus'
	local __obs_active 0
	local __obs_info 0
	if `__con_active' == 0 local __c1_hasdyad 0
	if `"`obsconstraints'"' != "" {
		if "`freedyads'" != "" | "`blockdiag'" != "" | "`fixdensity'" != "" {
			di "{err}obsconstraints() cannot be combined with freedyads(), blockdiag() or fixdensity."
			error 198
		}
		if "`method'" == "mple" {
			di "{err}obsconstraints() needs {bf:method(mcmle)}."
			error 198
		}
		local method "mcmle"
		local __obs_active 1
		local __obs_spec `"`obsconstraints'"'
		if `"`constraints'"' != "" {
			local __obs_first = substr(strtrim(`"`obsconstraints'"'), 1, 1)
			if "`__obs_first'" == "-" local __obs_spec `"`constraints' `obsconstraints'"'
			else local __obs_spec `"`constraints' + `obsconstraints'"'
		}
		_nwergm_constr, spec(`__obs_spec') nodes(`nodes') directed(`directed') twomode(`is2mode') matobj(`netobj') weights(default) prefix(o)
		if "`ocon_observed'" == "none" di "{p 0 0 2}{txt}Note: network `netname' has no missing dyads, so the {bf:observed} constraint leaves every dyad free (as in R's ergm).{p_end}"
		// R drops an observation constraint that is empty (only `observed' on a network without missing dyads): plain MCMLE
		if "`ocon_observed'" == "none" & `ocon_hasdyad' == 0 & inlist("`ocon_code'", "10", "11") {
			local __obs_active 0
		}
		else {
			capture mata: mata drop __nwergm_obs_G
			mata: __nwergm_obs_G = ErgmGraph()
			mata: __nwergm_obs_G.init(`nodes', ("`directed'"=="true"))
			mata: ergm_bridge_from_netobj(`netobj', __nwergm_obs_G, ("`directed'"=="true"))
			if "`is2mode'" == "true" mata: __nwergm_obs_G.set_bipartite(strtoreal(`netobj'->get_modes())')
			if `ocon_hasdyad' mata: __nwergm_obs_G.set_dyadmask(__ncon_free)
			mata: __nwergm_obs_par = __ncon_par
			mata: __nwergm_obs_cols = __ncon_cols
			// dyad-independent sample spaces: the pseudolikelihood start uses the informative dyads, i.e. those that
			// vary under the constraints but are fixed once the observation constraints are added (R: which="informative")
			if `ocon_dind' {
				if `__con_active' {
					mata: __nwergm_info = __nwergm_c1_free :& !(`=cond(`ocon_hasdyad',"__ncon_free","J(`nodes',`nodes',1)")')
				}
				else {
					mata: __nwergm_info = !(`=cond(`ocon_hasdyad',"__ncon_free","J(`nodes',`nodes',1)")')
				}
				mata: st_local("__obs_info", strofreal(sum(__nwergm_info :* (1 :- I(`nodes'))) > 0))
			}
		}
	}
	// captured HERE, before any MCMC ever runs: __nwergm_last_G's own
	// .nties mutates throughout MCMLE's own simulation (it IS the live
	// MCMC state, not a frozen copy of the observed network - see its
	// own class header comment), so reading e(ties) from it AFTER
	// ErgmMCMLE() returns would report the last SIMULATED tie count, not
	// the true observed one. A genuine bug of exactly this shape existed
	// in this file from unit 72 through unit 75 (`e(ties)` was read from
	// `__nwergm_last_G.nties` after fitting, in the method(mcmle) branch
	// below), caught only once `estat gof` (Part XX) needed a genuinely
	// correct observed density and its own reported "Observed" column
	// didn't match the true network by hand-inspection.
	mata: st_local("__ergm_obsties", strofreal(__nwergm_last_G.nties, "%18.0g"))
	// missing dyads (NA ties): excluded from the pseudolikelihood, imputed for the MCMC start (as R ergm)
	if !`__sub' {
		_nwergm_miss detect, netobj(`netobj') directed(`directed') twomode(`is2mode') nodes(`nodes') netname(`netname')
		local __ergm_nmiss = r(nmiss)
	}
	else local __ergm_nmiss 0
	if `__ergm_nmiss' > 0 & ("`freedyads'" != "" | "`blockdiag'" != "" | "`fixdensity'" != "") {
		di "{p 0 0 2}{err}missing dyads cannot currently be combined with freedyads(), blockdiag() or fixdensity.{p_end}"
		error 198
	}

	// --- spcache (Part XXV performance work, the development notes unit
	// 82/132): the incremental shared-partner cache exists and is fully
	// certified, but is NOT auto-enabled by default - unit 82's own
	// direct A/B benchmarking found it a NET LOSS below roughly degree
	// 30-40 (the realistic case for most fitted sparse models, where
	// TNT's high acceptance rate makes the cache's own per-toggle
	// maintenance cost dominate its O(1) lookup savings). This is the
	// disclosed, deliberate opt-in the roadmap called for: the user, who
	// knows their own network's density, decides. Only the undirected
	// shared-partner definition (`shared_partners()') is cached - the
	// directed OTP/ITP/OSP/ISP/RTP paths use their own dedicated,
	// uncached primitives (see their own header comments), so the option
	// has no effect on a directed network. Applies to BOTH MPLE and
	// MCMLE fits (build_mple_data() toggles the same __nwergm_last_G
	// singleton the MCMC sampler uses, so MPLE's own design-matrix
	// construction benefits identically) - this spcache option itself is
	// still surfaced only on the MCMLE branch below (e(spcache)), a
	// genuinely narrower thing than e(native): spcache only ever helps
	// the Mata build_mple_data() path (native's own MPLE build,
	// harmonisation unit 145, does not use or need the Mata-level
	// shared-partner cache at all, since it never calls
	// common_neighbors()/shared_partners() from Mata in the first
	// place), so an MPLE fit that routes through native has nothing for
	// e(spcache) to report regardless.
	local __ergm_spcache_relevant = ("`gwesp'"!="" | "`gwdsp'"!="" | "`gwnsp'"!="" | "`esp'"!="" | "`dsp'"!="" | "`triangle'"!="" | "`ctriple'"!="")
	local __ergm_spcache_used = 0
	if "`spcache'" != "" {
		if "`directed'" == "true" {
			di "{p 0 0 2}{err}note: option {bf:spcache} has no effect on a directed network; the incremental shared-partner cache only implements the undirected shared-partner definition.{p_end}"
		}
		else if !`__ergm_spcache_relevant' {
			di "{p 0 0 2}{err}note: option {bf:spcache} has no effect without gwesp()/gwdsp()/gwnsp()/esp()/dsp()/triangle/ctriple; none of those terms was requested.{p_end}"
		}
		else {
			mata: __nwergm_last_G.enable_sp_cache()
			local __ergm_spcache_used = 1
		}
	}

	// --- build the model: one addterm() call per requested term.
	capture mata: mata drop __nwergm_last_M
	_nwergm_tag clear
	mata: __nwergm_last_M = ErgmModel()
	mata: __nwergm_last_M.init()

	// fixdensity: `edges' is never registered as an estimated term (see
	// this option's own validation-block comment above for why) - the
	// user still typed `edges' (required, checked above) for a
	// consistent model-specification syntax, it just contributes
	// nothing to the fitted parameter vector.
	if "`fixdensity'" == "" & !`__ns_noedges' {
		local __td_edges "__netd_`++__ne_n'"
		mata: `__td_edges' = ErgmTermData()
		mata: __nwergm_last_M.addterm("edges", 1, &stat_edges(), &change_edges(), `__td_edges', ("edges"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_edges'"
	}

	// bipartite terms with sub-arguments (b*concurrent, b*mindegree, b*degrange, by=/attr= forms, ...): see _nwergm_bip.ado
	local __ergm_bipdep 0
	foreach __ergm_bo in bconcurrent1 bconcurrent2 bmindegree1 bmindegree2 bdegrange1 bdegrange2 bcovrange1 bcovrange2 bfactordistinct1 bfactordistinct2 bstarmix1 bstarmix2 btwostar1 btwostar2 coincidence bdsp1 bdsp2 bgwdsp1 bgwdsp2 bgwdegreefree1 bgwdegreefree2 bgwdspfree1 bgwdspfree2 {
		if `"``__ergm_bo''"' != "" local __ergm_bipdep 1
	}
	foreach __ergm_bo in bdegree1 bdegree2 bstar1 bstar2 bnodematch1 bnodematch2 bgwdegree1 bgwdegree2 {
		if strpos(`"``__ergm_bo''"', ",") > 0 local __ergm_bipdep 1
	}
	if "`is2mode'" == "true" {
		_nwergm_bip, nodes(`nodes') bconcurrent1(`"`bconcurrent1'"') bconcurrent2(`"`bconcurrent2'"') bmindegree1(`"`bmindegree1'"') bmindegree2(`"`bmindegree2'"') bdegrange1(`"`bdegrange1'"') bdegrange2(`"`bdegrange2'"') bdegree1(`"`bdegree1'"') bdegree2(`"`bdegree2'"') bstar1(`"`bstar1'"') bstar2(`"`bstar2'"') bcovrange1(`"`bcovrange1'"') bcovrange2(`"`bcovrange2'"') bfactordistinct1(`"`bfactordistinct1'"') bfactordistinct2(`"`bfactordistinct2'"') bsociality1(`"`bsociality1'"') bsociality2(`"`bsociality2'"') bstarmix1(`"`bstarmix1'"') bstarmix2(`"`bstarmix2'"') btwostar1(`"`btwostar1'"') btwostar2(`"`btwostar2'"') coincidence(`"`coincidence'"') bdsp1(`"`bdsp1'"') bdsp2(`"`bdsp2'"') bgwdsp1(`"`bgwdsp1'"') bgwdsp2(`"`bgwdsp2'"') bnodematch1(`"`bnodematch1'"') bnodematch2(`"`bnodematch2'"') bgwdegree1(`"`bgwdegree1'"') bgwdegree2(`"`bgwdegree2'"') nodemix(`"`nodemix'"')
		local __ergm_matatemps "`__ergm_matatemps' `__ergm_bipnewtemps'"
	}

	if "`mutual'" != "" {
		local __td_mutual "__netd_`++__ne_n'"
		mata: `__td_mutual' = ErgmTermData()
		mata: __nwergm_last_M.addterm("mutual", 1, &stat_mutual(), &change_mutual(), `__td_mutual', ("mutual"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_mutual'"
	}

	if `"`nodematch'"' != "" {
		_nwergm_cov nodematch, spec(`"`nodematch'"') nodes(`nodes') directed(`directed') twomode(`is2mode')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}

	if `"`nodecov'"' != "" {
		_nwergm_cov nodecov, spec(`"`nodecov'"') nodes(`nodes') directed(`directed') twomode(`is2mode')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}

	if `"`nodeicov'"' != "" {
		_nwergm_cov nodeicov, spec(`"`nodeicov'"') nodes(`nodes') directed(`directed') twomode(`is2mode')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}

	if `"`nodeocov'"' != "" {
		_nwergm_cov nodeocov, spec(`"`nodeocov'"') nodes(`nodes') directed(`directed') twomode(`is2mode')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}

	// --- term-expansion wave 1 (harmonisation unit 88): absdist,
	// nodematch(diff=TRUE) (a separate nodematchdiff() option, per this
	// file's own header comment on why a suboption on nodematch() itself
	// was not used), nodefactor, nodemix - see unw_ergm.do's own header
	// comment on these four terms for the full statistical definitions.
	if `"`absdist'"' != "" {
		_nwergm_cov absdist, spec(`"`absdist'"') nodes(`nodes') directed(`directed') twomode(`is2mode')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}

	if `"`nodematchdiff'"' != "" {
		_nwergm_cov nodematchdiff, spec(`"`nodematchdiff'"') nodes(`nodes') directed(`directed') twomode(`is2mode')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}

	if `"`nodefactor'"' != "" {
		_nwergm_cov nodefactor, spec(`"`nodefactor'"') nodes(`nodes') directed(`directed') twomode(`is2mode')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}

	if `"`nodemix'"' != "" {
		_nwergm_cov nodemix, spec(`"`nodemix'"') nodes(`nodes') directed(`directed') twomode(`is2mode')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}
	if `"`absdiffcat'"' != "" {
		_nwergm_cov absdiffcat, spec(`"`absdiffcat'"') nodes(`nodes') directed(`directed') twomode(`is2mode')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}
	if `"`diff'"' != "" {
		_nwergm_cov diff, spec(`"`diff'"') nodes(`nodes') directed(`directed') twomode(`is2mode')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}
	if `"`smalldiff'"' != "" {
		_nwergm_cov smalldiff, spec(`"`smalldiff'"') nodes(`nodes') directed(`directed') twomode(`is2mode')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}
	if `"`sociality'"' != "" {
		_nwergm_cov sociality, spec(`"`sociality'"') nodes(`nodes') directed(`directed') twomode(`is2mode')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}
	if `"`attrcov'"' != "" {
		_nwergm_cov attrcov, spec(`"`attrcov'"') nodes(`nodes') directed(`directed') twomode(`is2mode')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}
	if `"`mm'"' != "" {
		_nwergm_cov mm, spec(`"`mm'"') nodes(`nodes') directed(`directed') twomode(`is2mode')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}
	if `"`nodecovrange'"' != "" {
		_nwergm_cov nodecovrange, spec(`"`nodecovrange'"') nodes(`nodes') directed(`directed') twomode(`is2mode')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}
	if `"`nodeocovrange'"' != "" {
		_nwergm_cov nodeocovrange, spec(`"`nodeocovrange'"') nodes(`nodes') directed(`directed') twomode(`is2mode')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}
	if `"`nodeicovrange'"' != "" {
		_nwergm_cov nodeicovrange, spec(`"`nodeicovrange'"') nodes(`nodes') directed(`directed') twomode(`is2mode')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}
	if `"`nodefactordistinct'"' != "" {
		_nwergm_cov nodefactordistinct, spec(`"`nodefactordistinct'"') nodes(`nodes') directed(`directed') twomode(`is2mode')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}
	if `"`nodeofactordistinct'"' != "" {
		_nwergm_cov nodeofactordistinct, spec(`"`nodeofactordistinct'"') nodes(`nodes') directed(`directed') twomode(`is2mode')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}
	if `"`nodeifactordistinct'"' != "" {
		_nwergm_cov nodeifactordistinct, spec(`"`nodeifactordistinct'"') nodes(`nodes') directed(`directed') twomode(`is2mode')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}

	// --- bipartite (two-mode) Stage 2 terms (harmonisation unit 156):
	// bcov1()/bcov2() (R ergm's own b1cov()/b2cov(), renamed as Stata
	// options only - see the network-type validation block above for
	// why) mirror nodecov()'s own exact registration pattern (one
	// coefficient per requested variable, dyad-independent);
	// bfactor1()/bfactor2() (R's b1factor()/b2factor()) mirror
	// nodefactor()'s own exact pattern (one coefficient per non-base
	// level, `_ergm_drop_base_level()' - see nodefactor()'s own header
	// comment above for why the base level is dropped: the full-level
	// parameterization is exactly collinear with `edges'). The
	// network-type validation above already guarantees these four are
	// only ever registered when `is2mode'=="true". Every internal name
	// below (the `addterm()' registry name, the fitted coefficient's
	// own display name) intentionally keeps R's exact "b1cov"/"b2cov"/
	// "b1factor"/"b2factor" spelling - only the OPTION name differs.
	local __ergm_termidx = 0
	foreach __ergm_v of local bcov1 {
		_nwergm_numvar `__ergm_v' bcov1
		local ++__ergm_termidx
		local __td_b1c`__ergm_termidx' "__netd_`++__ne_n'"
		mata: `__td_b1c`__ergm_termidx'' = ErgmTermData()
		mata: `__td_b1c`__ergm_termidx''.attr = st_data(1::`nodes', "`__ergm_v'")
		mata: __nwergm_last_M.addterm("b1cov", 1, &stat_b1cov(), &change_b1cov(), `__td_b1c`__ergm_termidx'', ("b1cov_`__ergm_v'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_b1c`__ergm_termidx''"
	}

	local __ergm_termidx = 0
	foreach __ergm_v of local bcov2 {
		_nwergm_numvar `__ergm_v' bcov2
		local ++__ergm_termidx
		local __td_b2c`__ergm_termidx' "__netd_`++__ne_n'"
		mata: `__td_b2c`__ergm_termidx'' = ErgmTermData()
		mata: `__td_b2c`__ergm_termidx''.attr = st_data(1::`nodes', "`__ergm_v'")
		mata: __nwergm_last_M.addterm("b2cov", 1, &stat_b2cov(), &change_b2cov(), `__td_b2c`__ergm_termidx'', ("b2cov_`__ergm_v'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_b2c`__ergm_termidx''"
	}

	local __ergm_termidx = 0
	foreach __ergm_v of local bfactor1 {
		_nwergm_numvar `__ergm_v' bfactor1
		local ++__ergm_termidx
		local __td_b1f`__ergm_termidx' "__netd_`++__ne_n'"
		mata: `__td_b1f`__ergm_termidx'' = ErgmTermData()
		mata: `__td_b1f`__ergm_termidx''.attr = st_data(1::`nodes', "`__ergm_v'")
		// BUGFIX (harmonisation unit 156, caught via a real end-to-end
		// smoke test, not by inspection): the level set must be built
		// from the MODE-1 nodes' own attribute values only, never the
		// full node vector `nodefactor()' correctly uses (every node
		// contributes to plain nodefactor's own credit, but only
		// mode-1 nodes ever contribute to b1factor's). The covariate is
		// typically left missing (.) for the OTHER mode's nodes (it has
		// no meaning there) - reading the full vector via uniqrows()
		// picked up "." itself as a spurious extra "level" (Mata sorts
		// missing after every real value), producing a bogus
		// `b1factor_<var>_.' coefficient column no real dyad could ever
		// activate. Confirmed directly: a bipartite smoke test with
		// `grp' defined only on the 6 mode-1 nodes (missing on the 4
		// mode-2 nodes) produced levels (1, 2, .) instead of (1, 2).
		mata: `__td_b1f`__ergm_termidx''.levels = uniqrows(`__td_b1f`__ergm_termidx''.attr[__nwergm_last_G.mode1nodes])
		mata: `__td_b1f`__ergm_termidx''.levels = _ergm_drop_base_level(`__td_b1f`__ergm_termidx''.levels)
		mata: st_local("__ergm_nlev", strofreal(rows(`__td_b1f`__ergm_termidx''.levels)))
		tempname __ergm_levvec_b1f
		mata: st_matrix("`__ergm_levvec_b1f'", `__td_b1f`__ergm_termidx''.levels')
		local __ergm_cnames ""
		forvalues __k = 1/`__ergm_nlev' {
			local __ergm_cnames "`__ergm_cnames' b1factor_`__ergm_v'_`=`__ergm_levvec_b1f'[1,`__k']'"
		}
		mata: __nwergm_last_M.addterm("b1factor", `__ergm_nlev', &stat_b1factor(), &change_b1factor(), `__td_b1f`__ergm_termidx'', tokens("`__ergm_cnames'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_b1f`__ergm_termidx''"
	}

	local __ergm_termidx = 0
	foreach __ergm_v of local bfactor2 {
		_nwergm_numvar `__ergm_v' bfactor2
		local ++__ergm_termidx
		local __td_b2f`__ergm_termidx' "__netd_`++__ne_n'"
		mata: `__td_b2f`__ergm_termidx'' = ErgmTermData()
		mata: `__td_b2f`__ergm_termidx''.attr = st_data(1::`nodes', "`__ergm_v'")
		// BUGFIX: mode-2 mirror of b1factor()'s own fix above - see its
		// comment for the full account.
		mata: `__td_b2f`__ergm_termidx''.levels = uniqrows(`__td_b2f`__ergm_termidx''.attr[__nwergm_last_G.mode2nodes])
		mata: `__td_b2f`__ergm_termidx''.levels = _ergm_drop_base_level(`__td_b2f`__ergm_termidx''.levels)
		mata: st_local("__ergm_nlev", strofreal(rows(`__td_b2f`__ergm_termidx''.levels)))
		tempname __ergm_levvec_b2f
		mata: st_matrix("`__ergm_levvec_b2f'", `__td_b2f`__ergm_termidx''.levels')
		local __ergm_cnames ""
		forvalues __k = 1/`__ergm_nlev' {
			local __ergm_cnames "`__ergm_cnames' b2factor_`__ergm_v'_`=`__ergm_levvec_b2f'[1,`__k']'"
		}
		mata: __nwergm_last_M.addterm("b2factor", `__ergm_nlev', &stat_b2factor(), &change_b2factor(), `__td_b2f`__ergm_termidx'', tokens("`__ergm_cnames'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_b2f`__ergm_termidx''"
	}

	// --- bipartite (two-mode) Stage 3 terms (harmonisation unit 157):
	// bdegree1()/bdegree2()/bstar1()/bstar2() (R ergm's own b1degree()/
	// b2degree()/b1star()/b2star(), Stata-option-name-renamed for the
	// same reason as Stage 2's own bcov1()/etc. - see the network-type
	// validation block above) mirror degree()'s/kstar()'s own exact
	// registration pattern (`strtoreal(tokens(...))'' for the numlist).
	// Dyad-DEPENDENT (see unw_ergm.do's own header comment on this
	// family) - deliberately NOT added to the `__ergm_dind' MPLE-
	// eligibility check below (mirrors how plain degree()/kstar() are
	// excluded from it too), so a bipartite model using any of these
	// four correctly defaults to method(mcmle), exercising the Stage-1
	// bipartite MCMC proposal for real.
	if "`bdegree1'" != "" {
		local __td_bd1 "__netd_`++__ne_n'"
		mata: `__td_bd1' = ErgmTermData()
		mata: `__td_bd1'.levels = strtoreal(tokens("`bdegree1'"))'
		mata: st_local("__ergm_ndeg", strofreal(rows(`__td_bd1'.levels)))
		local __ergm_cnames ""
		foreach __ergm_dv of numlist `bdegree1' {
			local __ergm_cnames "`__ergm_cnames' b1degree_`__ergm_dv'"
		}
		mata: __nwergm_last_M.addterm("b1degree", `__ergm_ndeg', &stat_b1degree(), &change_b1degree(), `__td_bd1', tokens("`__ergm_cnames'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_bd1'"
	}
	if "`bdegree2'" != "" {
		local __td_bd2 "__netd_`++__ne_n'"
		mata: `__td_bd2' = ErgmTermData()
		mata: `__td_bd2'.levels = strtoreal(tokens("`bdegree2'"))'
		mata: st_local("__ergm_ndeg", strofreal(rows(`__td_bd2'.levels)))
		local __ergm_cnames ""
		foreach __ergm_dv of numlist `bdegree2' {
			local __ergm_cnames "`__ergm_cnames' b2degree_`__ergm_dv'"
		}
		mata: __nwergm_last_M.addterm("b2degree", `__ergm_ndeg', &stat_b2degree(), &change_b2degree(), `__td_bd2', tokens("`__ergm_cnames'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_bd2'"
	}
	if "`bstar1'" != "" {
		local __td_bs1 "__netd_`++__ne_n'"
		mata: `__td_bs1' = ErgmTermData()
		mata: `__td_bs1'.levels = strtoreal(tokens("`bstar1'"))'
		mata: st_local("__ergm_nk", strofreal(rows(`__td_bs1'.levels)))
		local __ergm_cnames ""
		foreach __ergm_kv of numlist `bstar1' {
			local __ergm_cnames "`__ergm_cnames' b1star_`__ergm_kv'"
		}
		mata: __nwergm_last_M.addterm("b1star", `__ergm_nk', &stat_b1star(), &change_b1star(), `__td_bs1', tokens("`__ergm_cnames'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_bs1'"
	}
	if "`bstar2'" != "" {
		local __td_bs2 "__netd_`++__ne_n'"
		mata: `__td_bs2' = ErgmTermData()
		mata: `__td_bs2'.levels = strtoreal(tokens("`bstar2'"))'
		mata: st_local("__ergm_nk", strofreal(rows(`__td_bs2'.levels)))
		local __ergm_cnames ""
		foreach __ergm_kv of numlist `bstar2' {
			local __ergm_cnames "`__ergm_cnames' b2star_`__ergm_kv'"
		}
		mata: __nwergm_last_M.addterm("b2star", `__ergm_nk', &stat_b2star(), &change_b2star(), `__td_bs2', tokens("`__ergm_cnames'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_bs2'"
	}

	// --- bipartite (two-mode) Stage 4 terms (harmonisation unit 162):
	// bnodematch1()/bnodematch2() (R ergm's own b1nodematch()/
	// b2nodematch(), default-parameter scope only - no diff()/alpha()/
	// beta()/byb2attr()/byb1attr(), a disclosed scope decision, see
	// unw_ergm.do's own header comment on these terms for the full
	// account and the real-R-output validation this derivation was
	// checked against) and bgwdegree1()/bgwdegree2() (R's own
	// gwb1degree()/gwb2degree(), FIXED-decay only - same v1 scope note
	// as plain gwdegree() above). Both families are genuinely dyad-
	// DEPENDENT (a same-attribute two-star count, or a GW-weighted
	// degree sum, both react to more than just the toggled dyad's own
	// two endpoints - see unw_ergm.do), so neither is added to the
	// MPLE-eligibility check below, matching plain kstar()/gwdegree()'s
	// own treatment exactly.
	local __ergm_termidx = 0
	foreach __ergm_v of local bnodematch1 {
		_nwergm_numvar `__ergm_v' bnodematch1
		local ++__ergm_termidx
		local __td_b1nm`__ergm_termidx' "__netd_`++__ne_n'"
		mata: `__td_b1nm`__ergm_termidx'' = ErgmTermData()
		mata: `__td_b1nm`__ergm_termidx''.attr = st_data(1::`nodes', "`__ergm_v'")
		mata: __nwergm_last_M.addterm("b1nodematch", 1, &stat_b1nodematch(), &change_b1nodematch(), `__td_b1nm`__ergm_termidx'', ("b1nodematch_`__ergm_v'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_b1nm`__ergm_termidx''"
	}
	local __ergm_termidx = 0
	foreach __ergm_v of local bnodematch2 {
		_nwergm_numvar `__ergm_v' bnodematch2
		local ++__ergm_termidx
		local __td_b2nm`__ergm_termidx' "__netd_`++__ne_n'"
		mata: `__td_b2nm`__ergm_termidx'' = ErgmTermData()
		mata: `__td_b2nm`__ergm_termidx''.attr = st_data(1::`nodes', "`__ergm_v'")
		mata: __nwergm_last_M.addterm("b2nodematch", 1, &stat_b2nodematch(), &change_b2nodematch(), `__td_b2nm`__ergm_termidx'', ("b2nodematch_`__ergm_v'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_b2nm`__ergm_termidx''"
	}
	if "`bgwdegree1'" != "" {
		local __td_bgwd1 "__netd_`++__ne_n'"
		mata: `__td_bgwd1' = ErgmTermData()
		mata: `__td_bgwd1'.decay = `bgwdegree1'
		mata: __nwergm_last_M.addterm("bgwdegree1", 1, &stat_bgwdegree1(), &change_bgwdegree1(), `__td_bgwd1', ("bgwdegree1_`bgwdegree1'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_bgwd1'"
	}
	if "`bgwdegree2'" != "" {
		local __td_bgwd2 "__netd_`++__ne_n'"
		mata: `__td_bgwd2' = ErgmTermData()
		mata: `__td_bgwd2'.decay = `bgwdegree2'
		mata: __nwergm_last_M.addterm("bgwdegree2", 1, &stat_bgwdegree2(), &change_bgwdegree2(), `__td_bgwd2', ("bgwdegree2_`bgwdegree2'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_bgwd2'"
	}

	// --- term-expansion wave 2 (harmonisation unit 90): degree(numlist)/
	// odegree(numlist)/idegree(numlist), concurrent, triangle, ctriple -
	// see unw_ergm.do's own header comment on these terms for the full
	// statistical definitions and R-ergm cross-checks. All dyad-
	// DEPENDENT (each depends on more than just its own two endpoints'
	// attributes), so none of these are added to the MPLE-eligibility
	// check below - matching mutual/every geometrically-weighted term.
	if "`degree'" != "" {
		local __td_deg "__netd_`++__ne_n'"
		mata: `__td_deg' = ErgmTermData()
		mata: `__td_deg'.levels = strtoreal(tokens("`degree'"))'
		mata: st_local("__ergm_ndeg", strofreal(rows(`__td_deg'.levels)))
		local __ergm_cnames ""
		foreach __ergm_dv of numlist `degree' {
			local __ergm_cnames "`__ergm_cnames' degree_`__ergm_dv'"
		}
		mata: __nwergm_last_M.addterm("degree", `__ergm_ndeg', &stat_degree(), &change_degree(), `__td_deg', tokens("`__ergm_cnames'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_deg'"
	}
	if "`odegree'" != "" {
		local __td_odeg "__netd_`++__ne_n'"
		mata: `__td_odeg' = ErgmTermData()
		mata: `__td_odeg'.levels = strtoreal(tokens("`odegree'"))'
		mata: st_local("__ergm_ndeg", strofreal(rows(`__td_odeg'.levels)))
		local __ergm_cnames ""
		foreach __ergm_dv of numlist `odegree' {
			local __ergm_cnames "`__ergm_cnames' odegree_`__ergm_dv'"
		}
		mata: __nwergm_last_M.addterm("odegree", `__ergm_ndeg', &stat_odegree(), &change_odegree(), `__td_odeg', tokens("`__ergm_cnames'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_odeg'"
	}
	if "`idegree'" != "" {
		local __td_ideg "__netd_`++__ne_n'"
		mata: `__td_ideg' = ErgmTermData()
		mata: `__td_ideg'.levels = strtoreal(tokens("`idegree'"))'
		mata: st_local("__ergm_ndeg", strofreal(rows(`__td_ideg'.levels)))
		local __ergm_cnames ""
		foreach __ergm_dv of numlist `idegree' {
			local __ergm_cnames "`__ergm_cnames' idegree_`__ergm_dv'"
		}
		mata: __nwergm_last_M.addterm("idegree", `__ergm_ndeg', &stat_idegree(), &change_idegree(), `__td_ideg', tokens("`__ergm_cnames'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_ideg'"
	}
	if "`concurrent'" != "" {
		local __td_conc "__netd_`++__ne_n'"
		mata: `__td_conc' = ErgmTermData()
		mata: __nwergm_last_M.addterm("concurrent", 1, &stat_concurrent(), &change_concurrent(), `__td_conc', ("concurrent"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_conc'"
	}
	if "`triangle'" != "" {
		local __td_tri "__netd_`++__ne_n'"
		mata: `__td_tri' = ErgmTermData()
		mata: __nwergm_last_M.addterm("triangle", 1, &stat_triangle(), &change_triangle(), `__td_tri', ("triangle"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_tri'"
	}
	if "`ctriple'" != "" {
		local __td_ctri "__netd_`++__ne_n'"
		mata: `__td_ctri' = ErgmTermData()
		mata: __nwergm_last_M.addterm("ctriple", 1, &stat_ctriple(), &change_ctriple(), `__td_ctri', ("ctriple"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_ctri'"
	}

	// --- term-expansion wave 3 (harmonisation unit 91): nodeifactor()/
	// nodeofactor() (directed analogues of nodefactor(), same base-level
	// omission), kstar()/istar()/ostar() (general k-star family, k as a
	// numlist), degrange()/odegrange()/idegrange() (semi-open-interval
	// degree counts, from()/to() as paired numlists).
	if `"`nodeofactor'"' != "" {
		_nwergm_cov nodeofactor, spec(`"`nodeofactor'"') nodes(`nodes') directed(`directed') twomode(`is2mode')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}
	if `"`nodeifactor'"' != "" {
		_nwergm_cov nodeifactor, spec(`"`nodeifactor'"') nodes(`nodes') directed(`directed') twomode(`is2mode')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}

	if "`kstar'" != "" {
		local __td_kstar "__netd_`++__ne_n'"
		mata: `__td_kstar' = ErgmTermData()
		mata: `__td_kstar'.levels = strtoreal(tokens("`kstar'"))'
		mata: st_local("__ergm_nk", strofreal(rows(`__td_kstar'.levels)))
		local __ergm_cnames ""
		foreach __ergm_kv of numlist `kstar' {
			local __ergm_cnames "`__ergm_cnames' kstar_`__ergm_kv'"
		}
		mata: __nwergm_last_M.addterm("kstar", `__ergm_nk', &stat_kstar(), &change_kstar(), `__td_kstar', tokens("`__ergm_cnames'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_kstar'"
	}
	if "`ostar'" != "" {
		local __td_ostar "__netd_`++__ne_n'"
		mata: `__td_ostar' = ErgmTermData()
		mata: `__td_ostar'.levels = strtoreal(tokens("`ostar'"))'
		mata: st_local("__ergm_nk", strofreal(rows(`__td_ostar'.levels)))
		local __ergm_cnames ""
		foreach __ergm_kv of numlist `ostar' {
			local __ergm_cnames "`__ergm_cnames' ostar_`__ergm_kv'"
		}
		mata: __nwergm_last_M.addterm("ostar", `__ergm_nk', &stat_ostar(), &change_ostar(), `__td_ostar', tokens("`__ergm_cnames'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_ostar'"
	}
	if "`istar'" != "" {
		local __td_istar "__netd_`++__ne_n'"
		mata: `__td_istar' = ErgmTermData()
		mata: `__td_istar'.levels = strtoreal(tokens("`istar'"))'
		mata: st_local("__ergm_nk", strofreal(rows(`__td_istar'.levels)))
		local __ergm_cnames ""
		foreach __ergm_kv of numlist `istar' {
			local __ergm_cnames "`__ergm_cnames' istar_`__ergm_kv'"
		}
		mata: __nwergm_last_M.addterm("istar", `__ergm_nk', &stat_istar(), &change_istar(), `__td_istar', tokens("`__ergm_cnames'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_istar'"
	}

	if "`degrange'" != "" {
		local __ergm_ndr : word count `degrange'
		if "`degrangeto'" == "" {
			local __ergm_dto ""
			forvalues __k = 1/`__ergm_ndr' {
				local __ergm_dto "`__ergm_dto' ."
			}
		}
		else {
			local __ergm_dto "`degrangeto'"
			local __ergm_ndto : word count `degrangeto'
			if `__ergm_ndto' != `__ergm_ndr' {
				di "{err}degrange() and degrangeto() must supply the same number of values."
				error 198
			}
		}
		local __td_dr "__netd_`++__ne_n'"
		mata: `__td_dr' = ErgmTermData()
		mata: `__td_dr'.levelpairs = strtoreal(tokens("`degrange'"))' , strtoreal(tokens("`__ergm_dto'"))'
		local __ergm_cnames ""
		forvalues __k = 1/`__ergm_ndr' {
			local __ergm_cnames "`__ergm_cnames' degrange_`__k'"
		}
		mata: __nwergm_last_M.addterm("degrange", `__ergm_ndr', &stat_degrange(), &change_degrange(), `__td_dr', tokens("`__ergm_cnames'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_dr'"
	}
	if "`odegrange'" != "" {
		local __ergm_ndr : word count `odegrange'
		if "`odegrangeto'" == "" {
			local __ergm_dto ""
			forvalues __k = 1/`__ergm_ndr' {
				local __ergm_dto "`__ergm_dto' ."
			}
		}
		else {
			local __ergm_dto "`odegrangeto'"
			local __ergm_ndto : word count `odegrangeto'
			if `__ergm_ndto' != `__ergm_ndr' {
				di "{err}odegrange() and odegrangeto() must supply the same number of values."
				error 198
			}
		}
		local __td_odr "__netd_`++__ne_n'"
		mata: `__td_odr' = ErgmTermData()
		mata: `__td_odr'.levelpairs = strtoreal(tokens("`odegrange'"))' , strtoreal(tokens("`__ergm_dto'"))'
		local __ergm_cnames ""
		forvalues __k = 1/`__ergm_ndr' {
			local __ergm_cnames "`__ergm_cnames' odegrange_`__k'"
		}
		mata: __nwergm_last_M.addterm("odegrange", `__ergm_ndr', &stat_odegrange(), &change_odegrange(), `__td_odr', tokens("`__ergm_cnames'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_odr'"
	}
	if "`idegrange'" != "" {
		local __ergm_ndr : word count `idegrange'
		if "`idegrangeto'" == "" {
			local __ergm_dto ""
			forvalues __k = 1/`__ergm_ndr' {
				local __ergm_dto "`__ergm_dto' ."
			}
		}
		else {
			local __ergm_dto "`idegrangeto'"
			local __ergm_ndto : word count `idegrangeto'
			if `__ergm_ndto' != `__ergm_ndr' {
				di "{err}idegrange() and idegrangeto() must supply the same number of values."
				error 198
			}
		}
		local __td_idr "__netd_`++__ne_n'"
		mata: `__td_idr' = ErgmTermData()
		mata: `__td_idr'.levelpairs = strtoreal(tokens("`idegrange'"))' , strtoreal(tokens("`__ergm_dto'"))'
		local __ergm_cnames ""
		forvalues __k = 1/`__ergm_ndr' {
			local __ergm_cnames "`__ergm_cnames' idegrange_`__k'"
		}
		mata: __nwergm_last_M.addterm("idegrange", `__ergm_ndr', &stat_idegrange(), &change_idegrange(), `__td_idr', tokens("`__ergm_cnames'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_idr'"
	}

	// --- term-expansion wave 4 (harmonisation unit 91 continuation):
	// esp(d)/dsp(d), fixed non-geometric shared-partner-count terms.
	// Wave 5 extended these (and gwesp/gwdsp/gwnsp below) to directed
	// networks via R ergm's own default directed shared-partner
	// definition (OTP) - `td.sptype' is set to "OTP" automatically
	// whenever the network is directed, left blank (UTP) otherwise.
	if "`esp'" != "" {
		local __ergm_nd : word count `esp'
		local __td_esp "__netd_`++__ne_n'"
		mata: `__td_esp' = ErgmTermData()
		mata: `__td_esp'.levels = strtoreal(tokens("`esp'"))'
		if "`directed'" == "true" {
			mata: `__td_esp'.sptype = "`type'"
		}
		local __ergm_cnames ""
		foreach __ergm_dv of numlist `esp' {
			local __ergm_cnames "`__ergm_cnames' esp`__ergm_dv'"
		}
		mata: __nwergm_last_M.addterm("esp", `__ergm_nd', &stat_esp(), &change_esp(), `__td_esp', tokens("`__ergm_cnames'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_esp'"
	}
	if "`dsp'" != "" {
		local __ergm_nd : word count `dsp'
		local __td_dsp "__netd_`++__ne_n'"
		mata: `__td_dsp' = ErgmTermData()
		mata: `__td_dsp'.levels = strtoreal(tokens("`dsp'"))'
		if "`directed'" == "true" {
			mata: `__td_dsp'.sptype = "`type'"
		}
		local __ergm_cnames ""
		foreach __ergm_dv of numlist `dsp' {
			local __ergm_cnames "`__ergm_cnames' dsp`__ergm_dv'"
		}
		mata: __nwergm_last_M.addterm("dsp", `__ergm_nd', &stat_dsp(), &change_dsp(), `__td_dsp', tokens("`__ergm_cnames'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_dsp'"
	}

	// --- term-expansion wave 6 (harmonisation unit 91 continuation):
	// transitiveties/cyclicalties, directed-only, built on wave 5's OTP
	// shared-partner machinery.
	if "`transitiveties'" != "" {
		local __td_tt "__netd_`++__ne_n'"
		mata: `__td_tt' = ErgmTermData()
		mata: __nwergm_last_M.addterm("transitiveties", 1, &stat_transitiveties(), &change_transitiveties(), `__td_tt', ("transitiveties"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_tt'"
	}
	if "`cyclicalties'" != "" {
		local __td_ct "__netd_`++__ne_n'"
		mata: `__td_ct' = ErgmTermData()
		mata: __nwergm_last_M.addterm("cyclicalties", 1, &stat_cyclicalties(), &change_cyclicalties(), `__td_ct', ("cyclicalties"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_ct'"
	}

	// structural() option: the structural terms of R ergm that have no option of their own
	// (parsed and registered by _nwergm_struct.ado)
	local __ns_dep 0
	if `"`structural'"' != "" {
		_nwergm_struct `netname', terms(`structural') nodes(`nodes') directed(`directed') type(`type')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
		local __ns_dep = r(dep)
	}
	// operators() option: Sum, Prod, S, F, NodematchFilter, Symmetrize, Project, I, For, Label (see _nwergm_ops.ado)
	if `"`operators'"' != "" {
		_nwergm_ops `netname', spec(`operators') nodes(`nodes') directed(`directed') twomode(`is2mode') nebase(`__ne_n') type(`=cond(`__ergm_type_explicit', "`type'", "")')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
		local __ns_dep = max(`__ns_dep', r(dep))
		local __ne_n = r(nebase)
	}

	// --- term-expansion wave 7 (harmonisation unit 91 continuation):
	// sender()/receiver() (per-node out-/in-degree fixed effects, base=1
	// omitted, matching R ergm's own default) - a thin convenience
	// wrapper: the node's own identity (1..nodes) IS the "attribute",
	// reusing the already-certified stat_nodeofactor()/stat_nodeifactor()
	// with zero new Mata code.
	if "`sender'" != "" {
		local __td_send "__netd_`++__ne_n'"
		mata: `__td_send' = ErgmTermData()
		mata: `__td_send'.attr = (1::`nodes')
		mata: `__td_send'.levels = (2::`nodes')
		local __ergm_cnames ""
		forvalues __k = 2/`nodes' {
			local __ergm_cnames "`__ergm_cnames' sender`__k'"
		}
		mata: __nwergm_last_M.addterm("sender", `nodes'-1, &stat_nodeofactor(), &change_nodeofactor(), `__td_send', tokens("`__ergm_cnames'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_send'"
	}
	if "`receiver'" != "" {
		local __td_recv "__netd_`++__ne_n'"
		mata: `__td_recv' = ErgmTermData()
		mata: `__td_recv'.attr = (1::`nodes')
		mata: `__td_recv'.levels = (2::`nodes')
		local __ergm_cnames ""
		forvalues __k = 2/`nodes' {
			local __ergm_cnames "`__ergm_cnames' receiver`__k'"
		}
		mata: __nwergm_last_M.addterm("receiver", `nodes'-1, &stat_nodeifactor(), &change_nodeifactor(), `__td_recv', tokens("`__ergm_cnames'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_recv'"
	}

	if `"`edgecov'"' != "" {
		_nwergm_cov edgecov, spec(`"`edgecov'"') nodes(`nodes') directed(`directed') twomode(`is2mode')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}
	if `"`dyadcov'"' != "" {
		_nwergm_cov dyadcov, spec(`"`dyadcov'"') nodes(`nodes') directed(`directed') twomode(`is2mode')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}

	// --- hamming(netname): Hamming distance to a reference network,
	// same _nwsyntax()-based network-name resolution as edgecov() above,
	// but a BINARY reference (get_matrix_mod(0,...), not (1,...) -
	// hamming distance cares only about tie/no-tie agreement, not
	// covariate weight).
	local __ergm_termidx = 0
	foreach __ergm_v of local hamming {
		local ++__ergm_termidx
		local __td_hm`__ergm_termidx' "__netd_`++__ne_n'"
		mata: `__td_hm`__ergm_termidx'' = ErgmTermData()
		_nwsyntax `__ergm_v', max(1) other(hm`__ergm_termidx')
		if `hm`__ergm_termidx'nodes' != `nodes' {
			di "{err}hamming() network {bf:`__ergm_v'} has a different number of nodes than {bf:`netname'}."
			error 198
		}
		mata: `__td_hm`__ergm_termidx''.edgecovmat = *(`hm`__ergm_termidx'netobj'->get_matrix_mod(0,("`directed'"=="true")))
		mata: st_local("__nacov", strofreal(ergm_offdiag_missing(`__td_hm`__ergm_termidx''.edgecovmat)))
		if `__nacov' {
			di "{p 0 0 2}{err}In term {bf:edgecov/hamming}: network {bf:`__ergm_v'} has missing dyads, which is not supported for a dyadic covariate.{p_end}"
			error 416
		}
		mata: __nwergm_last_M.addterm("hamming", 1, &stat_hamming(), &change_hamming(), `__td_hm`__ergm_termidx'', ("hamming_`__ergm_v'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_hm`__ergm_termidx''"
	}

	if "`gwesp'" != "" {
		confirm number `gwesp'
		local __td_gwesp "__netd_`++__ne_n'"
		mata: `__td_gwesp' = ErgmTermData()
		mata: `__td_gwesp'.decay = `gwesp'
		if "`directed'" == "true" {
			mata: `__td_gwesp'.sptype = "`type'"
		}
		mata: __nwergm_last_M.addterm("gwesp", 1, &stat_gwesp(), &change_gwesp(), `__td_gwesp', ("gwesp_`gwesp'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_gwesp'"
		// ErgmGraph::enable_sp_cache() (Part XXV performance work,
		// the development notes unit 82) is DELIBERATELY NOT called here.
		// It was built, exhaustively certified for correctness, wired in,
		// and then measured directly against this suite's own realistic
		// GWESP benchmarks (100-node and 500-node sparse networks) - and
		// found to make BOTH slower (100-node: 23.1s -> 39.3s; a clean,
		// controlled A/B test isolating the cache as the only variable),
		// not faster. Root cause, fully characterized: TNT's own
		// acceptance rate on a FITTED sparse model is very high (83-93%
		// measured directly, not assumed) - so toggle()'s own cache-
		// maintenance cost (paid on nearly every proposal, not
		// occasionally) dominates the cheaper O(1) lookup's own savings
		// at the LOW degree (~4-6) these realistic benchmark networks
		// have. A degree sweep at a matched high acceptance rate found
		// the cache only becomes a net win around degree ~30-40+ (1.6x
		// faster there; 1.6-2x SLOWER at degree 4-20) - well above what
		// either benchmark network has. Kept unwired rather than removed
		// entirely: the machinery itself is correct and useful for
		// genuinely dense networks, just not a good default for the
		// sparse case this package's own realistic test networks
		// represent. See the development notes unit 82 and
		// the development notes' own Performance section for the full,
		// disclosed account - the same "implement, measure, and report
		// honestly even when the obvious optimization does not pan out"
		// discipline this project used for the batch-means variance
		// estimator (unit 80).
	}
	if "`gwdsp'" != "" {
		confirm number `gwdsp'
		local __td_gwdsp "__netd_`++__ne_n'"
		mata: `__td_gwdsp' = ErgmTermData()
		mata: `__td_gwdsp'.decay = `gwdsp'
		if "`directed'" == "true" {
			mata: `__td_gwdsp'.sptype = "`type'"
		}
		mata: __nwergm_last_M.addterm("gwdsp", 1, &stat_gwdsp(), &change_gwdsp(), `__td_gwdsp', ("gwdsp_`gwdsp'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_gwdsp'"
	}
	if "`gwnsp'" != "" {
		confirm number `gwnsp'
		local __td_gwnsp "__netd_`++__ne_n'"
		mata: `__td_gwnsp' = ErgmTermData()
		mata: `__td_gwnsp'.decay = `gwnsp'
		if "`directed'" == "true" {
			mata: `__td_gwnsp'.sptype = "`type'"
		}
		mata: __nwergm_last_M.addterm("gwnsp", 1, &stat_gwnsp(), &change_gwnsp(), `__td_gwnsp', ("gwnsp_`gwnsp'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_gwnsp'"
	}
	if "`gwdegree'" != "" {
		confirm number `gwdegree'
		local __td_gwdeg "__netd_`++__ne_n'"
		mata: `__td_gwdeg' = ErgmTermData()
		mata: `__td_gwdeg'.decay = `gwdegree'
		mata: __nwergm_last_M.addterm("gwdegree", 1, &stat_gwdegree(), &change_gwdegree(), `__td_gwdeg', ("gwdegree_`gwdegree'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_gwdeg'"
	}
	if "`gwodegree'" != "" {
		confirm number `gwodegree'
		local __td_gwod "__netd_`++__ne_n'"
		mata: `__td_gwod' = ErgmTermData()
		mata: `__td_gwod'.decay = `gwodegree'
		mata: __nwergm_last_M.addterm("gwodegree", 1, &stat_gwodegree(), &change_gwodegree(), `__td_gwod', ("gwodegree_`gwodegree'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_gwod'"
	}
	if "`gwidegree'" != "" {
		confirm number `gwidegree'
		local __td_gwid "__netd_`++__ne_n'"
		mata: `__td_gwid' = ErgmTermData()
		mata: `__td_gwid'.decay = `gwidegree'
		mata: __nwergm_last_M.addterm("gwidegree", 1, &stat_gwidegree(), &change_gwidegree(), `__td_gwid', ("gwidegree_`gwidegree'"))
		local __ergm_matatemps "`__ergm_matatemps' `__td_gwid'"
	}
	// gwespfree() (harmonisation unit 136): registered as a curved
	// `esp' term spanning EVERY achievable shared-partner count
	// 1..(nodes-2) - reusing the already-certified stat_esp()/
	// change_esp() machinery directly, not new statistic/change code
	// (curved-ness is an estimation-side property, not a per-term one -
	// see unw_ergm.do's own ErgmModel::curved comment). Deliberately
	// registered LAST (after every other term) so its own 2 theta
	// columns are always the final 2 in theta-space regardless of what
	// else is in the model - the MPLE code below relies on this to
	// build a starting theta without needing a general "find this
	// term's own theta position" accessor.
	if "`gwespfree'" != "" {
		confirm number `gwespfree'
		// Harmonisation unit 145: `nodes-2' is the theoretical worst
		// case (every dyad, on a maximally clustered network, shares
		// partners with every other node) - real networks fall far
		// short of it, and the curved-MPLE Newton-Raphson loop's own
		// cost scales with the SQUARE of this per-count basis width
		// (the development notes unit 145's own profiling: a 418-node
		// real network registered 416 columns for a true maximum
		// edgewise-shared-partner value of 10). Registered at the TRUE
		// maximum reachable edgewise-shared-partner value across every
		// dyad's own change statistic (ergm_graph_max_shared_partners(),
		// unw_ergm.do, PLUS ONE - see that function's own header comment
		// for why the +1 is required: a single dyad's toggle can raise
		// a DIFFERENT, already-adjacent dyad's own shared-partner count
		// by one, not just the toggled dyad's own value, so the network's
		// current true maximum alone is not itself always reachable-safe).
		// Harmonisation unit 169 (type(OTP)), widened to all five types
		// by unit 170: on a directed network the bound instead comes
		// from ergm_graph_max_sp_dir(), the same "+1" reasoning but over
		// the requested type()'s own shared_partners_*() ties rather
		// than the undirected UTP definition.
		if "`directed'" == "true" {
			mata: st_local("__ergm_maxdeg", strofreal(ergm_graph_max_sp_dir(__nwergm_last_G, "`type'") + 1))
		}
		else {
			mata: st_local("__ergm_maxdeg", strofreal(ergm_graph_max_shared_partners(__nwergm_last_G) + 1))
		}
		local __ergm_curved_maxd = max(1, min(`nodes' - 2, `__ergm_maxdeg'))
		// Only the pseudolikelihood is bounded by the observed network (the further counts have a zero change statistic
		// there). Every sampling estimator (MCMLE, Bayes, CD, SA) simulates networks in which a dyad can have more shared
		// partners than in the observed one, up to nodes-2, and a count above the last column of the curved block would be
		// dropped silently (the model would not be the model): these methods use all nodes-2 counts. The same holds for the
		// other curved terms below (nodes-1 for the degree terms).
		local __ergm_cut 0
		if "`method'" != "mple" _nwergm_gwcut esp, name(gwespfree) cutoff(`gwcutoff') full(`=max(1, `nodes' - 2)') sptype(`=cond("`directed'" == "true", "`type'", "")')
		if "`method'" != "mple" local __ergm_curved_maxd = max(1, min(`gwcutoff', `nodes' - 2))
		local __td_gwespfree "__netd_`++__ne_n'"
		mata: `__td_gwespfree' = ErgmTermData()
		mata: `__td_gwespfree'.cutoff = `__ergm_cut'
		mata: `__td_gwespfree'.levels = (1..`__ergm_curved_maxd')'
		// Sets the same td.sptype fixed-decay gwesp() itself sets for a
		// directed network (nwergm.ado:1355 above) - stat_esp()/
		// change_esp() (unw_ergm.do) already dispatch on td.sptype to
		// all five directed definitions, so no new statistic/change
		// code is needed for any of them.
		if "`directed'" == "true" {
			mata: `__td_gwespfree'.sptype = "`type'"
		}
		// addterm()'s own cnames must have length npar (here
		// __ergm_curved_maxd, the ETA-space dimension - one name per
		// achievable shared-partner count) - NOT the 2-dimensional
		// THETA-space this term is ultimately reported in. These names
		// are internal/intermediate only (never shown to the user - the
		// MPLE code below replaces the whole coefficient vector with
		// the 2 theta-space names "gwesp_weight"/"gwesp_decay" before
		// ereturn post), given a distinct "gwespfree_" prefix so they
		// cannot collide with an ordinary esp() term's own "espN" names
		// in any diagnostic that displays them before that replacement.
		local __ergm_curved_cnames ""
		forvalues __k = 1/`__ergm_curved_maxd' {
			local __ergm_curved_cnames "`__ergm_curved_cnames' gwespfree_`__k'"
		}
		mata: __nwergm_last_M.addterm("esp", `__ergm_curved_maxd', &stat_esp(), &change_esp(), `__td_gwespfree', tokens("`__ergm_curved_cnames'"))
		mata: __nwergm_last_M.mark_curved()
		local __ergm_matatemps "`__ergm_matatemps' `__td_gwespfree'"
	}
	// gwdegreefree() (harmonisation unit 139): mirrors gwespfree()'s
	// own exact pattern, registered under "degree" (reusing
	// stat_degree()/change_degree() directly) spanning every
	// achievable degree value 1..(nodes-1) - d=0 is safe to omit
	// entirely, since gw_kernel(0,alpha)=exp(alpha)*(1-1)=0 for any
	// alpha, so it can never contribute to the geometric sum. Also
	// registered LAST (after gwespfree(), which the mutual-exclusivity
	// check above guarantees cannot coexist with this one anyway), for
	// the same "always the final 2 theta columns" reason gwespfree()
	// documents at its own registration site.
	if "`gwdegreefree'" != "" {
		confirm number `gwdegreefree'
		// Harmonisation unit 145: same rationale as gwespfree()'s own
		// registration site above - a single dyad toggle changes
		// exactly one node's own degree by +-1, so no dyad's change
		// statistic can ever touch a degree value above the network's
		// own current maximum degree PLUS ONE (the toggle-on case) -
		// tighter than the theoretical `nodes-1' worst case on any real
		// network that is not itself nearly complete.
		mata: st_local("__ergm_maxdeg", strofreal(ergm_graph_maxdegree(__nwergm_last_G, "total")))
		local __ergm_curved_maxd = max(1, min(`nodes' - 1, `__ergm_maxdeg' + 1))
		local __ergm_cut 0
		if "`method'" != "mple" _nwergm_gwcut deg, name(gwdegreefree) cutoff(`gwcutoff') full(`=max(1, `nodes' - 1)') sptype()
		if "`method'" != "mple" local __ergm_curved_maxd = max(1, min(`gwcutoff', `nodes' - 1))
		local __td_gwdegreefree "__netd_`++__ne_n'"
		mata: `__td_gwdegreefree' = ErgmTermData()
		mata: `__td_gwdegreefree'.cutoff = `__ergm_cut'
		mata: `__td_gwdegreefree'.levels = (1..`__ergm_curved_maxd')'
		local __ergm_curved_cnames ""
		forvalues __k = 1/`__ergm_curved_maxd' {
			local __ergm_curved_cnames "`__ergm_curved_cnames' gwdegreefree_`__k'"
		}
		mata: __nwergm_last_M.addterm("degree", `__ergm_curved_maxd', &stat_degree(), &change_degree(), `__td_gwdegreefree', tokens("`__ergm_curved_cnames'"))
		mata: __nwergm_last_M.mark_curved()
		local __ergm_matatemps "`__ergm_matatemps' `__td_gwdegreefree'"
	}
	// curved bipartite terms (gwb1degree/gwb2degree/gwb1dsp/gwb2dsp with fixed=FALSE in R): see _nwergm_bip.ado
	if "`bgwdegreefree1'`bgwdegreefree2'`bgwdspfree1'`bgwdspfree2'" != "" {
		if "`is2mode'" != "true" {
			di "{p 0 0 2}{err}In term {bf:bgwdegreefree/bgwdspfree}: Term may not be used with networks with bipartite==FALSE.{p_end}"
			error 198
		}
		_nwergm_bip_curved, bgwdegreefree1(`"`bgwdegreefree1'"') bgwdegreefree2(`"`bgwdegreefree2'"') bgwdspfree1(`"`bgwdspfree1'"') bgwdspfree2(`"`bgwdspfree2'"') full(`=("`method'" != "mple")') cutoff(`gwcutoff')
		local __ergm_matatemps "`__ergm_matatemps' `__ergm_bipnewtemps'"
	}
	// gwdspfree() (harmonisation unit 140): mirrors the other two
	// curved options' own exact pattern, registered under "dsp"
	// (reusing stat_dsp()/change_dsp() directly).
	if "`gwdspfree'" != "" {
		confirm number `gwdspfree'
		// Harmonisation unit 145: same TRUE shared-partner-count bound
		// (plus one - see ergm_graph_max_shared_partners()'s own header
		// comment) as gwespfree()'s own registration site above (DSP is
		// the identical common-neighbor concept, evaluated over every
		// dyad rather than only tied ones). Harmonisation unit 171: on a
		// directed network the bound instead comes from
		// ergm_graph_max_sp_dir_all() - the all-dyads counterpart to
		// gwespfree()'s own ties-only ergm_graph_max_sp_dir(), needed
		// here because dsp(d) is defined over every dyad, not just ties.
		if "`directed'" == "true" {
			mata: st_local("__ergm_maxdeg", strofreal(ergm_graph_max_sp_dir_all(__nwergm_last_G, "`type'") + 1))
		}
		else {
			mata: st_local("__ergm_maxdeg", strofreal(ergm_graph_max_shared_partners(__nwergm_last_G) + 1))
		}
		local __ergm_curved_maxd = max(1, min(`nodes' - 2, `__ergm_maxdeg'))
		local __ergm_cut 0
		if "`method'" != "mple" _nwergm_gwcut dsp, name(gwdspfree) cutoff(`gwcutoff') full(`=max(1, `nodes' - 2)') sptype(`=cond("`directed'" == "true", "`type'", "")')
		if "`method'" != "mple" local __ergm_curved_maxd = max(1, min(`gwcutoff', `nodes' - 2))
		local __td_gwdspfree "__netd_`++__ne_n'"
		mata: `__td_gwdspfree' = ErgmTermData()
		mata: `__td_gwdspfree'.cutoff = `__ergm_cut'
		mata: `__td_gwdspfree'.levels = (1..`__ergm_curved_maxd')'
		// Sets td.sptype exactly as gwespfree()'s own registration site
		// does - stat_dsp()/change_dsp() already dispatch on it (unit 91).
		if "`directed'" == "true" {
			mata: `__td_gwdspfree'.sptype = "`type'"
		}
		local __ergm_curved_cnames ""
		forvalues __k = 1/`__ergm_curved_maxd' {
			local __ergm_curved_cnames "`__ergm_curved_cnames' gwdspfree_`__k'"
		}
		mata: __nwergm_last_M.addterm("dsp", `__ergm_curved_maxd', &stat_dsp(), &change_dsp(), `__td_gwdspfree', tokens("`__ergm_curved_cnames'"))
		mata: __nwergm_last_M.mark_curved()
		local __ergm_matatemps "`__ergm_matatemps' `__td_gwdspfree'"
	}
	// gwnspfree() (harmonisation unit 152): mirrors gwdspfree()'s own
	// exact pattern, registered under "nsp" (reusing the new
	// stat_nsp()/change_nsp() - nsp(d) = dsp(d) - esp(d), unw_ergm.do).
	if "`gwnspfree'" != "" {
		confirm number `gwnspfree'
		// same TRUE shared-partner-count bound (plus one) as
		// gwdspfree()'s own registration site - nsp, like dsp, is
		// defined over every dyad (tied or not), so the same bound
		// applies, directed or not.
		if "`directed'" == "true" {
			mata: st_local("__ergm_maxdeg", strofreal(ergm_graph_max_sp_dir_all(__nwergm_last_G, "`type'") + 1))
		}
		else {
			mata: st_local("__ergm_maxdeg", strofreal(ergm_graph_max_shared_partners(__nwergm_last_G) + 1))
		}
		local __ergm_curved_maxd = max(1, min(`nodes' - 2, `__ergm_maxdeg'))
		local __ergm_cut 0
		if "`method'" != "mple" _nwergm_gwcut nsp, name(gwnspfree) cutoff(`gwcutoff') full(`=max(1, `nodes' - 2)') sptype(`=cond("`directed'" == "true", "`type'", "")')
		if "`method'" != "mple" local __ergm_curved_maxd = max(1, min(`gwcutoff', `nodes' - 2))
		local __td_gwnspfree "__netd_`++__ne_n'"
		mata: `__td_gwnspfree' = ErgmTermData()
		mata: `__td_gwnspfree'.cutoff = `__ergm_cut'
		mata: `__td_gwnspfree'.levels = (1..`__ergm_curved_maxd')'
		// nsp inherits td.sptype dispatch for free via stat_dsp()/
		// stat_esp() (stat_nsp() = stat_dsp() - stat_esp()), same as
		// the fixed-decay gwnsp() path already relies on.
		if "`directed'" == "true" {
			mata: `__td_gwnspfree'.sptype = "`type'"
		}
		local __ergm_curved_cnames ""
		forvalues __k = 1/`__ergm_curved_maxd' {
			local __ergm_curved_cnames "`__ergm_curved_cnames' gwnspfree_`__k'"
		}
		mata: __nwergm_last_M.addterm("nsp", `__ergm_curved_maxd', &stat_nsp(), &change_nsp(), `__td_gwnspfree', tokens("`__ergm_curved_cnames'"))
		mata: __nwergm_last_M.mark_curved()
		local __ergm_matatemps "`__ergm_matatemps' `__td_gwnspfree'"
	}
	// gwodegreefree()/gwidegreefree() (harmonisation unit 141): mirror
	// the other curved options' own exact pattern, registered under
	// "odegree"/"idegree" (reusing stat_odegree()/change_odegree() and
	// stat_idegree()/change_idegree() directly).
	if "`gwodegreefree'" != "" {
		confirm number `gwodegreefree'
		// Harmonisation unit 145: same rationale as gwdegreefree()'s
		// own registration site above, bounded by out-degree (the
		// direction this term's own change statistic actually touches)
		// rather than total degree.
		mata: st_local("__ergm_maxdeg", strofreal(ergm_graph_maxdegree(__nwergm_last_G, "out")))
		local __ergm_curved_maxd = max(1, min(`nodes' - 1, `__ergm_maxdeg' + 1))
		local __ergm_cut 0
		if "`method'" != "mple" _nwergm_gwcut odeg, name(gwodegreefree) cutoff(`gwcutoff') full(`=max(1, `nodes' - 1)') sptype()
		if "`method'" != "mple" local __ergm_curved_maxd = max(1, min(`gwcutoff', `nodes' - 1))
		local __td_gwodegreefree "__netd_`++__ne_n'"
		mata: `__td_gwodegreefree' = ErgmTermData()
		mata: `__td_gwodegreefree'.cutoff = `__ergm_cut'
		mata: `__td_gwodegreefree'.levels = (1..`__ergm_curved_maxd')'
		local __ergm_curved_cnames ""
		forvalues __k = 1/`__ergm_curved_maxd' {
			local __ergm_curved_cnames "`__ergm_curved_cnames' gwodegreefree_`__k'"
		}
		mata: __nwergm_last_M.addterm("odegree", `__ergm_curved_maxd', &stat_odegree(), &change_odegree(), `__td_gwodegreefree', tokens("`__ergm_curved_cnames'"))
		mata: __nwergm_last_M.mark_curved()
		local __ergm_matatemps "`__ergm_matatemps' `__td_gwodegreefree'"
	}
	if "`gwidegreefree'" != "" {
		confirm number `gwidegreefree'
		// Harmonisation unit 145: same rationale, bounded by in-degree.
		mata: st_local("__ergm_maxdeg", strofreal(ergm_graph_maxdegree(__nwergm_last_G, "in")))
		local __ergm_curved_maxd = max(1, min(`nodes' - 1, `__ergm_maxdeg' + 1))
		local __ergm_cut 0
		if "`method'" != "mple" _nwergm_gwcut ideg, name(gwidegreefree) cutoff(`gwcutoff') full(`=max(1, `nodes' - 1)') sptype()
		if "`method'" != "mple" local __ergm_curved_maxd = max(1, min(`gwcutoff', `nodes' - 1))
		local __td_gwidegreefree "__netd_`++__ne_n'"
		mata: `__td_gwidegreefree' = ErgmTermData()
		mata: `__td_gwidegreefree'.cutoff = `__ergm_cut'
		mata: `__td_gwidegreefree'.levels = (1..`__ergm_curved_maxd')'
		local __ergm_curved_cnames ""
		forvalues __k = 1/`__ergm_curved_maxd' {
			local __ergm_curved_cnames "`__ergm_curved_cnames' gwidegreefree_`__k'"
		}
		mata: __nwergm_last_M.addterm("idegree", `__ergm_curved_maxd', &stat_idegree(), &change_idegree(), `__td_gwidegreefree', tokens("`__ergm_curved_cnames'"))
		mata: __nwergm_last_M.mark_curved()
		local __ergm_matatemps "`__ergm_matatemps' `__td_gwidegreefree'"
	}

	// fixdensity dropped `edges' as an estimated term above - a model
	// needs at least one other term to actually estimate anything.
	if "`fixdensity'" != "" {
		mata: st_local("__ergm_nterms_check", strofreal(__nwergm_last_M.nterms))
		if `__ergm_nterms_check' == 0 {
			di "{p 0 0 2}{err}fixdensity requires at least one term besides {bf:edges} (which is dropped, not estimated, under this constraint - see {bf:Remarks}).{p_end}"
			error 198
		}
	}

	// altkstar with fixed = FALSE (R's default): the degree counts 1..n-1 with R's own weight/lambda map (curved type 2)
	if `__altk' {
		if "`directed'" == "true" | "`is2mode'" == "true" {
			di "{p 0 0 2}{err}In term {bf:altkstar}: Term may not be used with networks with `=cond("`directed'" == "true", "directed==TRUE", "bipartite > 0")'; the curved form is available for one-mode undirected networks.{p_end}"
			error 198
		}
		if "`method'" != "mple" {
			di "{p 0 0 2}{err}altkstar with an estimated decay (R: fixed=FALSE) is available with {bf:method(mple)} only, with starting values given by {bf:init()}; use {bf:altkstar(lambda=#  fixed)} for a fixed decay.{p_end}"
			error 198
		}
		local __td_altk "__netd_`++__ne_n'"
		mata: `__td_altk' = ErgmTermData()
		mata: `__td_altk'.levels = (1..`=`nodes'-1')'
		local __ergm_altk_cn ""
		forvalues __k = 1/`=`nodes'-1' {
			local __ergm_altk_cn "`__ergm_altk_cn' altkstar_`__k'"
		}
		mata: __nwergm_last_M.addterm("degree", `=`nodes'-1', &stat_degree(), &change_degree(), `__td_altk', tokens("`__ergm_altk_cn'"))
		mata: __nwergm_last_M.mark_curved()
		mata: __nwergm_last_M.curved[__nwergm_last_M.nterms] = 2
		local __ergm_matatemps "`__ergm_matatemps' `__td_altk'"
	}
	// Unified curved-model flag/starting-value (harmonisation unit
	// 139): v1 scope allows at most one curved term per model (the
	// mutual-exclusivity checks above enforce this), so exactly one of
	// `gwespfree'/`gwdegreefree' can be non-empty at this point -
	// `__ergm_curved' and `__ergm_curved_start' let every downstream
	// curved-path branch (MPLE fit, e(curved), MCMLE gating) check ONE
	// flag instead of repeating "gwespfree() OR gwdegreefree()"
	// everywhere.
	local __ergm_curved = `__ergm_ncurved'
	if "`gwespfree'" != "" local __ergm_curved_start "`gwespfree'"
	else if "`gwdegreefree'" != "" local __ergm_curved_start "`gwdegreefree'"
	else if "`gwdspfree'" != "" local __ergm_curved_start "`gwdspfree'"
	else if "`gwnspfree'" != "" local __ergm_curved_start "`gwnspfree'"
	else if "`gwodegreefree'" != "" local __ergm_curved_start "`gwodegreefree'"
	else if "`bgwdegreefree1'`bgwdegreefree2'`bgwdspfree1'`bgwdspfree2'" != "" local __ergm_curved_start "`bgwdegreefree1'`bgwdegreefree2'`bgwdspfree1'`bgwdspfree2'"
	else if `__altk' local __ergm_curved_start 1
	else local __ergm_curved_start "`gwidegreefree'"

	// dyad-independent iff only edges/nodematch/nodecov/nodeicov/nodeocov/
	// edgecov/absdist/nodematchdiff/nodefactor/nodemix are present (mutual
	// and every geometrically-weighted term, including gwdsp/gwnsp, are
	// dyad-dependent - gwdsp/gwnsp no less than gwesp, since shared-
	// partner counts are just as nonlocal for untied dyads as for tied
	// ones; degree()/odegree()/idegree()/concurrent/triangle/ctriple are
	// ALSO dyad-dependent - unit 90 - since each depends on more than
	// just its own two endpoints' attributes, via other nodes' degrees
	// or shared third parties).
	// nodeofactor()/nodeifactor() are dyad-independent (like nodefactor -
	// their change stat depends only on the toggled dyad's own endpoint
	// attribute, not on other dyads' state), so they are deliberately
	// excluded from this check. kstar/ostar/istar/degrange/odegrange/
	// idegrange are all degree-based and so are dyad-dependent (wave 3).
	// `gwnspfree' added to this check now that method(mcmle) is
	// actually reachable for curved terms (see the gwespfree() gate's
	// own comment above) - previously harmless to omit only because
	// gwnspfree() unconditionally forced method(mple) regardless of
	// this check's own result, a forcing that no longer happens.
	local __ergm_dind = (`"`mutual'"'=="" & `__ns_dep' == 0 & `"`gwesp'"'=="" & `"`gwdsp'"'=="" & `"`gwnsp'"'=="" & `"`gwdegree'"'=="" & `"`gwodegree'"'=="" & `"`gwidegree'"'=="" & `"`degree'"'=="" & `"`odegree'"'=="" & `"`idegree'"'=="" & `"`concurrent'"'=="" & `"`triangle'"'=="" & `"`ctriple'"'=="" & `"`kstar'"'=="" & `"`ostar'"'=="" & `"`istar'"'=="" & `"`degrange'"'=="" & `"`odegrange'"'=="" & `"`idegrange'"'=="" & `"`esp'"'=="" & `"`dsp'"'=="" & "`transitiveties'"=="" & "`cyclicalties'"=="" & "`gwespfree'"=="" & "`gwdegreefree'"=="" & "`gwdspfree'"=="" & "`gwodegreefree'"=="" & "`gwidegreefree'"=="" & "`gwnspfree'"=="" & "`bdegree1'"=="" & "`bdegree2'"=="" & "`bstar1'"=="" & "`bstar2'"=="" & "`bnodematch1'"=="" & "`bnodematch2'"=="" & "`bgwdegree1'"=="" & "`bgwdegree2'"=="" & !`__ergm_bipdep' & "`nodecovrange'`nodeocovrange'`nodeicovrange'`nodefactordistinct'`nodeofactordistinct'`nodeifactordistinct'"=="")
	if `"`operators'"' != "" mata: ergm_ops_finalize(__nwergm_last_M)
	if `__sub' {
		capture mata: mata drop `__sub_name'
		mata: `__sub_name' = ErgmModel()
		mata: ergm_ops_copyM(`__sub_name', __nwergm_last_M)
		global NWERGM_SUBDIND = `__ergm_dind' & !`__ergm_ncurved'
		global NWERGM_SUBCURVED = `__ergm_ncurved'
		exit
	}
	if `__con_active' {
		if `con_dind' == 0 local __ergm_dind 0
	}
	mata: st_local("__exkind", strofreal(ergm_exactll_kind(__nwergm_last_M)))
	if "`exactll'" != "" {
		if "`nologlik'" != "" | "`mcll'" != "" {
			di as err "{p 0 0 2}options exactll and `=cond("`mcll'" != "", "mcll", "nologlik")' may not be combined{p_end}"
			exit 198
		}
		if `__exkind' == 2 {
			di as err "{p 0 0 2}option exactll needs a model without dyad-dependent terms (apart from {bf:mutual} in a directed network); the log-likelihood of this model has no exact form, drop exactll to evaluate it by bridge sampling{p_end}"
			exit 198
		}
		if `__exkind' == 1 & (`__ergm_nmiss' > 0 | `__con_active' | `__obs_info') {
			di as err "{p 0 0 2}option exactll with {bf:mutual} needs a network without missing dyads, constraints or observation constraints{p_end}"
			exit 198
		}
	}
	if "`method'" == "" {
		local method = cond(`__ergm_dind' & "`mainmethod'" != "sa", "mple", "mcmle")
	}
	// the log-likelihood of an MCMLE fit of a model without dyad-dependent terms (and of a directed model with mutual) is
	// evaluated exactly, unless mcll asks for the Monte Carlo (bridge sampling) value
	local __exauto 0
	if "`exactll'" == "" & "`method'" == "mcmle" & "`mcll'" == "" & "`nologlik'" == "" & !`__ego' & `__exkind' < 2 & !`__con_active' & !`__obs_info' {
		if `__exkind' == 0 | `__ergm_nmiss' == 0 local __exauto 1
	}
	if "`mcll'" != "" & "`method'" != "mcmle" {
		di as err "{p 0 0 2}option mcll applies to method(mcmle) only (the log-likelihood of method(mple) is exact for a dyad-independent model and a pseudolikelihood otherwise){p_end}"
		exit 198
	}
	if "`method'" == "mple" & `__con_active' {
		if `con_dind' == 0 di "{p 0 0 2}{txt}Maximum Pseudo-Likelihood (MPLE) estimation for ERGMs with dyad-dependent constraints is not implemented at this time. You may want to use {bf:method(mcmle)} instead.{p_end}"
	}
	if "`method'" == "mple" & !`__ergm_dind' {
		di "{p 0 0 2}{txt}Note: {bf:method(mple)} requested for a dyad-dependent model - reporting pseudolikelihood, NOT full ERGM maximum likelihood.{p_end}"
	}

	// coefficient names longer than 32 characters (the limit of Stata matrix names) are cut
	mata: __nwergm_last_M.coefnames = ergm_coefnames32(__nwergm_last_M.coefnames)
	if `"`logstat'`expstat'"' != "" & ("`fixdensity'" != "" | `__ergm_curved') {
		di "{p 0 0 2}{err}options {bf:logstat()}/{bf:expstat()} cannot be combined with {bf:fixdensity} or a curved (free-decay) term.{p_end}"
		error 198
	}
	if `"`logstat'"' != "" {
		_nwergm_statop log `logstat'
	}
	if `"`expstat'"' != "" {
		_nwergm_statop exp `expstat'
	}
	if `"`coeflabel'"' != "" {
		_nwergm_coeflabel `coeflabel'
	}
	// offset() - holds one or more named coefficients fixed at a
	// user-supplied value rather than estimating them, matching R ergm's
	// own `offset()' formula wrapper (the offset coefficient is reported
	// at exactly the given value, with an entirely zero row/column in
	// the vcov). In a model with a curved term the names are those of
	// the reported (theta-space) parameters, e.g. gwesp_weight and
	// gwesp_decay: either or both of a curved term's parameters can be
	// fixed (R: offset(gwesp(fixed=FALSE)), with which= for one of
	// them), and so can the other terms while the curved one is
	// estimated. They go to __nwergm_last_M.thfixed/thfixedvalue
	// (isfixed stays 0 for a curved model).
	if "`offset'" != "" {
		if `__ergm_curved' {
			mata: __nwergm_last_M.thfixed = J(1, __nwergm_last_M.ntheta(), 0)
			mata: __nwergm_last_M.thfixedvalue = J(1, __nwergm_last_M.ntheta(), 0)
		}
		local __ergm_noffset : word count `offset'
		if mod(`__ergm_noffset', 2) != 0 {
			di "{p 0 0 2}{err}option {bf:offset()} needs coefname/value PAIRS - `offset' has `__ergm_noffset' token(s), an odd count.{p_end}"
			error 198
		}
		local __ergm_noffset_pairs = `__ergm_noffset' / 2
		forvalues __k = 1/`__ergm_noffset_pairs' {
			local __ergm_off_name : word `=2*`__k'-1' of `offset'
			local __ergm_off_val : word `=2*`__k'' of `offset'
			capture confirm number `__ergm_off_val'
			if _rc {
				di "{p 0 0 2}{err}option {bf:offset()}: `__ergm_off_val' is not a valid number - expected coefname/value pairs, e.g. {bf:offset(mutual 2)}.{p_end}"
				error 198
			}
			if `__ergm_curved' {
				mata: st_local("__ergm_off_colpos", strofreal(sum(selectindex(__nwergm_last_M.theta_coefnames() :== "`__ergm_off_name'"))))
			}
			else {
				mata: st_local("__ergm_off_colpos", strofreal(__nwergm_last_M.findcoef("`__ergm_off_name'")))
			}
			if `__ergm_off_colpos' == 0 {
				di "{err}option {bf:offset()}: `__ergm_off_name' is not a coefficient name in this model."
				error 198
			}
			if `__ergm_curved' mata: st_local("__ergm_off_dup", strofreal(__nwergm_last_M.thfixed[`__ergm_off_colpos']))
			else mata: st_local("__ergm_off_dup", strofreal(__nwergm_last_M.isfixed[`__ergm_off_colpos']))
			if `__ergm_off_dup' {
				di "{err}option {bf:offset()}: `__ergm_off_name' is given more than once."
				error 198
			}
			if `__ergm_curved' {
				// the decay of a geometrically weighted term must not be negative (as for gwesp() etc.)
				if substr("`__ergm_off_name'", -6, .) == "_decay" & `__ergm_off_val' < 0 {
					di "{p 0 0 2}{err}option {bf:offset()}: the decay `__ergm_off_name' must not be negative.{p_end}"
					error 198
				}
				mata: __nwergm_last_M.thfixed[`__ergm_off_colpos'] = 1
				mata: __nwergm_last_M.thfixedvalue[`__ergm_off_colpos'] = `__ergm_off_val'
			}
			else mata: __nwergm_last_M.mark_fixed(`__ergm_off_colpos', `__ergm_off_val')
		}
		if `__ergm_curved' mata: st_local("__ergm_nfree", strofreal(cols(ergm_thfree(__nwergm_last_M))))
		else mata: st_local("__ergm_nfree", strofreal(cols(__nwergm_last_M.freeidx())))
		if `__ergm_nfree' == 0 {
			di "{p 0 0 2}{err}option {bf:offset()} cannot fix every coefficient in the model - at least one must remain free to estimate.{p_end}"
			error 198
		}
	}

	// constraints(): statistics held constant by the sample-space constraint are
	// fixed at 0 and ignored (R: ergm.checkconstraints.model()).
	if `__con_active' {
		mata: st_local("__con_conf", invtokens(strofreal(_ergm_con_conflicts(__nwergm_last_M, "`con_implies'"))))
		if "`__con_conf'" != "" {
			local __con_confnames ""
			foreach __c of local __con_conf {
				mata: st_local("__con_cn", __nwergm_last_M.coefnames[`__c'])
				local __con_confnames "`__con_confnames' `__con_cn'"
				mata: __nwergm_last_M.mark_fixed(`__c', 0)
			}
			di "{txt}{p 0 6 2}Note: the constraints hold{res}`__con_confnames'{txt} constant; they are dropped from the model.{p_end}"
			mata: st_local("__ergm_nfree", strofreal(cols(__nwergm_last_M.freeidx())))
			if `__ergm_nfree' == 0 {
				di "{p 0 0 2}{err}all terms are either offsets or held constant by the constraints; there is nothing to estimate.{p_end}"
				error 198
			}
		}
	}

	// Built directly as a Mata matrix and handed straight to st_store()
	// below - NEVER routed through an intermediate Stata MATRIX
	// (st_matrix()), which is fine at the tiny scale of this suite's own
	// certification networks but catastrophically slow (effectively
	// hangs - confirmed directly: a trivial 999000x4 st_matrix() call
	// alone did not complete in over 2 minutes, where the equivalent
	// st_store() directly from Mata took 0.008 seconds) once ndyads
	// scales into the hundreds of thousands - i.e. any directed model
	// with a few hundred nodes or more. Stata matrices are architected
	// for small structures (coefficient vectors, VCV matrices), not
	// bulk per-observation data - the dataset/variable system st_store()
	// targets is what Stata itself uses for that, and performs
	// accordingly. Found and fixed while building the R-vs-Stata
	// benchmark suite's own large-network control case
	// (the development notes harmonisation unit 81).
	if `__ergm_curved' & ("`method'" == "cd" | "`mainmethod'" == "sa") {
		di "{p 0 0 2}{err}contrastive divergence and stochastic approximation are not available for models with curved terms.{p_end}"
		error 198
	}
	// init(): R's control.ergm(init=); starting values / offset values
	local __e7_initmode 0
	if `"`init'"' != "" {
		if `__ergm_curved' {
			// the starting values of the curved pseudolikelihood fit (R: control.ergm(init=)): one per parameter, . = default
			if "`method'" != "mple" {
				di "{p 0 0 2}{err}option {bf:init()} with a curved (free-decay) term is available with {bf:method(mple)} only.{p_end}"
				error 198
			}
			capture mata: mata drop __ergm_curved_init
			mata: __ergm_curved_init = strtoreal(tokens(st_local("init")))
			mata: st_local("__ergm_ci_ok", strofreal(cols(__ergm_curved_init) == __nwergm_last_M.ntheta()))
			if !`__ergm_ci_ok' {
				di "{err}option {bf:init()} needs one value (or .) for each parameter of the curved model."
				error 198
			}
			// offsets take their value from init() when it gives one (as in R)
			mata: ergm_thfix_init(__nwergm_last_M, __ergm_curved_init)
		}
		else {
			_nwergm_est init `"`init'"' "`method'"
			local __e7_initmode = r(mode)
		}
	}

	tempname __nw_D
	// Harmonisation unit 145: route the design-matrix build through the
	// native (C) backend when eligible, exactly the same "is this whole
	// model's own term set inside the native plugin's coverage"
	// eligibility check the MCMLE path below already uses
	// (ErgmNativeSetup() - side-effects populate __nwergm_last_M's own
	// native_termcodes/attridx/p1/p2/attrmat, then ErgmNativeBuildMPLEData()
	// reads them straight off, exactly mirroring ErgmNativeSampleCore()'s
	// own contract). The `2' argument is a proposal code MPLE never
	// uses (no MCMC runs on this path at all) - passed only because
	// ErgmNativeSetup()'s own signature requires one. Falls back to the
	// original Mata build_mple_data() call unchanged whenever native is
	// unavailable or this model's own terms fall outside its coverage
	// (e.g. edgecov()/hamming(), or more parameters than the plugin's own
	// hard-coded MAXTERMS/MAXATTR bounds) - no model is ever left broken,
	// only unaccelerated, matching every other native-eligibility check
	// in this file.
	// BUGFIX pattern already established at this file's own MCMLE call
	// site below: ErgmNativeSetup()'s own return value, called bare,
	// would auto-display as a stray unexplained integer - read
	// eligibility off __nwergm_last_M.native_enabled (the side effect
	// it sets) via st_local() instead, never the bare Mata return.
	// nonative (harmonisation unit 160): an explicit escape hatch to force
	// the Mata backend even on an otherwise native-eligible model - added
	// because unit 160 made edgecov()/hamming() (the last remaining
	// non-native term family) native-eligible too, which left NO way for
	// a user (or this package's own certification suite, e.g. the
	// spcache-purity test in cscripts/test_nwergm_ado.do) to deliberately
	// exercise the Mata code path on a real fit anymore. `ErgmNativeSetup()'
	// is simply never called when set, so `__nwergm_last_M.native_enabled'
	// stays at its own default 0 - identical in effect to every other
	// "native unavailable" case already handled below.
	if `__obs_info' mata: __nwergm_last_G.set_dyadmask(__nwergm_info)
	// many per-node factor columns (sender/receiver/nodefactor with many levels): a sparse design instead of the
	// dense one when the dense one would be large (ergm_sp_use()); same estimates, far less memory and time
	local __ergm_sparse 0
	// MPLE fits (whose covariance is the inverse Hessian) and the starting values of MCMLE fits
	if !`__ergm_curved' & `__ergm_nmiss' == 0 & "`mpletype'" == "glm" & `"`init'"' == "" & ("`method'" == "mcmle" | ///
		("`method'" == "mple" & (("`__ergm_dind'" == "1" & "`mplecovariance'" != "bootstrap") | "`mplecovariance'" == "invhess"))) {
		mata: st_local("__ergm_has_offset", strofreal(sum(__nwergm_last_M.isfixed)>0))
		// global NWERGM_NOSPARSE (certification scripts only): keep the dense design, to compare the two
		if !`__ergm_has_offset' & "$NWERGM_NOSPARSE" == "" & "`exactll'" == "" & !(`__exauto' & `__exkind' == 1) mata: st_local("__ergm_sparse", strofreal(ergm_sp_use(__nwergm_last_M, __nwergm_last_G)))
	}
	if "`nonative'" == "" & !`__ergm_sparse' {
		mata: __ergm_mple_native_setup_rc = ErgmNativeSetup(__nwergm_last_M, `__spdcode', __nwergm_last_G)
		mata: mata drop __ergm_mple_native_setup_rc
	}
	mata: st_local("__ergm_mple_native_used", strofreal(__nwergm_last_M.native_enabled))
	if `__ergm_sparse' {
		local __ergm_mple_native_used 0
		mata: __nwergm_sp = ergm_sp_build(__nwergm_last_M, __nwergm_last_G)
		mata: `__nw_D' = J(0, 0, .)
	}
	else if `__ergm_mple_native_used' {
		mata: `__nw_D' = ErgmNativeBuildMPLEData(__nwergm_last_M, __nwergm_last_G)
	}
	else {
		mata: `__nw_D' = __nwergm_last_M.build_mple_data(__nwergm_last_G)
	}
	// the missing-dyad row filter must see the same dyad mask the design matrix was built with (the informative
	// dyads), so it runs before the mask is restored below
	if `__ergm_nmiss' > 0 {
		mata: `__nw_D' = select(`__nw_D', ergm_mple_keep(__nwergm_last_G, __nwergm_missmat))
	}
	if `__obs_info' {
		if `__con_active' & `__c1_hasdyad' {
			mata: __nwergm_last_G.set_dyadmask(__nwergm_c1_free)
		}
		else {
			mata: __nwergm_last_G.has_dyadmask = 0
		}
	}
	local __ergm_matatemps "`__ergm_matatemps' `__nw_D'"
	if `__ergm_sparse' {
		mata: st_local("__ergm_nrows", strofreal(sum(__nwergm_sp.wt), "%18.0g"))
		mata: st_local("__ergm_p", strofreal(__nwergm_sp.p, "%18.0g"))
	}
	else {
		mata: st_local("__ergm_nrows", strofreal(rows(`__nw_D'), "%18.0g"))
		mata: st_local("__ergm_p", strofreal(cols(`__nw_D')-1, "%18.0g"))
	}

	tempname __ergm_coefnames
	mata: st_local("__ergm_coefnames", invtokens(__nwergm_last_M.coefnames))

	tempname __b_mple __V_mple
	// Curved gwesp (harmonisation unit 136): fit directly in THETA-space
	// via ErgmCurvedMPLEFit() (unw_ergm.do) - Newton-Raphson/Fisher
	// scoring on the SAME pseudolikelihood the ordinary closed-form
	// `logit' call below maximizes, chain-ruled through the certified
	// theta_to_eta()/theta_to_eta_jacobian() (units 133-134). This
	// replaces `logit' entirely for a curved model (fits every
	// coefficient, ordinary and curved, jointly in one loop) rather
	// than running `logit' and then transforming its result - a first
	// version of this feature did exactly that (fit the unconstrained
	// eta MLE via `logit', then project down to theta), and direct
	// testing against R on a well-identified 15-node network found it
	// landing at a materially different, wrong-signed local point -
	// see ErgmCurvedMPLEFit()'s own header comment for the full
	// account of why directly optimizing the true objective is the
	// correct fix, not a patch on the old approach. Whichever curved
	// term is present (harmonisation unit 139 generalized this from
	// gwespfree() alone to gwespfree()/gwdegreefree()), its own
	// weight/decay theta columns are always the LAST 2 (registered
	// last, by construction - see its own addterm() call above), so a
	// starting theta of (0-vector, weight0=0, decay0=`__ergm_curved_start')
	// is built directly rather than needing a general "find this term's
	// own theta position" accessor.
	// remembers whether the pseudolikelihood estimate exists (0 = it does not); used below for e(mple_exists) and, with method(mple), e(converged)
	local __ergm_mple_ok 1
	if `__ergm_sparse' {
		local __e7_ex 1
		if "`mplecheck'" == "on" mata: st_local("__e7_ex", strofreal(ergm_sp_newton(__nwergm_sp, "`__b_mple'", "`__V_mple'")))
		if !`__e7_ex' local __ergm_mple_ok 0
		if !`__e7_ex' di "{err}Warning: The MPLE does not exist!"
		if !`__e7_ex' | "`mplecheck'" != "on" mata: (void) ergm_sp_glm(__nwergm_sp, "`__b_mple'", "`__V_mple'")
	}
	else if `__ergm_curved' {
		tempname __ergm_curvedconv
		// Harmonisation unit 146: try the curved fit entirely natively
		// first (design-matrix build AND Newton-Raphson, one plugin
		// call) when eligible - `ErgmNativeCurvedMPLEFit()' returns 0
		// (rather than erroring) on the one real failure mode it can
		// hit (a singular final information matrix), in which case
		// falling back to the Mata `ErgmCurvedMPLEFit()' on the
		// already-built `__nw_D' below is both correct and cheap (no
		// re-fetching of anything, `__nw_D' was already built above
		// regardless of which path fits it).
		local __ergm_curved_native_used = 0
		if `__ergm_mple_native_used' & `__ergm_nmiss' == 0 & !`__altk' & `"`init'"' == "" {
			mata: st_local("__ergm_curved_native_used", strofreal(ErgmNativeCurvedMPLEFit(__nwergm_last_M, __nwergm_last_G, `__ergm_curved_start', "`__b_mple'", "`__V_mple'", "`__ergm_curvedconv'")))
		}
		if !`__ergm_curved_native_used' {
			mata: __ergm_theta_start = (J(1, __nwergm_last_M.ntheta()-2, 0), 0, `__ergm_curved_start')
			if `"`init'"' != "" mata: ErgmCurvedMPLEFit(__nwergm_last_M, `__nw_D', __ergm_theta_start, 10000, 1e-10, "`__b_mple'", "`__V_mple'", "`__ergm_curvedconv'", __ergm_curved_init)
			else mata: ErgmCurvedMPLEFit(__nwergm_last_M, `__nw_D', __ergm_theta_start, 10000, 1e-10, "`__b_mple'", "`__V_mple'", "`__ergm_curvedconv'")
			mata: mata drop __ergm_theta_start
		}
		mata: st_local("__ergm_curved_converged", strofreal(st_matrix("`__ergm_curvedconv'")[1,1]))
		mata: st_local("__ergm_coefnames", invtokens(__nwergm_last_M.theta_coefnames()))
		if `__ergm_curved_converged' == 0 {
			di "{p 0 0 2}{err}note: the curved MPLE fit did not converge within 100 Newton-Raphson iterations - treat these results with caution.{p_end}"
		}
	}
	else {
		local __ergm_xlist ""
		forvalues __k = 1/`__ergm_p' {
			local __ergm_xlist "`__ergm_xlist' __ergm_x`__k'"
		}

		local __ergm_irls 0
		local __ergm_dcomp 0
		// a large design matrix usually has few distinct rows: the same likelihood on the distinct rows with their counts
		tempname __nw_Dc
		mata: `__nw_Dc' = ergm_mple_compress(`__nw_D')
		mata: st_local("__ergm_dcomp", strofreal(rows(`__nw_Dc') > 0))
		local __ergm_matatemps "`__ergm_matatemps' `__nw_Dc'"
		mata: st_local("__ergm_has_offset", strofreal(sum(__nwergm_last_M.isfixed)>0))
		if !`__ergm_has_offset' & "`mpletype'" == "glm" & ("`mplecheck'" == "on" | "`method'" != "mple") {
			if `__ergm_dcomp' mata: st_local("__ergm_irls", strofreal(ergm_mple_irls_c(`__nw_Dc', "`__b_mple'", "`__V_mple'")))
			else mata: st_local("__ergm_irls", strofreal(ergm_mple_irls(`__nw_D', "`__b_mple'", "`__V_mple'")))
		}
		// a separated pseudolikelihood goes through the existence check and R's glm iterate below
		// the existence check is a simplex on the design; a strict Newton fit that converged (ergm_mple_irls()) already
		// shows that the MPLE exists, so a model with many columns, where the simplex is slow, skips it
		if `__ergm_irls' & "`mplecheck'" == "on" & `__ergm_p' <= 100 {
			if `__ergm_dcomp' mata: st_local("__e7_ex", strofreal(ergm_mple_exists_c(`__nw_Dc')))
			else mata: st_local("__e7_ex", strofreal(ergm_mple_exists(`__nw_D')))
			if !`__e7_ex' local __ergm_irls 0
		}
		if !`__ergm_irls' {
		preserve
		qui drop _all
		qui set obs `__ergm_nrows'
		foreach __v of local __ergm_xlist {
			qui gen double `__v' = .
		}
		qui gen double __ergm_y = .
		mata: st_store(., tokens("`__ergm_xlist' __ergm_y"), `__nw_D')

		// offset() (harmonisation unit 183): a fixed coefficient's own
		// column is EXCLUDED from the free regressor list and its known
		// contribution added instead via `logit''s own native offset()
		// option - the standard GLM-offset construction, and exactly
		// what a fixed/known linear-predictor term means statistically.
		// No-op (`__ergm_free_xlist'==`__ergm_xlist', no offset option)
		// whenever nothing is fixed.
		mata: st_local("__ergm_has_offset", strofreal(sum(__nwergm_last_M.isfixed)>0))
		local __ergm_free_xlist ""
		forvalues __k = 1/`__ergm_p' {
			mata: st_local("__ergm_isfix_k", strofreal(__nwergm_last_M.isfixed[`__k']))
			if !`__ergm_isfix_k' {
				local __ergm_free_xlist "`__ergm_free_xlist' __ergm_x`__k'"
			}
		}
		local __ergm_offset_opt ""
		if `__ergm_has_offset' {
			qui gen double __ergm_offset = .
			mata: st_store(., "__ergm_offset", `__nw_D'[.,(1..`__ergm_p')] * (__nwergm_last_M.isfixed :* __nwergm_last_M.fixedvalue)')
			local __ergm_offset_opt "offset(__ergm_offset)"
		}

		// BUGFIX: a fully edgeless (zero-tie) network - an MPLE fit
		// where the outcome never varies - used to crash completely
		// silently (only "r(2000);", no explanatory text at all) from
		// this bare, uncaptured `logit' call, unlike this command's
		// otherwise consistently friendly "{err}...{txt}" validation
		// messages for every other rejected input. `restore' still
		// needs to run regardless of failure, or a caught error here
		// would leave the caller's own dataset in the modified,
		// mid-preserve state (the same class of bug already fixed once
		// in nwrename.ado this same pass).
		tempname __e7_sb __e7_sV
		local __e7_special 0
		_nwergm_est mple `__nw_D' `__e7_sb' `__e7_sV' "`mpletype'" "`mplecheck'" `__ergm_has_offset' "`method'"
		local __e7_special = r(special)
		if r(exists) == 0 local __ergm_mple_ok 0
		local __e7_rcx 0
		// logit replaces e(): the results of the previous fit are held and put back if this fit is refused
		tempname __e7_hold
		local __e7_held 0
		if !`__e7_special' {
			_estimates hold `__e7_hold', nullok
			local __e7_held 1
			capture qui logit __ergm_y `__ergm_free_xlist', noconstant `__ergm_offset_opt' tolerance(1e-9) ltolerance(1e-11)
			// near-separated fits may not reach the tight tolerance: fall back to logit's defaults
			if _rc == 430 capture qui logit __ergm_y `__ergm_free_xlist', noconstant `__ergm_offset_opt'
			local __e7_rcx = _rc
		}
		if `__e7_rcx' != 0 {
			local __ergm_mple_rc = `__e7_rcx'
			if `__e7_held' _estimates unhold `__e7_hold'
			restore
			di "{p 0 0 2}{err}The MPLE fit did not converge (outcome does not vary - e.g. a fully edgeless network with no ties at all). Cannot estimate this model.{p_end}"
			error `__ergm_mple_rc'
		}
		tempname __b_mple_free __V_mple_free
		if `__e7_special' {
			matrix `__b_mple_free' = `__e7_sb'
			matrix `__V_mple_free' = `__e7_sV'
		}
		else {
			_nwergm_getb `__b_mple_free'
			mata: st_matrix("`__V_mple_free'", st_matrix("e(V)"))
		}
		if `__e7_held' _estimates unhold `__e7_hold'
		restore
		if `__ergm_has_offset' {
			mata: ergm_mple_expand_fixed(__nwergm_last_M, st_matrix("`__b_mple_free'"), st_matrix("`__V_mple_free'"), "`__b_mple'", "`__V_mple'")
		}
		else {
			matrix `__b_mple' = `__b_mple_free'
			matrix `__V_mple' = `__V_mple_free'
		}
		}
	}

	if "`method'" == "mple" {
		// logit's own e(b)/e(V) (non-curved path only - the curved
		// path's own ErgmCurvedMPLEFit() posts plain, unstriped
		// matrices directly) carry an equation-name stripe (the
		// depvar's own name, e.g. "__ergm_y:__ergm_x1") - blanked
		// explicitly before assigning fresh colnames/rownames, or a
		// stale/mismatched stripe between b and V makes `ereturn post`
		// fail with a "name conflict" (r(507)) - the exact same bug
		// class already found and fixed once in nwqap.ado (see its own
		// header comment). Harmless no-op on the curved path's own
		// already-unstriped matrices.
		capture matrix coleq `__b_mple' = _
		capture matrix coleq `__V_mple' = _
		capture matrix roweq `__V_mple' = _
		matrix colnames `__b_mple' = `__ergm_coefnames'
		matrix rownames `__V_mple' = `__ergm_coefnames'
		matrix colnames `__V_mple' = `__ergm_coefnames'

		if "`mplecovariance'" != "invhess" & ("`mplecovariance'" == "bootstrap" | !`__ergm_dind') & !`__ergm_curved' {
			_nwergm_est mplecov `__b_mple' `__V_mple' "`mplecovariance'" "`=cond(`__spd', "spdyad", "`proposal'")'"
		}
		ereturn post `__b_mple' `__V_mple', depname(`netname') obs(`__ergm_nrows')
		ereturn local cmd "nwergm"
		if !`__sub' _nwergm_tag set
		ereturn local version "1.16.0"
		ereturn local title "Exponential-family random graph model (MPLE)"
		ereturn local depvar "`netname'"
		ereturn local method "mple"
		ereturn local directed "`directed'"
		ereturn local proposal "`proposal'"
		if `__spd' ereturn scalar trifocus = `__spdfocus'
		ereturn local estat_cmd "nwergm_estat"
		ereturn scalar N = `__ergm_nrows'
		ereturn scalar nodes = `nodes'
		ereturn scalar ties = `__ergm_obsties'
		ereturn scalar nmissing = `__ergm_nmiss'
		ereturn scalar curved = `__ergm_curved'
		// observed model statistics (R: summary(formula)), one per eta-column
		capture mata: st_matrix("e(obs_stats)", ergm_full_stat(__nwergm_last_M, __nwergm_last_G))
		// Harmonisation unit 145: report whether the design-matrix build
		// itself used the native backend, mirroring e(native) on the
		// MCMLE branch below - previously only ever set there, leaving
		// an MPLE fit's own e(native) undefined even when native routing
		// was actually used for it.
		ereturn scalar native = `__ergm_mple_native_used'

		// a pseudolikelihood estimate that does not exist (separation) is not a converged fit: R's ergm reports -Inf/Inf coefficients, here they are
		// large finite values. The penalised MPLE is finite by construction and is not flagged.
		// with mplecheck(off) nothing is known about the existence, so e(mple_exists) is not posted
		if "`mplecheck'" == "on" ereturn scalar mple_exists = `__ergm_mple_ok'
		ereturn scalar converged = `__ergm_mple_ok' | "`mpletype'" == "penalized"
		if !`__ergm_mple_ok' & "`mpletype'" != "penalized" {
			di "{p 0 0 2}{err}Warning: the maximum pseudolikelihood estimate (MPLE) does not exist for this model and network, so the estimates are not reliable and e(converged) is set to 0.{p_end}"
			di "{p 0 0 2}{err}Some coefficients are driven to large finite values by separation (R's ergm reports -Inf/Inf). Check the model, or use mpletype(penalized).{p_end}"
		}

		nwergm_display "`netname'" "`nodes'" "`directed'" "MPLE" "" "" "" "`__ergm_tabopts'"
		if `__ergm_sparse' {
			_nwergm_fitstats, dmat(__nwergm_sp) method(mple) dind(`__ergm_dind') curved(0) sparse `exactll'
			mata: st_local("__ergm_hassp", strofreal(findexternal("__nwergm_sp") != NULL))
			if `__ergm_hassp' mata: mata drop __nwergm_sp
		}
		else {
			// the pseudolikelihood is evaluated on the distinct rows of the design when it was compressed above
			local __ergm_fs_dc ""
			if "`__ergm_dcomp'" == "1" & "`exactll'" == "" local __ergm_fs_dc "dcomp(`__nw_Dc')"
			_nwergm_fitstats, dmat(`__nw_D') method(mple) dind(`__ergm_dind') curved(`__ergm_curved') `__ergm_fs_dc' `exactll'
		}
		if `__ergm_curved' {
			// not when offset() fixes the decay (the last parameter)
			mata: st_local("__ergm_decayfree", strofreal(anyof(ergm_thfree(__nwergm_last_M), __nwergm_last_M.ntheta())))
			if `__ergm_decayfree' di as text "{p 0 1 2}(The decay of the curved term is estimated; see {help nwergm##gw_effects:help nwergm, gw_effects}.){p_end}"
		}
	}
	else {
		tempname __theta0
		if `__e7_initmode' == 1 {
			mata: __e7_fx = __nwergm_last_M.isfixed; __e7_fx[__e7_tmpfix] = J(1, cols(__e7_tmpfix), 0); __nwergm_last_M.isfixed = __e7_fx
			mata: __e7_fx = __nwergm_last_M.fixedvalue; __e7_fx[__e7_tmpfix] = J(1, cols(__e7_tmpfix), 0); __nwergm_last_M.fixedvalue = __e7_fx
			mata: mata drop __e7_fx
			mata: mata drop __e7_tmpfix
		}
		if `__e7_initmode' == 2 {
			mata: __e7_th = __e7_init; __e7_th = editmissing(__e7_th, 0) :* (1 :- __nwergm_last_M.isfixed) + (__nwergm_last_M.isfixed :* __nwergm_last_M.fixedvalue); st_matrix("`__b_mple'", __e7_th)
			mata: mata drop __e7_th
		}
		// Curved gwesp (harmonisation unit 138): `__b_mple' is now
		// THETA-space for a curved model (unit 136's own MPLE change -
		// it reports gwesp_weight/gwesp_decay directly, not raw
		// eta-space esp() coefficients), but ErgmMCMLE() needs an
		// ETA-space starting vector (the actual MCMC sampling weight,
		// regardless of curved-ness). `__ergm_theta_c0_mcmle' - the
		// curved MPLE's own theta_hat, kept as a live Mata variable
		// rather than round-tripped through a Stata matrix - doubles
		// as ErgmMCMLE()'s own optional starting point for its
		// internal per-iteration eta->theta projection, so the MCMLE
		// loop warm-starts from the SAME point MPLE already found
		// rather than a generic (0,...,0,alpha0) restart.
		if `__ergm_curved' {
			mata: __ergm_theta_c0_mcmle = st_matrix("`__b_mple'")
			mata: `__theta0' = __nwergm_last_M.theta_to_eta(__ergm_theta_c0_mcmle)
		}
		else {
			mata: `__theta0' = st_matrix("`__b_mple'")
			// R: without a dyad-independent sample space MPLE is not an initial-value method; start from zeros,
			// except for offsets and for the starting values given in init(), which R uses as given
			tempname __keep0
			mata: `__keep0' = __nwergm_last_M.isfixed
			if `__e7_initmode' > 0 mata: `__keep0' = `__keep0' :| (__e7_init :< .)
			if `__con_active' {
				if `con_dind' == 0 mata: `__theta0' = `__theta0' :* `__keep0'
			}
			if `__obs_active' & !`__obs_info' mata: `__theta0' = `__theta0' :* `__keep0'
			mata: mata drop `__keep0'
		}
		local __ergm_matatemps "`__ergm_matatemps' `__theta0'"

		// freedyads() now has a masked TNT variant too
		// (ergm_propose_tnt_masked() - the development notes'
		// "Constraints beyond v1's free binary dyad space" row) - picks
		// the masked form of whichever proposal() was actually
		// requested/defaulted to, rather than forcing uniform.
		// BUGFIX (blockdiag() addition): this must also fire for a
		// blockdiag()-only model (has_dyadmask==1 exactly the same way
		// freedyads() sets it, via the SAME set_dyadmask() call) - an
		// `if "`freedyads''!=""' check alone would silently pick the
		// UNMASKED proposal for a blockdiag()-only model, completely
		// ignoring the constraint during MCMC despite G.has_dyadmask
		// being correctly set. Caught before shipping, not after.
		if `__spd' {
			local __ergm_propfn "&ergm_propose_spdyad()"
			local __ergm_propcode `__spdcode'
		}
		else if "`freedyads'" != "" | "`blockdiag'" != "" {
			// BUGFIX (harmonisation unit 168): __ergm_propcode was
			// hardcoded to 1 (uniform) on this branch regardless of
			// which masked proposal was actually picked just above -
			// harmless before this unit (a masked model was ALWAYS
			// Mata-only, and the Mata fallback path uses `__ergm_propfn'
			// directly, never this code), but M.native_proposal (which
			// this code DOES feed, via ErgmNativeSetup()'s own
			// proposal_code argument) is now read by the native masked
			// TNT port's own wire-protocol argstr - left wrong, every
			// masked+tnt native call would have silently told the C
			// plugin to run uniform instead. Caught reading this code
			// while wiring up that port, before it ever shipped.
			if "`proposal'" == "tnt" {
				local __ergm_propfn "&ergm_propose_tnt_masked()"
				local __ergm_propcode 2
			}
			else {
				local __ergm_propfn "&ergm_propose_uniform_masked()"
				local __ergm_propcode 1
			}
		}
		else if "`proposal'" == "tnt" {
			local __ergm_propfn "&ergm_propose_tnt()"
			local __ergm_propcode 2
		}
		else {
			local __ergm_propfn "&ergm_propose_uniform()"
			local __ergm_propcode 1
		}

		// Native (C) MCMC backend eligibility (harmonisation unit 83;
		// scope relaxed considerably, unit 91 follow-on - see
		// unw_ergm.do's own ErgmNativeSetup() header comment for the
		// full current term list) - decided ONCE here, before any MCMC
		// runs, never inside ErgmMCMLE()'s own loop. Sets
		// __nwergm_last_M.native_enabled; ErgmMCMCSample()/
		// ErgmMCMCSampleDiag() (called internally by ErgmMCMLE() below)
		// check that field themselves and fall back to the unmodified
		// Mata sampler whenever it is 0 - a model using any term outside
		// the native backend's own current scope, or a platform with no
		// compiled lib/plugins/ergm_mcmc.plugin, is completely
		// unaffected by this call. See unw_ergm.do's own "Native (C)
		// MCMC backend" section and the development notes for the
		// full design.
		// BUGFIX: ErgmNativeSetup() returns real scalar (1/0, whether the
		// native backend ended up eligible) - calling it bare left Mata
		// auto-displaying that return value as a stray, unexplained "1"
		// (or "0") before anything else this command prints. The
		// eligibility flag itself is read straight off
		// __nwergm_last_M.native_enabled on the next line regardless, so
		// the return value was never actually needed here at all.
		// nonative (unit 160): see the identical MPLE-path comment above -
		// skips ErgmNativeSetup() entirely, leaving native_enabled at its
		// own default 0.
		if "`nonative'" == "" {
			mata: __ergm_native_setup_rc = ErgmNativeSetup(__nwergm_last_M, `__ergm_propcode', __nwergm_last_G)
			mata: mata drop __ergm_native_setup_rc
		}
		if `__con_active' | `mcmcmaxedges' > 0 {
			mata: st_local("__con_ok", strofreal(__nwergm_last_M.native_enabled_sample))
			if `__con_ok' != 1 {
				di "{p 0 0 2}{err}constraints() and mcmcmaxedges() need the native plugin, which is not available for this model, platform or the nonative option.{p_end}"
				error 198
			}
			if `__con_active' {
				mata: __nwergm_last_M.con_par = __nwergm_c1_par
				mata: __nwergm_last_M.con_cols = __nwergm_c1_cols
			}
			else {
				mata: __nwergm_last_M.con_par = J(1, 10, 0)
			}
			if `mcmcmaxedges' > 0 mata: __nwergm_last_M.con_par[10] = `mcmcmaxedges'
		}
		if `__obs_active' {
			mata: st_local("__con_ok", strofreal(__nwergm_last_M.native_enabled_sample))
			if `__con_ok' != 1 {
				di "{p 0 0 2}{err}obsconstraints() needs the native plugin, which is not available for this model, platform or the nonative option.{p_end}"
				error 198
			}
		}
		// fixdensity: this is the single place that sets M.fixed_density=1,
		// guaranteed to run before ErgmMCMLE() is ever called below.
		// `native_enabled' (the MPLE-design-matrix-build flag) is forced
		// off unconditionally regardless of whether ErgmNativeSetup() ran
		// above or was skipped via nonative - a fixed-density model is
		// always method(mcmle) (checked earlier in this program), so its
		// own MPLE-mode native path is simply never reached either way;
		// forcing it off here just documents that explicitly rather than
		// leaving it as an unexercised accident. `native_enabled_sample'
		// (the MCMC-SAMPLING flag ErgmMCMCSample()/ErgmMCMCSampleDiag()
		// actually check) is deliberately left at whatever
		// ErgmNativeSetup() already decided from this model's own TERMS -
		// native/ergm_mcmc.c's own propose_swap() now natively ports the
		// fixdensity compound tie/non-tie swap move too (its own
		// wire-carried M.fixed_density flag selects that proposal loop
		// internally), so fixdensity no longer forces a Mata-only fit the
		// way it used to; a fixed-density model runs native exactly when
		// an ordinary model with the same terms would.
		if "`fixdensity'" != "" {
			mata: __nwergm_last_M.fixed_density = 1
			mata: __nwergm_last_M.native_enabled = 0
		}
		// native_enabled_sample (unit 168), not native_enabled: for a
		// freedyads()-masked model native_enabled itself is forced to 0
		// (MPLE has no mask awareness), but MCMC sampling - all of
		// what an MCMLE fit's own e(native) diagnostic is actually
		// describing here - now genuinely can and does run natively.
		// Reporting native_enabled would misleadingly show e(native)==0
		// for a masked fit whose sampling loop ran on the C plugin the
		// whole time. For an unmasked model the two fields are always
		// equal, so this is a no-op change there.
		mata: st_local("__ergm_native_used", strofreal(__nwergm_last_M.native_enabled_sample))
		// a cutoff below the largest possible count is enforced by the native sampler only: without it (the nonative
		// option, a model or platform without the plugin, a plugin of an older version) a count above the cutoff would be
		// dropped silently
		if `__ergm_cutact' {
			mata: st_local("__ergm_gen", strofreal(ergm_native_gen()))
			if !`__ergm_native_used' | `__ergm_gen' < 7 {
				di "{p 0 0 2}{err}a curved term with an estimated decay and {bf:gwcutoff(`gwcutoff')} below the number of nodes needs the native plugin of this version of nwergm, which is not available for this model, platform, the {bf:nonative} option or an installed older plugin; reinstall nwergm (or run {bf:nwinstall, models}) or raise {bf:gwcutoff()} to the number of nodes.{p_end}"
				exit 498
			}
		}
		if !`__ergm_native_used' _nwergm_slowwarn "this fit" "`nonative'"
		if `__ergm_nmiss' > 0 {
			// missing dyads: second, constrained chain (only the missing dyads free), as R ergm
			capture mata: mata drop __nwergm_last_Gobs
			capture confirm number 0
			mata: __nwergm_last_Gobs = ergm_graph_clone(__nwergm_last_G)
			mata: __nwergm_last_Gobs.set_dyadmask(__nwergm_missmat)
			mata: __nwergm_last_M.obs_G = &__nwergm_last_Gobs
			mata: __nwergm_last_M.obs_mask = __nwergm_missmat
			if `__spd' mata: __nwergm_last_M.obs_propfn = &ergm_propose_spdyad()
			else if "`proposal'" == "tnt" mata: __nwergm_last_M.obs_propfn = &ergm_propose_tnt_masked()
			else mata: __nwergm_last_M.obs_propfn = &ergm_propose_uniform_masked()
			mata: __nwergm_last_M.obs_active = 1
		}

		_nwergm_est ctl, termination(`mcmletermination') confidence(`mcmleconfidence') steplength(`mcmlesteplength') ///
			margin(`mcmlestepmargin') effsize(`mcmleeffectivesize')
		// R: the MCMLE sample size is chosen adaptively (MCMLE.effectiveSize = 64, base size max(256, 32 * parameters)) unless
		// mcmleeffectivesize(0) asks for fixed-size samples; the fixed-size default is 3000 draws. The constrained (missing
		// data), contrastive-divergence and stochastic-approximation fits keep their own fixed sizes.
		local __ss_adapt = (`mcmleeffectivesize' != 0 & !`__obs_active' & "`method'" != "cd" & "`mainmethod'" != "sa")
		if `mcmcsamplesize' < 0 & !`__ss_adapt' local mcmcsamplesize 3000
		mata: __nwergm_ties0 = __nwergm_last_G.all_ties()
		capture mata: mata drop __ergm_obsstat
		capture confirm number 0
		mata: __ergm_obsstat = ergm_full_stat(__nwergm_last_M, __nwergm_last_G)
		if `__bayes' {
			if !`__ergm_native_used' {
				di as err "{p 0 0 2}estimate(bayes) needs the native plugin, which is not available for this model or platform.{p_end}"
				error 198
			}
			if `__ergm_nmiss' > 0 {
				di as err "{p 0 0 2}estimate(bayes) does not cover networks with missing dyads.{p_end}"
				error 198
			}
			_nwergm_bayes, netname(`netname') nodes(`nodes') directed(`directed') nrows(`__ergm_nrows') bmple(`__b_mple') vmple(`__V_mple') ///
				coefnames(`__ergm_coefnames') obsties(`__ergm_obsties') native(`__ergm_native_used') curved(`__ergm_curved') ///
				proposal(`proposal') bopts(`"`__bopts'"') tabopts(`"`__ergm_tabopts'"') ///
				`=cond(`__spd', "trifocus(`__spdfocus')", "")' sub(`__sub')
			mata: mata drop `__ergm_matatemps'
			exit
		}
		if `__ego' {
			local __egobad = ("`fixdensity'" != "" | "`method'" == "cd" | "`mainmethod'" == "sa")
			foreach __x in __ergm_curved __obs_active __con_active __ergm_nmiss {
				if "``__x''" != "" & "``__x''" != "0" local __egobad 1
			}
			if `__egobad' {
				di as err "{p 0 0 2}nwergm ego cannot be combined with curved terms, constraints, missing dyads or the cd and sa estimators.{p_end}"
				error 198
			}
			mata: ergm_ego_settarget(__nwergm_last_M, tokens("`egonames'"), "`egotarget'")
		}
		tempname __fit
		if `__obs_active' {
			mata: `__fit' = ErgmMCMLEObs(__nwergm_last_M, __nwergm_last_G, __nwergm_obs_G, __nwergm_obs_par, __nwergm_obs_cols, `__theta0', `mcmleiterations', `mcmcburnin', `mcmcinterval', `mcmcsamplesize', ("`verbose'"!=""))
		}
		else if `__ergm_curved' {
			capture noisily mata: `__fit' = ErgmMCMLE(__nwergm_last_M, __nwergm_last_G, `__theta0', `mcmleiterations', `mcmcburnin', `mcmcinterval', `mcmcsamplesize', `__ergm_propfn', ("`verbose'"!=""), __ergm_theta_c0_mcmle)
			if _rc {
				local __rcfit = _rc
				if `__rcfit' == 498 & `__ergm_cutact' {
					di as err "{p 0 0 2}The Monte Carlo fit stopped because a simulated network has a count above {bf:gwcutoff(`gwcutoff')}. With a curved term whose decay is estimated this usually means that an iteration of the fit moved the decay (or the weight) to values at which the simulated networks degenerate (a few large clusters of triangles); R's {cmd:ergm} stops in the same way, for about half of the seeds on this kind of model. Raising {bf:gwcutoff()} only postpones the failure. Try a fixed decay ({bf:gwesp(#)}, {bf:gwdsp(#)}, ...), another {bf:seed()}, a larger {bf:mcmcsamplesize()}, or an {bf:offset()} on the decay; {bf:verbose} shows the path of the estimates.{p_end}"
				}
				exit `__rcfit'
			}
			mata: mata drop __ergm_theta_c0_mcmle
		}
		else {
			if "`method'" == "cd" {
				_nwergm_est cdstart `__theta0' `__ergm_curved'
				mata: `__fit' = ErgmCD(__nwergm_last_M, __nwergm_last_G, `__theta0', `mcmleiterations', `cdnsteps', `cdsamplesize', `__ergm_propfn', ("`verbose'"!=""), 0.5, 0.5)
			}
			else if "`mainmethod'" == "sa" {
				mata: __e7_q = cols(__nwergm_last_M.freeidx())
				mata: `__fit' = ErgmSA(__nwergm_last_M, __nwergm_last_G, `__theta0', `saburnin', `sainterval', `sagain', max((200, 7 + 3*__e7_q)), `sansub', 7 + __e7_q, 207 + __e7_q, `saphase3', `__ergm_propfn', ("`verbose'"!=""))
				mata: mata drop __e7_q
			}
			else {
			mata: `__fit' = ErgmMCMLE(__nwergm_last_M, __nwergm_last_G, `__theta0', `mcmleiterations', `mcmcburnin', `mcmcinterval', `mcmcsamplesize', `__ergm_propfn', ("`verbose'"!=""))
			// Without a dyad-independent sample space there is no MPLE start (as in R): the first sample is drawn
			// at zero and can be far from the estimate, so refit from the estimate until it stops moving.
			if `__con_active' {
				if `con_dind' == 0 {
					forvalues __r = 2/5 {
						mata: st_local("__con_chg", strofreal(max(abs((`__fit'.coef - `__theta0')[__nwergm_last_M.freeidx()]) :/ sqrt(diagonal(`__fit'.vcov)[__nwergm_last_M.freeidx()])')))
						if `__con_chg' < 0.05 continue, break
						mata: `__theta0' = `__fit'.coef
						mata: _ergm_con_resetG(__nwergm_last_G, __nwergm_ties0)
						mata: `__fit' = ErgmMCMLE(__nwergm_last_M, __nwergm_last_G, `__theta0', `mcmleiterations', `mcmcburnin', `mcmcinterval', `mcmcsamplesize', `__ergm_propfn', ("`verbose'"!=""))
					}
				}
			}
			}
		}
		local __ergm_matatemps "`__ergm_matatemps' `__fit'"
		if `__ego' {
			capture mata: mata drop ergm_target
			mata: `__fit'.vcov = ergm_ego_sandwich(`__fit'.finalsample, __nwergm_last_M, tokens("`egonames'"), "`egovt'", "__ego_A")
			mata: `__fit'.coef = ergm_ego_unshift(`__fit'.coef, __nwergm_last_M, `egoshift')
		}
		local __br_ss "`mcmcsamplesize'"
		local __br_int "`mcmcinterval'"
		local __br_burn "`mcmcburnin'"
		if `__ss_adapt' {
			mata: st_local("mcmcsamplesize", strofreal(`__fit'.final_samplesize, "%18.0g"))
			mata: st_local("__br_ss", strofreal(`__fit'.bridge_samplesize, "%18.0g"))
			mata: st_local("__br_int", strofreal(`__fit'.next_interval, "%18.0g"))
			mata: st_local("__br_burn", strofreal(max((16, 16 * `__fit'.final_interval)), "%18.0g"))
		}

		tempname __b_mcmle __V_mcmle
		if `__ergm_curved' {
			// Curved gwesp (harmonisation unit 138): `__fit'.coef is
			// still eta-space (ErgmMCMLE() itself never reports
			// theta directly - see its own header comment); the
			// reported fit is `__fit'.coef_theta, with `__fit'.vcov
			// (eta-space) transformed via the exact same delta-method
			// formula ErgmCurvedMPLEFit() already uses internally,
			// evaluated at the converged theta rather than a
			// Newton-Raphson optimum.
			//
			// Curved MCMLE degeneracy guard: measured directly during
			// this unit's own development that a curved model CAN
			// drive the underlying MCMC chain into a genuinely
			// degenerate region (100% Metropolis-Hastings acceptance,
			// a classic stuck-chain signature) on a real test network -
			// confirmed as a genuine difficulty of the statistical
			// problem itself, not a bug specific to this
			// implementation, since R ergm's OWN reference
			// implementation independently failed outright
			// ("Unconstrained MCMC sampling did not mix at all") on
			// the identical network. Unlike R, nothing here previously
			// detected this and it silently reported a "converged"
			// fit with missing coef_theta entries cascading into a
			// nonsensical result - checked and refused explicitly now,
			// matching this project's own "never silently report a
			// wrong answer" convention, rather than chasing full
			// robustness against MCMC degeneracy (a substantially
			// larger undertaking, and one R's own mature
			// implementation does not fully solve either).
			// Checked on `coef_theta' AND (harmonisation unit 180 - the
			// theta-space Newton redesign) the FINAL transformed
			// `__V_mcmle' too, not just `coef_theta' alone: a finite
			// `coef_theta' can still carry a near-singular RAW `vcov'
			// (the final diagnostics simulation's own sample frozen/
			// near-zero-variance at a hard-to-mix theta) that the
			// Jacobian delta-method sandwich below then turns into a
			// matrix of missing values - observed directly on this
			// package's own known-pathological `curvedgwespnet' network
			// under a deliberately tiny iteration/sample budget, where
			// the ORIGINAL (coef_theta-only) guard let a missing-VCOV
			// fit reach `ereturn post', which then failed with a raw,
			// unexplained "estimates post: matrix has missing values"
			// (r(504)) instead of this command's own clear message.
			mata: st_local("__ergm_curved_degenerate", strofreal(missing(`__fit'.coef_theta) > 0))
			if `__ergm_curved_degenerate' {
				di "{p 0 0 2}{err}The curved MCMLE fit did not produce a valid result - the underlying MCMC chain likely became degenerate for this model/network combination (this is a genuine difficulty of curved-decay estimation in general, not specific to this package; R's own ergm can fail identically with 'Unconstrained MCMC sampling did not mix at all' on a hard case). Try a different starting decay value, a longer {bf:mcmcburnin()}, or a simpler model.{p_end}"
				error 430
			}
			mata: st_matrix("`__b_mcmle'", `__fit'.coef_theta)
			mata: st_matrix("`__V_mcmle'", ergm_curved_vtheta(__nwergm_last_M, `__fit'.coef_theta, `__fit'.vcov))
			mata: st_local("__ergm_curved_vcov_degenerate", strofreal(missing(st_matrix("`__V_mcmle'")) > 0))
			if `__ergm_curved_vcov_degenerate' {
				di "{p 0 0 2}{err}The curved MCMLE fit did not produce a valid result - the final variance-covariance simulation landed at a near-degenerate (frozen) point, leaving the theta-space variance-covariance matrix undefined after the delta-method transform. Try a different starting decay value, a longer {bf:mcmcburnin()}, a larger {bf:mcmcsamplesize()}, or a simpler model.{p_end}"
				error 430
			}
			mata: st_local("__ergm_coefnames", invtokens(__nwergm_last_M.theta_coefnames()))
		}
		else {
			// Non-curved degeneracy guard, mirroring the curved guard
			// immediately above (unit 138): an outer Newton step with no
			// check against what the MCMC sample actually supports can
			// drive `theta' into a degenerate region (observed directly:
			// an edges coefficient near 900, forcing a near-frozen
			// graph) where the final diagnostics simulation's own sampled
			// statistics have essentially zero variance - ergm_spectral0_ar()'s
			// autocorrelation estimate is then undefined (0/0), cascading
			// through `V[k,k] = V[k,k]*infl[k]' and `invsym(V)' into an
			// entirely missing vcov, while the F-test can spuriously
			// "pass" on a frozen chain (Dbar trivially ~0 when nothing
			// varies) - so `converged==1' alone is not sufficient
			// evidence of a usable fit. Checked and refused explicitly,
			// matching this project's own "never silently report a
			// wrong answer" convention - same as the curved branch, not
			// previously applied here.
			mata: st_local("__ergm_mcmle_degenerate", strofreal(missing(`__fit'.vcov) > 0))
			if `__ergm_mcmle_degenerate' {
				di "{p 0 0 2}{err}The MCMLE fit did not produce a valid result - the underlying MCMC chain likely became degenerate for this model/network combination (the fitted parameters drove the simulated graph into a near-deterministic region, leaving the variance-covariance matrix undefined). Try different starting values, a longer {bf:mcmcburnin()}, or a simpler model.{p_end}"
				error 430
			}
			mata: st_matrix("`__b_mcmle'", `__fit'.coef)
			mata: st_matrix("`__V_mcmle'", `__fit'.vcov)

		}
		// captured into plain locals, NOT e(name)-style scalars: `ereturn
		// post' below clears whatever the e() results namespace
		// currently holds, so referencing `e(converged)' AFTER that
		// call (as this code originally, incorrectly, did) reads back
		// missing - the exact same "r(x) is only published once the
		// program exits" confusion already found and fixed once in this
		// package's own nw2project.ado, here for e() instead of r().
		mata: st_local("__ergm_converged", strofreal(`__fit'.converged))
		mata: st_local("__ergm_niter", strofreal(`__fit'.niter))
		mata: st_local("__ergm_acceptrate", strofreal(`__fit'.acceptrate))
		mata: st_local("__ergm_interval_final", strofreal(`__fit'.final_interval))
		// the maximum likelihood estimate does not exist when an observed statistic is on the boundary of the final sample: no
		// simulated draw lies below it (or none above it), so no finite coefficient can make the expected statistic equal the
		// observed one (R: "Observed statistic(s) ... are at their smallest/greatest attainable values", coefficient -Inf/+Inf).
		// Checked for fits without curved terms, missing dyads, observation constraints, sample-space constraints and ego data.
		local __ergm_mle_ok 1
		local __ergm_mcmle_test `__ergm_converged'
		local __ergm_mle_bnd ""
		if !`__ergm_curved' & !`__obs_active' & `__ergm_nmiss' == 0 & !`__con_active' & !`__ego' & "`method'" == "mcmle" & "`mainmethod'" != "sa" {
			mata: __ergm_mb = ((__ergm_obsstat :<= colmin(`__fit'.finalsample)) :| (__ergm_obsstat :>= colmax(`__fit'.finalsample))) :& (__nwergm_last_M.isfixed :== 0)
			mata: st_local("__ergm_mle_bnd", invtokens(strofreal(selectindex(__ergm_mb))))
			mata: mata drop __ergm_mb
			if "`__ergm_mle_bnd'" != "" {
				local __ergm_mle_ok 0
				local __ergm_mle_names ""
				foreach __k of local __ergm_mle_bnd {
					local __ergm_mle_names "`__ergm_mle_names' `: word `__k' of `__ergm_coefnames''"
				}
				local __ergm_converged 0
			}
		}

		matrix coleq `__b_mcmle' = _
		matrix coleq `__V_mcmle' = _
		matrix roweq `__V_mcmle' = _
		matrix colnames `__b_mcmle' = `__ergm_coefnames'
		matrix rownames `__V_mcmle' = `__ergm_coefnames'
		matrix colnames `__V_mcmle' = `__ergm_coefnames'

		ereturn post `__b_mcmle' `__V_mcmle', depname(`netname') obs(`__ergm_nrows')
		ereturn local cmd "nwergm"
		if !`__sub' _nwergm_tag set
		ereturn local version "1.16.0"
		ereturn local title "Exponential-family random graph model (MCMLE)"
		ereturn local depvar "`netname'"
		ereturn local method "mcmle"
		ereturn local estimate "`=cond("`method'"=="cd","CD",cond("`mainmethod'"=="sa","SA","MLE"))'"
		if `__ego' {
			ereturn local estimate "Ego"
			ereturn local title "Egocentric exponential-family random graph model"
			ereturn scalar egoshift = `egoshift'
		}
		ereturn local directed "`directed'"
		ereturn local proposal "`proposal'"
		if `__spd' ereturn scalar trifocus = `__spdfocus'
		if `__con_active' ereturn local constraints `"`constraints'"'
		if `__obs_active' ereturn local obsconstraints `"`obsconstraints'"'
		ereturn local estat_cmd "nwergm_estat"
		ereturn scalar N = `__ergm_nrows'
		ereturn scalar nodes = `nodes'
		// the pseudolikelihood used as the starting value did not exist (separation): recorded, but the fit is judged by the MCMLE test
		if "`mplecheck'" == "on" ereturn scalar mple_exists = `__ergm_mple_ok'
		ereturn scalar mle_exists = `__ergm_mle_ok'
		ereturn scalar converged = `__ergm_converged'
		ereturn scalar mcmle_iterations = `__ergm_niter'
		ereturn scalar mcmc_acceptrate = `__ergm_acceptrate'
		ereturn scalar mcmc_burnin = `mcmcburnin'
		ereturn scalar mcmc_interval = `mcmcinterval'
		// The interval actually used for the LAST MCMLE iteration and the
		// final diagnostics simulation (harmonisation unit 85) - may
		// exceed `e(mcmc_interval)' (the caller-supplied starting value)
		// when the adaptive-interval mechanism grew it because the
		// achieved effective MCMC sample size fell short of the target
		// floor; equal to `e(mcmc_interval)' whenever no growth was ever
		// triggered (the ordinary case for small/well-mixing models).
		ereturn scalar mcmc_interval_final = `__ergm_interval_final'
		// 1 if this model's own term list was eligible for the native
		// (C) MCMC backend and the compiled plugin was actually used for
		// this run's own simulations; 0 if the Mata sampler ran instead
		// (either because a term outside the native backend's current
		// scope was present, or no compiled plugin exists for this
		// platform) - see the development notes' own "Native (C)
		// MCMC backend" section for exactly which terms are covered
		// today. Purely informational: both backends are certified
		// statistically indistinguishable (cscripts/test_nwergm_native.do)
		// and nothing about interpreting results differs based on this
		// flag - it exists so a user curious about performance can see,
		// without guessing, whether their own specific model got the
		// native speedup.
		ereturn scalar native = `__ergm_native_used'
		// 1 if the Mata incremental shared-partner cache (spcache option,
		// off by default - see this call's own build-up comment above)
		// was actually enabled for this fit, 0 otherwise. Purely
		// informational, like e(native); has no effect when e(native)==1
		// (the native backend never uses this Mata-level cache at all).
		ereturn scalar spcache = `__ergm_spcache_used'
		ereturn scalar curved = `__ergm_curved'
		ereturn scalar mcmc_samplesize = `mcmcsamplesize'
		ereturn scalar ties = `__ergm_obsties'
		ereturn scalar nmissing = `__ergm_nmiss'
		// the final simulation's own sufficient-statistic draws
		// (samplesize x nparam), doubling as nwergm's basic MCMC
		// diagnostics sample (Part XIX) - consumed by `estat mcmcdiag'
		// (nwergm_estat.ado). Columns are unnamed (no natural row/column
		// stripe applies to a raw draw-by-draw sample); `estat mcmcdiag'
		// pulls coefficient names from e(b) instead.
		//
		// PERFORMANCE NOTE, `nomcmcsample' (harmonisation unit 154):
		// the development notes' own unit-81 entry flagged this as a
		// "related, lower-priority risk" and guessed the fix would need
		// "reworking estat mcmcdiag's own matrix-based consumption of
		// e(mcmcsample)" - directly profiled before acting on that
		// guess, and it was WRONG in an important way: `estat mcmcdiag'`'s
		// own READ of e(mcmcsample) (`= st_matrix(...)`, Mata reading FROM
		// a Stata matrix) is fast regardless of size (0.004s at
		// 100,000x15). The entire cost lives here, in THIS bulk WRITE
		// (`st_matrix("name", data)`, Mata writing INTO a Stata matrix) -
		// confirmed by direct timing to be slow (34s+ at 100,000x15)
		// REGARDLESS of the destination name (a plain local matrix name
		// costs exactly the same as writing to "e(mcmcsample)" directly,
		// ruling out any e()-specific overhead) - a genuine architectural
		// property of Stata's own matrix engine at bulk-data scale (the
		// same class of cost unit 81 found for the MPLE design matrix),
		// not a `nwergm`-specific inefficiency and not fixable by
		// restructuring the READ side at all. Since e(mcmcsample) is
		// documented, public API (unlike unit 81's own purely-internal
		// MPLE design matrix, which never needed to exist as a genuine
		// Stata matrix at all), this write cannot be avoided when a
		// caller actually wants the sample - but a caller who only wants
		// the coefficient table, and does not intend to call `estat
		// mcmcdiag' or inspect e(mcmcsample) directly, can now skip
		// paying it via `nomcmcsample'. Default (posting it) is
		// unchanged, so this is purely additive - no existing model or
		// test loses e(mcmcsample) unless it opts out.
		if "`nomcmcsample'" == "" {
			mata: st_matrix("e(mcmcsample)", `__fit'.finalsample)
		}

		if !`__ergm_mle_ok' {
			di "{p 0 0 2}{err}Warning: the maximum likelihood estimate does not exist for this model and network: the observed statistic(s)`__ergm_mle_names' lie at the boundary of the simulated statistics (their smallest or greatest attainable values), so their coefficients are infinite (R's ergm: -Inf/+Inf). The estimates are not reliable and e(converged) is set to 0.{p_end}"
		}
		// independent of the warning above: the MCMLE test is reported whenever it failed (e(converged) is 0 also for a non-existent MLE)
		if `__ergm_mcmle_test' == 0 {
			di "{p 0 0 2}{err}Warning: MCMLE did NOT satisfy its own convergence test after `__ergm_niter' iterations.{p_end}"
			di "{p 0 0 2}{err}Results are reported but should not be treated as a converged fit - consider increasing mcmleiterations()/mcmcsamplesize().{p_end}"
		}

		if `__ego' {
			mata: mata drop `__ergm_matatemps'
			exit
		}
		nwergm_display "`netname'" "`nodes'" "`directed'" "`=cond("`method'"=="cd","CD",cond("`mainmethod'"=="sa","SA","MCMLE"))'" "`=cond(`__ergm_mle_ok', "`__ergm_converged'", "2")'" "`__ergm_niter'" "`mcmcsamplesize'" "`__ergm_tabopts'"
		local __dcname ""
		if "`__ergm_dcomp'" == "1" local __dcname "`__nw_Dc'"
		if `__ss_adapt' local __ergm_interval_bridge `__br_int'
		else local __ergm_interval_bridge `__ergm_interval_final'
		local __sparseopt ""
		local __dmatname "`__nw_D'"
		if `__ergm_sparse' {
			local __sparseopt "sparse"
			local __dmatname "__nwergm_sp"
		}
		_nwergm_fitstats, dmat(`__dmatname') method(mcmle) propfn(`__ergm_propfn') mcmcburnin(`__br_burn') mcmcinterval(`__br_int') ///
			mcmcsamplesize(`__br_ss') intervalfinal(`__ergm_interval_bridge') curved(`__ergm_curved') bridgesteps(`bridgesteps') ///
			bridgesamplesize(`bridgesamplesize') bridgeinterval(`bridgeinterval') carry(`__ss_adapt') dcomp(`__dcname') `nologlik' `exactll' `=cond(`__exauto', "exactll", "")' `__sparseopt'
		mata: st_local("__ergm_hassp", strofreal(findexternal("__nwergm_sp") != NULL))
		if `__ergm_hassp' mata: mata drop __nwergm_sp
		if `__ergm_curved' {
			// not when offset() fixes the decay (the last parameter)
			mata: st_local("__ergm_decayfree", strofreal(anyof(ergm_thfree(__nwergm_last_M), __nwergm_last_M.ntheta())))
			if `__ergm_decayfree' di as text "{p 0 1 2}(The decay of the curved term is estimated; see {help nwergm##gw_effects:help nwergm, gw_effects}.){p_end}"
		}
	}

	mata: mata drop `__ergm_matatemps'
end

// splits the options of the Bayesian fit off the option string of nwergm: returns them in c_local names given as arguments
// curved terms with an estimated decay in a sampling fit (R: gwesp(fixed = FALSE, cutoff = 30) etc.): the block has
// min(gwcutoff(), full) count statistics, `full' being the largest count that can occur (nodes - 2 shared partners,
// nodes - 1 for a degree). R stops when a network has a count above the cutoff; the observed network is checked here, the
// simulated ones by the native sampler. Returns the cutoff to arm in c_local __ergm_cut (0: it cannot bind).
capture program drop _nwergm_gwcut
program _nwergm_gwcut
	version 14
	syntax anything(name=kind), NAME(string) CUToff(integer) FULL(integer) [SPtype(string)]
	if `cutoff' >= `full' {
		c_local __ergm_cut 0
		exit
	}
	mata: st_local("__mx", strofreal(ergm_gwcut_obsmax(__nwergm_last_G, "`kind'", "`sptype'")))
	if `__mx' > `cutoff' {
		if "`kind'" == "esp" local what "the number of shared partners on some edge"
		else if inlist("`kind'", "dsp", "nsp") local what "the number of shared partners of some dyad"
		else if "`kind'" == "odeg" local what "the out-degree of some node"
		else if "`kind'" == "ideg" local what "the in-degree of some node"
		else local what "the degree of some node"
		di as err "{p 0 0 2}Term {bf:`name'} has encountered a network for which `what' (`__mx') exceeded the cutoff of `cutoff'. This can usually be remedied by increasing option {bf:gwcutoff()}.{p_end}"
		exit 498
	}
	c_local __ergm_cut `cutoff'
	c_local __ergm_cutact 1
end

capture program drop _nwergm_bayes_split
program _nwergm_bayes_split
	version 14
	args mbayes mrest
	local 0 `", `3'"'
	syntax [, CHAINS(string) BURNIN(string) ITERATIONS(string) THIN(string) AUXITERATIONS(string) GAMMA(string) NOADAPT ///
		TARGETACCEPT(string) NODELAYED DAINFLATE(string) PROPOSALVAR(string) PRIORMEAN(string) PRIORVAR(string) PRIORCOV(string) ///
		PRIORDECAY(string) STARTVALS(string) FRAME(string) NODRAWS * ]
	local b
	foreach o in chains burnin iterations thin auxiterations gamma targetaccept dainflate proposalvar priormean priorvar priorcov priordecay startvals frame {
		if `"``o''"' != "" local b `"`b' `o'(``o'')"'
	}
	foreach o in noadapt nodelayed nodraws {
		if "``o''" != "" local b `"`b' `o'"'
	}
	c_local `mbayes' `"`b'"'
	c_local `mrest' `"`options'"'
end


capture program drop _nwergm_bayes
program _nwergm_bayes, eclass
	version 14
	syntax , NETNAME(string) NODES(integer) DIRECTED(string) NROWS(integer) BMPLE(name) VMPLE(name) COEFNAMES(string asis) ///
		OBSTIES(integer) NATIVE(integer) CURVED(integer) PROPOSAL(string) [BOPTS(string asis) TABOPTS(string asis) TRIFOCUS(string) SUB(integer 0)]
	local bopts `bopts'
	local tabopts `tabopts'
	local 0 `", `bopts'"'
	syntax [, CHAINS(integer 0) BURNIN(integer 100) ITERATIONS(integer 1000) THIN(integer 1) AUXITERATIONS(integer 1000) GAMMA(real 0.5) NOADAPT ///
		TARGETACCEPT(real 0.25) NODELAYED DAINFLATE(real 1.5) PROPOSALVAR(real 0.0025) PRIORMEAN(numlist) PRIORVAR(numlist >0) PRIORCOV(name) ///
		PRIORDECAY(numlist min=2 max=2) STARTVALS(numlist) FRAME(name) NODRAWS]
	if `chains' != 0 & `chains' < 3 {
		di as err "option chains() must be at least 3."
		exit 198
	}
	if `burnin' < 0 | `iterations' < 1 | `thin' < 1 | `auxiterations' < 1 {
		di as err "{p 0 0 2}options burnin() must be zero or positive, and iterations(), thin() and auxiterations() positive.{p_end}"
		exit 198
	}
	if `thin' > `iterations' {
		di as err "option thin() cannot exceed iterations()."
		exit 198
	}
	if `gamma' <= 0 | `proposalvar' <= 0 | `dainflate' <= 0 {
		di as err "options gamma(), proposalvar() and dainflate() must be positive."
		exit 198
	}
	if `targetaccept' <= 0 | `targetaccept' >= 1 {
		di as err "option targetaccept() must be between 0 and 1."
		exit 198
	}
	local dmeanlog = ln(0.5)
	local dsdlog = 0.75
	if "`priordecay'" != "" {
		local dmeanlog : word 1 of `priordecay'
		local dsdlog : word 2 of `priordecay'
		if `dsdlog' <= 0 {
			di as err "option priordecay(): the standard deviation on the log scale must be positive."
			exit 198
		}
	}
	if "`priorvar'" != "" & "`priorcov'" != "" {
		di as err "options priorvar() and priorcov() cannot be combined."
		exit 198
	}
	if "`priorcov'" != "" {
		capture confirm matrix `priorcov'
		if _rc {
			di as err "option priorcov(): matrix `priorcov' not found."
			exit 111
		}
	}
	if "`frame'" == "" local frame nwergm_bayes_draws
	if "`nodraws'" != "" local frame ""
	_nwergm_tabopts __t, `tabopts'
	local level 95
	if regexm(`"`__t'"', "level\(([0-9.]+)\)") local level = regexs(1)

	tempname pm pv sv
	if "`priormean'" != "" mata: st_matrix("`pm'", strtoreal(tokens("`priormean'")))
	if "`priorvar'" != "" mata: st_matrix("`pv'", strtoreal(tokens("`priorvar'")))
	if "`startvals'" != "" mata: st_matrix("`sv'", strtoreal(tokens("`startvals'")))
	local pmn = cond("`priormean'" != "", "`pm'", "")
	local pvn = cond("`priorvar'" != "", "`pv'", "")
	local svn = cond("`startvals'" != "", "`sv'", "")
	local adapt = ("`noadapt'" == "")
	local da = ("`nodelayed'" == "")

	// an unfinished earlier call must not leave the plugin switch on
	capture scalar drop __eb_on
	timer clear 97
	timer on 97
	mata: ErgmBayesFit(__nwergm_last_M, __nwergm_last_G, __ergm_obsstat, "`bmple'", "`vmple'", "`pmn'", "`pvn'", "`priorcov'", "`svn'", `dmeanlog', `dsdlog', ///
		`chains', `burnin', `iterations', `thin', `auxiterations', `gamma', `proposalvar', `adapt', `targetaccept', `da', `dainflate', `level', "`frame'")
	timer off 97
	quietly timer list 97
	local secs = r(t97)

	tempname b V med sd lo hi ess rhat rhatu acc
	matrix `b' = __eb_b
	matrix `V' = __eb_V
	local k = colsof(`b')
	foreach m in med sd lo hi ess rhat rhatu {
		matrix ``m'' = __eb_`m'
		if "`m'" == "med" matrix `med' = __eb_med
	}
	matrix `acc' = __eb_acc
	local nch = scalar(__eb_nchains)
	local nkeep = scalar(__eb_nkeep)
	local sumacc = 0
	forvalues c = 1/`nch' {
		local sumacc = `sumacc' + `acc'[1, `c']
	}
	local arate = `sumacc' / `nch'
	local gammaend = scalar(__eb_gamma_out)
	local nsim = scalar(__eb_nsim)
	local nsimburn = scalar(__eb_nsimburn)
	local nda = scalar(__eb_nda)
	local nprop = scalar(__eb_nprop)
	local useda = scalar(__eb_useda)
	tempname ci prmean prvar isfree isdec
	matrix `ci' = (`lo' \ `hi')
	matrix `prmean' = __eb_prmean
	matrix `prvar' = __eb_prvar
	matrix `isfree' = __eb_isfree
	matrix `isdec' = __eb_isdec
	matrix coleq `b' = _
	matrix coleq `V' = _
	matrix roweq `V' = _
	matrix colnames `b' = `coefnames'
	matrix rownames `V' = `coefnames'
	matrix colnames `V' = `coefnames'
	foreach m in med sd ess rhat rhatu isfree isdec prmean {
		matrix colnames ``m'' = `coefnames'
		matrix rownames ``m'' = _
	}
	matrix colnames `ci' = `coefnames'
	matrix rownames `ci' = lower upper
	matrix rownames `prvar' = `coefnames'
	matrix colnames `prvar' = `coefnames'
	local ties "`obsties'"

	ereturn post `b' `V', depname(`netname') obs(`nrows')
	ereturn local cmd "nwergm"
	if !`sub' _nwergm_tag set
	ereturn local version "1.16.0"
	ereturn local title "Bayesian exponential-family random graph model"
	ereturn local depvar "`netname'"
	ereturn local method "bayes"
	ereturn local estimate "Bayes"
	ereturn local directed "`directed'"
	ereturn local proposal "`proposal'"
	if "`trifocus'" != "" ereturn scalar trifocus = `trifocus'
	ereturn local estat_cmd "nwergm_estat"
	ereturn local post_frame "`frame'"
	ereturn local priors "normal(priormean, priorvar) on the coefficients; log-normal(priordecay) on a free decay"
	ereturn scalar N = `nrows'
	ereturn scalar nodes = `nodes'
	ereturn scalar ties = `ties'
	ereturn scalar nmissing = 0
	ereturn scalar curved = `curved'
	ereturn scalar native = `native'
	ereturn scalar converged = 1
	ereturn scalar chains = `nch'
	ereturn scalar burnin = `burnin'
	ereturn scalar iterations = `iterations'
	ereturn scalar thin = `thin'
	ereturn scalar auxiterations = `auxiterations'
	ereturn scalar ndraws = `nch' * `nkeep'
	ereturn scalar draws_per_chain = `nkeep'
	ereturn scalar accept_rate = `arate'
	ereturn scalar gamma = `gammaend'
	ereturn scalar gamma0 = `gamma'
	ereturn scalar proposalvar = `proposalvar'
	ereturn scalar targetaccept = `targetaccept'
	ereturn scalar adapt = `adapt'
	ereturn scalar delayed = `useda'
	ereturn scalar da_rejections = `nda'
	ereturn scalar nsim = `nsim' + `nsimburn'
	ereturn scalar level = `level'
	ereturn scalar seconds = `secs'
	ereturn scalar mcmc_burnin = `auxiterations'
	ereturn scalar mcmc_interval = 1
	ereturn matrix median = `med'
	ereturn matrix sd = `sd'
	ereturn matrix ci = `ci'
	ereturn matrix ess = `ess'
	ereturn matrix rhat = `rhat'
	ereturn matrix rhat_upper = `rhatu'
	ereturn matrix accept_chains = `acc'
	ereturn matrix prior_mean = `prmean'
	ereturn matrix prior_var = `prvar'
	ereturn matrix free = `isfree'
	capture mata: st_matrix("e(obs_stats)", ergm_full_stat(__nwergm_last_M, __nwergm_last_G))
	foreach s in nch nkeep nsimburn nda nprop useda gamma_out nsim {
		capture scalar drop __eb_`s'
	}
	_nwergm_bayes_display, tabopts(`"`tabopts'"')
end


capture program drop _nwergm_bayes_display
program _nwergm_bayes_display
	version 14
	syntax [, TABOPTS(string asis)]
	local tabopts `tabopts'
	_nwergm_tabopts __t, `tabopts'
	local level = e(level)
	if regexm(`"`__t'"', "level\(([0-9.]+)\)") {
		local lv = regexs(1)
		if `lv' != `level' {
			capture confirm matrix __eb_dummy
			capture mata: ErgmBayesRequantile(`lv')
			if !_rc local level = `lv'
		}
	}
	tempname b sd med ci ess rhat
	matrix `b' = e(b)
	matrix `sd' = e(sd)
	matrix `med' = e(median)
	matrix `ci' = e(ci)
	matrix `ess' = e(ess)
	matrix `rhat' = e(rhat)
	local names : colnames `b'
	local K = colsof(`b')
	local wn = 12
	foreach nm of local names {
		local wn = max(`wn', min(28, udstrlen("`nm'")))
	}
	local wn = min(`wn', 28)
	di
	di as txt "Bayesian exponential-family random graph model" _col(52) "Chains" _col(66) "= " as res %6.0f e(chains)
	di as txt "Network: " as res "`e(depvar)'" as txt "   Nodes: " as res e(nodes) as txt "   Ties: " as res e(ties) as txt _col(52) "Burn-in" _col(66) "= " as res %6.0f e(burnin)
	di as txt "Directed: " as res cond("`e(directed)'" == "true", "Yes", "No") as txt "   Auxiliary iterations: " as res e(auxiterations) ///
		as txt _col(52) "Iterations" _col(66) "= " as res %6.0f e(iterations)
	di as txt "Acceptance rate: " as res %5.3f e(accept_rate) as txt _col(52) "Sample size" _col(66) "= " as res %6.0f e(ndraws)
	di
	local tw = `wn' + 1
	local lw = 65
	di as txt "{hline `tw'}{c TT}{hline `=`lw''}"
	di as txt %`wn's "Coefficient" " {c |}" %9s "Mean" %10s "Std. dev." %10s "Median" %22s "[`level'% cred. interval]" %7s "ESS" %7s "R-hat"
	di as txt "{hline `tw'}{c +}{hline `=`lw''}"
	forvalues k = 1/`K' {
		local nm : word `k' of `names'
		local sdv = `sd'[1, `k']
		if `sdv' == 0 {
			di as txt %`wn's abbrev("`nm'", `wn') " {c |}" as res %9.4f `b'[1, `k'] as txt "  (fixed value, not estimated)"
			continue
		}
		di as txt %`wn's abbrev("`nm'", `wn') " {c |}" as res %9.4f `b'[1, `k'] %10.4f `sdv' %10.4f `med'[1, `k'] %11.4f `ci'[1, `k'] %11.4f `ci'[2, `k'] %7.0f `ess'[1, `k'] %7.3f `rhat'[1, `k']
	}
	di as txt "{hline `tw'}{c BT}{hline `=`lw''}"
	di as txt "{p 0 0 2}Posterior mean, standard deviation, median and equal-tailed credible interval of the pooled draws of all chains; ESS: effective sample size (sum over the chains); R-hat: Gelman-Rubin statistic.{p_end}"
	if "`e(post_frame)'" != "" di as txt "{p 0 0 2}The draws are in frame {bf:`e(post_frame)'} (b1..b`K' in the order of the table, chain, iter); {bf:estat posterior} saves and plots them, {bf:estat mcmcdiag} shows the convergence diagnostics.{p_end}"
end

capture program drop nwergm_display
program nwergm_display
	args netname nodes directed method converged niter mcmcsamplesize tabopts

	di
	di "{txt}Exponential-family random graph model"
	di
	di "{txt}Network:{col 24}={res}  `netname'"
	di "{txt}Nodes:{col 24}={res}  `nodes'"
	di "{txt}Ties:{col 24}={res}  `=e(ties)'"
	di "{txt}Directed:{col 24}={res}  " cond("`directed'"=="true","Yes","No")
	di "{txt}Estimation:{col 24}={res}  " cond("`method'"=="CD","Contrastive divergence",cond("`method'"=="SA","Stochastic approximation","`method'"))
	if "`method'" == "MCMLE" {
		di "{txt}MCMC sample size:{col 24}={res}  `mcmcsamplesize'"
	}
	di
	_nwergm_tabopts __t, `tabopts'
	ereturn display, `__t'
	di
	if "`method'" == "CD" {
		di "{txt}{p 0 0 2}Contrastive divergence estimate (`niter' iteration(s)); standard errors come from the covariance of the short-run CD sample.{p_end}"
	}
	else if "`method'" == "SA" {
		di "{txt}Stochastic approximation estimate (`niter' phase-2 iteration(s))."
	}
	else if "`method'" == "MCMLE" {
		if "`converged'" == "1" {
			di "{txt}MCMLE converged after `niter' iteration(s)."
		}
		else if "`converged'" == "2" {
			di "{err}MCMLE stopped after `niter' iteration(s): no maximum likelihood estimate."
		}
		else {
			di "{err}MCMLE did not converge after `niter' iteration(s)."
		}
	}
	else {
		di "{txt}{p 0 0 2}Maximum pseudolikelihood estimate; this is the maximum likelihood estimate only if the model is dyad-independent.{p_end}"
	}
end

/*
	nwergm simulate (Part X's own example syntax): draws one or more
	networks from a fully-specified ERGM (fixed theta, not estimated),
	via the same native MCMC engine nwergm's own estimation path uses.
	v1 scope deliberately covers only the terms needing no external
	covariate data (edges/mutual/the gw family) - see this program's own
	SMCL doc header above ("Simulation" section) for the full rationale
	and the development notes for extending this to covariate terms.
*/
capture program drop nwergm_simulate
program nwergm_simulate
	version 14
	_nwergm_libcheck
	local __nes_n = 0
	syntax anything(name=nodes) , edges [mutual ///
		NODEMATCH(string) NODEMATCHDIFF(string) NODECOV(string) NODEICOV(string) NODEOCOV(string) ///
		EDGECOV(string) ABSDIST(string) NODEFACTOR(string) NODEMIX(string) ///
		GWESP(string) GWDSP(string) GWNSP(string) GWDEGREE(string) GWODEGREE(string) GWIDEGREE(string) ///
		DEGREE(string) ODEGREE(string) IDEGREE(string) CONCURRENT TRIANGLE CTRIPLE ///
		NODEIFACTOR(string) NODEOFACTOR(string) ///
		KSTAR(string) ISTAR(string) OSTAR(string) ///
		DEGRANGE(string) DEGRANGETO(string) ODEGRANGE(string) ODEGRANGETO(string) ///
		IDEGRANGE(string) IDEGRANGETO(string) ESP(string) DSP(string) ///
		TRANSITIVETIES CYCLICALTIES HAMMING(string) SENDER RECEIVER ///
		TYPE(string) STRUCTURAL(string asis) ///
		BCOV1(string) BCOV2(string) BFACTOR1(string) BFACTOR2(string) ///
		BDEGREE1(string) BDEGREE2(string) BSTAR1(string) BSTAR2(string) ///
		BNODEMATCH1(string) BNODEMATCH2(string) BGWDEGREE1(string) BGWDEGREE2(string) ///
		BCONCURRENT1(string) BCONCURRENT2(string) BMINDEGREE1(string) BMINDEGREE2(string) ///
		BDEGRANGE1(string) BDEGRANGE2(string) BCOVRANGE1(string) BCOVRANGE2(string) ///
		BFACTORDISTINCT1(string) BFACTORDISTINCT2(string) BSOCIALITY1(string) BSOCIALITY2(string) ///
		BSTARMIX1(string) BSTARMIX2(string) BTWOSTAR1(string) BTWOSTAR2(string) COINCIDENCE(string) ///
		BDSP1(string) BDSP2(string) BGWDSP1(string) BGWDSP2(string) ///
		BIPARTITE(integer 0) ///
		THETA(numlist) directed NSIM(integer 1) MCMCBURNIN(integer -1) ///
		MCMCINTERVAL(integer 1024) PROPOSAL(string) SEED(string) GENERATE(string) SPCACHE ///
		BASIS(string) CONSTRAINTS(string asis) MCMCPROP(string asis) NONATIVE OUTPUT(string) ]
	if `"`seed'"' != "" _nwergm_seed `seed', check
	_nwergm_decaycheck, gwesp(`gwesp') gwdsp(`gwdsp') gwnsp(`gwnsp') gwdegree(`gwdegree') gwodegree(`gwodegree') gwidegree(`gwidegree') ///
		bgwdegree1(`bgwdegree1') bgwdegree2(`bgwdegree2') bgwdsp1(`bgwdsp1') bgwdsp2(`bgwdsp2')
	// a geometrically weighted term is in the model when its option is given, also with decay 0 (ergm allows decay 0)
	foreach __g in gwesp gwdsp gwnsp gwdegree gwodegree gwidegree {
		local __has_`__g' = ("``__g''" != "")
		if `__has_`__g'' {
			capture confirm number ``__g''
			if _rc {
				di as err "option {bf:`__g'()} takes one number, the decay"
				exit 198
			}
		}
	}

	foreach __ergm_o in degree odegree idegree kstar ostar istar degrange degrangeto odegrange odegrangeto idegrange idegrangeto esp dsp bdegree1 bdegree2 bstar1 bstar2 {
		if `"``__ergm_o''"' != "" & strpos(`"``__ergm_o''"', ",") == 0 {
			capture numlist "``__ergm_o''"
			if !_rc local `__ergm_o' `r(numlist)'
		}
	}
	// R: MCMC.burnin = MCMC.interval * 16 - an unset burn-in follows the interval
	if `mcmcburnin' < 0 local mcmcburnin = 16 * `mcmcinterval'
	confirm integer number `nodes'
	if `nodes' < 2 {
		di "{err}nwergm simulate needs at least 2 nodes."
		error 198
	}
	// Bipartite (two-mode) simulation support (mirrors the main nwergm
	// command's own network-type validation block above): `bipartite()'
	// gives the mode-1 node count, following this package's own
	// established convention (nwset's own mat()+bipartite branch,
	// check_bipartite()/get_2mode_edge() in nwset.ado) that mode-1 nodes
	// are node indices 1..bipartite() and mode-2 nodes are the
	// remaining bipartite()+1..nodes - unlike ErgmGraph's own general
	// non-contiguous `mode' field (see unw_ergm.do's own header comment
	// on it), simulate has no existing network to read a per-node mode
	// assignment FROM, so it needs its own explicit, R-`network(n,
	// bipartite=)'-analogous contiguous-prefix convention here - the
	// same one nwset's own mat()+bipartite construction already uses,
	// so a simulated bipartite draw round-trips cleanly back through
	// nwset/nwergm without any node relabeling.
	if `bipartite' != 0 & "`directed'" != "" {
		di "{p 0 0 2}{err}nwergm simulate does not support directed two-mode (bipartite) networks - bipartite ERGMs are undirected only, matching the reference implementation this package studies (R's ergm package).{p_end}"
		error 198
	}
	if `bipartite' < 0 | `bipartite' == `nodes' {
		di "{p 0 0 2}{err}option {bf:bipartite()} must give the mode-1 node count, strictly between 0 and {bf:nodes()} (`nodes'); got `bipartite'.{p_end}"
		error 198
	}
	if `bipartite' != 0 {
		foreach __ergm_bo in mutual nodeicov nodeocov nodeifactor nodeofactor sender receiver odegree idegree ostar istar ctriple odegrange odegrangeto idegrange idegrangeto {
			if `"``__ergm_bo''"' != "" {
				di "{err}In term {bf:`__ergm_bo'}: Term may not be used with networks with directed==FALSE."
				error 198
			}
		}
		foreach __ergm_bo in gwodegree gwidegree gwdegree {
			if `__has_`__ergm_bo'' {
				di "{err}In term {bf:`__ergm_bo'}: Term may not be used with networks with bipartite > 0."
				error 198
			}
		}
	}
	else {
		local __ergm_bipall ""
		foreach __ergm_bo in bgwdegree1 bgwdegree2 bconcurrent1 bconcurrent2 bmindegree1 bmindegree2 bdegrange1 bdegrange2 bcovrange1 bcovrange2 bfactordistinct1 bfactordistinct2 bsociality1 bsociality2 bstarmix1 bstarmix2 btwostar1 btwostar2 coincidence bdsp1 bdsp2 bgwdsp1 bgwdsp2 {
			local __ergm_bipall `"`__ergm_bipall'``__ergm_bo''"'
		}
		if "`bcov1'`bcov2'`bfactor1'`bfactor2'`bdegree1'`bdegree2'`bstar1'`bstar2'`bnodematch1'`bnodematch2'" != "" | `"`__ergm_bipall'"' != "" {
			di "{p 0 0 2}{err}options {bf:bcov1()}/{bf:bcov2()}/{bf:bfactor1()}/{bf:bfactor2()}/{bf:bdegree1()}/{bf:bdegree2()}/{bf:bstar1()}/{bf:bstar2()}/{bf:bnodematch1()}/{bf:bnodematch2()}/{bf:bgwdegree1()}/{bf:bgwdegree2()} require {bf:bipartite()} (the mode-1 node count).{p_end}"
			di "{p 0 0 2}{err}Use {bf:nodematch()}/{bf:nodecov()}/{bf:nodefactor()}/{bf:degree()}/{bf:kstar()}/{bf:gwdegree()} for a one-mode simulation's own analogous effect.{p_end}"
			error 198
		}
	}
	if "`theta'" == "" {
		di "{p 0 0 2}{err}option {bf:theta()} is required - one coefficient per requested term, in the same order the term options are listed (edges first).{p_end}"
		error 198
	}
	if "`mutual'" != "" & "`directed'" == "" {
		di "{err}option {bf:mutual} requires {bf:directed}."
		error 198
	}
	if (`__has_gwodegree' | `__has_gwidegree') & "`directed'" == "" {
		di "{p 0 0 2}{err}options {bf:gwodegree()}/{bf:gwidegree()} require {bf:directed}. Use {bf:gwdegree()} for an undirected simulation.{p_end}"
		error 198
	}
	// gwesp()/gwdsp()/gwnsp()/esp()/dsp() support directed simulation too
	// (matching the estimation path above) via one of four directed
	// shared-partner definitions selected by `type()' (default OTP) -
	// no directedness restriction on these terms themselves.
	local __ergm_type_explicit = ("`type'" != "")
	local type = upper("`type'")
	if "`type'" == "" local type "OTP"
	_opts_oneof "OTP ITP OSP ISP RTP" "type" "`type'" 198
	if `__ergm_type_explicit' & "`directed'" == "" {
		di "{p 0 0 2}{err}note: option {bf:type()} only affects directed simulation; without {bf:directed}, the undirected shared-partner definition is used regardless.{p_end}"
	}
	if `__ergm_type_explicit' & (!`__has_gwesp' & !`__has_gwdsp' & !`__has_gwnsp' & "`esp'`dsp'"=="") {
		di "{p 0 0 2}{err}note: option {bf:type()} has no effect - no {bf:gwesp()}/{bf:gwdsp()}/{bf:gwnsp()}/{bf:esp()}/{bf:dsp()} term was requested.{p_end}"
	}
	if ("`nodeicov'" != "" | "`nodeocov'" != "") & "`directed'" == "" {
		di "{err}options {bf:nodeicov()}/{bf:nodeocov()} require {bf:directed}."
		error 198
	}
	if "`degree'" != "" & "`directed'" != "" {
		di "{p 0 0 2}{err}option {bf:degree()} is undirected only. Use {bf:odegree()}/{bf:idegree()} for a directed simulation.{p_end}"
		error 198
	}
	if ("`odegree'" != "" | "`idegree'" != "") & "`directed'" == "" {
		di "{p 0 0 2}{err}options {bf:odegree()}/{bf:idegree()} require {bf:directed}. Use {bf:degree()} for an undirected simulation.{p_end}"
		error 198
	}
	if "`concurrent'" != "" & "`directed'" != "" {
		di "{err}option {bf:concurrent} (v1 scope) is undirected only."
		error 198
	}
	if "`triangle'" != "" & "`directed'" != "" {
		local structural `"`structural' triangle"'
		local triangle ""
	}
	if "`ctriple'" != "" & "`directed'" == "" {
		di "{err}option {bf:ctriple} requires {bf:directed}. Use {bf:triangle} for an undirected simulation."
		error 198
	}
	if ("`nodeifactor'" != "" | "`nodeofactor'" != "") & "`directed'" == "" {
		di "{p 0 0 2}{err}options {bf:nodeifactor()}/{bf:nodeofactor()} require {bf:directed}. Use {bf:nodefactor()} for an undirected simulation.{p_end}"
		error 198
	}
	if "`kstar'" != "" & "`directed'" != "" {
		di "{p 0 0 2}{err}option {bf:kstar()} is undirected only. Use {bf:ostar()}/{bf:istar()} for a directed simulation.{p_end}"
		error 198
	}
	if ("`ostar'" != "" | "`istar'" != "") & "`directed'" == "" {
		di "{p 0 0 2}{err}options {bf:ostar()}/{bf:istar()} require {bf:directed}. Use {bf:kstar()} for an undirected simulation.{p_end}"
		error 198
	}
	if "`degrange'" != "" & "`directed'" != "" {
		di "{p 0 0 2}{err}option {bf:degrange()} is undirected only. Use {bf:odegrange()}/{bf:idegrange()} for a directed simulation.{p_end}"
		error 198
	}
	if ("`odegrange'" != "" | "`idegrange'" != "") & "`directed'" == "" {
		di "{p 0 0 2}{err}options {bf:odegrange()}/{bf:idegrange()} require {bf:directed}. Use {bf:degrange()} for an undirected simulation.{p_end}"
		error 198
	}
	if ("`transitiveties'" != "" | "`cyclicalties'" != "") & "`directed'" == "" {
		di "{err}options {bf:transitiveties}/{bf:cyclicalties} require {bf:directed}."
		error 198
	}
	if ("`sender'" != "" | "`receiver'" != "") & "`directed'" == "" {
		di "{err}options {bf:sender}/{bf:receiver} require {bf:directed}."
		error 198
	}
	if "`proposal'" == "" local proposal "tnt"
	_opts_oneof "uniform tnt" "proposal" "`proposal'" 198
	_nwergm_hints, spec(`mcmcprop')
	if `__spdstrict' & `bipartite' != 0 {
		di as err "{p 0 0 2}The triadic() hint cannot be used with a bipartite network (use .triadic, which R skips on a bipartite network).{p_end}"
		error 198
	}
	// output(stats) (R: output = "stats"): the statistics of the draws as a Stata matrix (one row per draw, one column per
	// model term), without storing the draws as networks
	if "`output'" == "" local output "network"
	if !inlist("`output'", "network", "stats") {
		di "{err}output() must be {bf:network} or {bf:stats}."
		exit 198
	}
	if "`generate'" == "" local generate "ergmsim"
	if "`output'" == "stats" {
		capture confirm names `generate'
		if _rc | "`generate'" == "default" {
			di "{err}With output(stats), generate() names the frame that receives the statistics: {bf:`generate'} is not a valid name for a new frame."
			exit 198
		}
	}
	if `"`seed'"' != "" {
		_nwergm_seed `seed'
	}

	local __ergm_matatemps ""

	capture mata: mata drop __nwergm_last_M
	_nwergm_tag clear
	mata: __nwergm_last_M = ErgmModel()
	mata: __nwergm_last_M.init()
	// the graph of an earlier fit must not stay in memory while the terms are read: _nwergm_numvar takes the number
	// of observations to check from __nwergm_last_G.n, which would be the size of that fit (not of this simulation)
	capture mata: mata drop __nwergm_last_G
	mata: __nwergm_last_G = ErgmGraph()
	mata: __nwergm_last_G.init(`nodes', ("`directed'"!=""))

	tempname td_edges
	mata: `td_edges' = ErgmTermData()
	mata: __nwergm_last_M.addterm("edges", 1, &stat_edges(), &change_edges(), `td_edges', ("edges"))
	local ntermtok "edges"
	local __ergm_matatemps "`__ergm_matatemps' `td_edges'"

	if "`mutual'" != "" {
		tempname td_mutual
		mata: `td_mutual' = ErgmTermData()
		mata: __nwergm_last_M.addterm("mutual", 1, &stat_mutual(), &change_mutual(), `td_mutual', ("mutual"))
		local ntermtok "`ntermtok' mutual"
		local __ergm_matatemps "`__ergm_matatemps' `td_mutual'"
	}

	// --- node-covariate terms (ported from the estimation path above):
	// read directly via st_data(1::nodes, "varname") from the ACTIVE
	// Stata dataset, exactly as estimation itself does - a network
	// object is not involved at all in this read, so nothing about
	// simulation-vs-estimation changes it. The caller needs `nodes'
	// observations with the named variable(s) already loaded (e.g.
	// `set obs 20' + `gen mygroup = ...' before calling simulate) -
	// documented in nwergm.sthlp's own Simulation section.
	local __ergm_termidx = 0
	foreach __ergm_v of local nodematch {
		_nwergm_numvar `__ergm_v' nodematch
		local ++__ergm_termidx
		local __td_nm`__ergm_termidx' "__netds_`++__nes_n'"
		mata: `__td_nm`__ergm_termidx'' = ErgmTermData()
		mata: `__td_nm`__ergm_termidx''.attr = st_data(1::`nodes', "`__ergm_v'")
		mata: __nwergm_last_M.addterm("nodematch", 1, &stat_nodematch(), &change_nodematch(), `__td_nm`__ergm_termidx'', ("nodematch_`__ergm_v'"))
		local ntermtok "`ntermtok' nodematch_`__ergm_v'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_nm`__ergm_termidx''"
	}
	local __ergm_termidx = 0
	foreach __ergm_v of local nodecov {
		_nwergm_numvar `__ergm_v' nodecov
		local ++__ergm_termidx
		local __td_nc`__ergm_termidx' "__netds_`++__nes_n'"
		mata: `__td_nc`__ergm_termidx'' = ErgmTermData()
		mata: `__td_nc`__ergm_termidx''.attr = st_data(1::`nodes', "`__ergm_v'")
		mata: __nwergm_last_M.addterm("nodecov", 1, &stat_nodecov(), &change_nodecov(), `__td_nc`__ergm_termidx'', ("nodecov_`__ergm_v'"))
		local ntermtok "`ntermtok' nodecov_`__ergm_v'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_nc`__ergm_termidx''"
	}
	local __ergm_termidx = 0
	foreach __ergm_v of local nodeicov {
		_nwergm_numvar `__ergm_v' nodeicov
		local ++__ergm_termidx
		local __td_ni`__ergm_termidx' "__netds_`++__nes_n'"
		mata: `__td_ni`__ergm_termidx'' = ErgmTermData()
		mata: `__td_ni`__ergm_termidx''.attr = st_data(1::`nodes', "`__ergm_v'")
		mata: __nwergm_last_M.addterm("nodeicov", 1, &stat_nodeicov(), &change_nodeicov(), `__td_ni`__ergm_termidx'', ("nodeicov_`__ergm_v'"))
		local ntermtok "`ntermtok' nodeicov_`__ergm_v'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_ni`__ergm_termidx''"
	}
	local __ergm_termidx = 0
	foreach __ergm_v of local nodeocov {
		_nwergm_numvar `__ergm_v' nodeocov
		local ++__ergm_termidx
		local __td_no`__ergm_termidx' "__netds_`++__nes_n'"
		mata: `__td_no`__ergm_termidx'' = ErgmTermData()
		mata: `__td_no`__ergm_termidx''.attr = st_data(1::`nodes', "`__ergm_v'")
		mata: __nwergm_last_M.addterm("nodeocov", 1, &stat_nodeocov(), &change_nodeocov(), `__td_no`__ergm_termidx'', ("nodeocov_`__ergm_v'"))
		local ntermtok "`ntermtok' nodeocov_`__ergm_v'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_no`__ergm_termidx''"
	}
	local __ergm_termidx = 0
	foreach __ergm_v of local absdist {
		_nwergm_numvar `__ergm_v' absdist
		local ++__ergm_termidx
		local __td_ad`__ergm_termidx' "__netds_`++__nes_n'"
		mata: `__td_ad`__ergm_termidx'' = ErgmTermData()
		mata: `__td_ad`__ergm_termidx''.attr = st_data(1::`nodes', "`__ergm_v'")
		mata: __nwergm_last_M.addterm("absdist", 1, &stat_absdist(), &change_absdist(), `__td_ad`__ergm_termidx'', ("absdist_`__ergm_v'"))
		local ntermtok "`ntermtok' absdist_`__ergm_v'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_ad`__ergm_termidx''"
	}
	local __ergm_termidx = 0
	foreach __ergm_v of local nodematchdiff {
		_nwergm_numvar `__ergm_v' nodematchdiff
		local ++__ergm_termidx
		local __td_nmd`__ergm_termidx' "__netds_`++__nes_n'"
		mata: `__td_nmd`__ergm_termidx'' = ErgmTermData()
		mata: `__td_nmd`__ergm_termidx''.attr = st_data(1::`nodes', "`__ergm_v'")
		mata: `__td_nmd`__ergm_termidx''.levels = uniqrows(`__td_nmd`__ergm_termidx''.attr)
		mata: st_local("__ergm_nlev", strofreal(rows(`__td_nmd`__ergm_termidx''.levels)))
		tempname __ergm_levvec
		mata: st_matrix("`__ergm_levvec'", `__td_nmd`__ergm_termidx''.levels')
		local __ergm_cnames ""
		forvalues __k = 1/`__ergm_nlev' {
			local __ergm_cnames "`__ergm_cnames' nodematch_`__ergm_v'_`=`__ergm_levvec'[1,`__k']'"
		}
		mata: __nwergm_last_M.addterm("nodematch_diff", `__ergm_nlev', &stat_nodematch_diff(), &change_nodematch_diff(), `__td_nmd`__ergm_termidx'', tokens("`__ergm_cnames'"))
		local ntermtok "`ntermtok' `__ergm_cnames'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_nmd`__ergm_termidx''"
	}
	local __ergm_termidx = 0
	foreach __ergm_v of local nodefactor {
		_nwergm_numvar `__ergm_v' nodefactor
		local ++__ergm_termidx
		local __td_nf`__ergm_termidx' "__netds_`++__nes_n'"
		mata: `__td_nf`__ergm_termidx'' = ErgmTermData()
		mata: `__td_nf`__ergm_termidx''.attr = st_data(1::`nodes', "`__ergm_v'")
		mata: `__td_nf`__ergm_termidx''.levels = uniqrows(`__td_nf`__ergm_termidx''.attr)
		mata: `__td_nf`__ergm_termidx''.levels = _ergm_drop_base_level(`__td_nf`__ergm_termidx''.levels)
		mata: st_local("__ergm_nlev", strofreal(rows(`__td_nf`__ergm_termidx''.levels)))
		tempname __ergm_levvec2
		mata: st_matrix("`__ergm_levvec2'", `__td_nf`__ergm_termidx''.levels')
		local __ergm_cnames ""
		forvalues __k = 1/`__ergm_nlev' {
			local __ergm_cnames "`__ergm_cnames' nodefactor_`__ergm_v'_`=`__ergm_levvec2'[1,`__k']'"
		}
		mata: __nwergm_last_M.addterm("nodefactor", `__ergm_nlev', &stat_nodefactor(), &change_nodefactor(), `__td_nf`__ergm_termidx'', tokens("`__ergm_cnames'"))
		local ntermtok "`ntermtok' `__ergm_cnames'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_nf`__ergm_termidx''"
	}
	local __ergm_nodemix_b ""
	if `bipartite' != 0 {
		local __ergm_nodemix_b `"`nodemix'"'
		local nodemix ""
	}
	if `"`nodemix'"' != "" {
		_nwergm_cov nodemix, spec(`"`nodemix'"') nodes(`nodes') directed(`=cond("`directed'"!="","true","false")') twomode(`=cond(`bipartite'!=0,"true","false")')
		local ntermtok "`ntermtok' `r(cnames)'"
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
	}

	if `bipartite' != 0 {
		capture mata: mata drop __nwergm_bipG
		mata: __nwergm_bipG = ErgmGraph()
		mata: __nwergm_bipG.init(`nodes', 0)
		mata: __nwergm_bipG.set_bipartite((J(`bipartite',1,1) \ J(`nodes'-`bipartite',1,2)))
		mata: st_local("__ergm_c0", strofreal(cols(__nwergm_last_M.coefnames)))
		_nwergm_bip, nodes(`nodes') gname(__nwergm_bipG) bconcurrent1(`"`bconcurrent1'"') bconcurrent2(`"`bconcurrent2'"') bmindegree1(`"`bmindegree1'"') bmindegree2(`"`bmindegree2'"') bdegrange1(`"`bdegrange1'"') bdegrange2(`"`bdegrange2'"') bdegree1(`"`bdegree1'"') bdegree2(`"`bdegree2'"') bstar1(`"`bstar1'"') bstar2(`"`bstar2'"') bcovrange1(`"`bcovrange1'"') bcovrange2(`"`bcovrange2'"') bfactordistinct1(`"`bfactordistinct1'"') bfactordistinct2(`"`bfactordistinct2'"') bsociality1(`"`bsociality1'"') bsociality2(`"`bsociality2'"') bstarmix1(`"`bstarmix1'"') bstarmix2(`"`bstarmix2'"') btwostar1(`"`btwostar1'"') btwostar2(`"`btwostar2'"') coincidence(`"`coincidence'"') bdsp1(`"`bdsp1'"') bdsp2(`"`bdsp2'"') bgwdsp1(`"`bgwdsp1'"') bgwdsp2(`"`bgwdsp2'"') bnodematch1(`"`bnodematch1'"') bnodematch2(`"`bnodematch2'"') bgwdegree1(`"`bgwdegree1'"') bgwdegree2(`"`bgwdegree2'"') nodemix(`"`__ergm_nodemix_b'"')
		local __ergm_matatemps "`__ergm_matatemps' `__ergm_bipnewtemps'"
		local __ergm_newn ""
		mata: st_local("__ergm_c1", strofreal(cols(__nwergm_last_M.coefnames)))
		if `__ergm_c1' > `__ergm_c0' mata: st_local("__ergm_newn", invtokens(__nwergm_last_M.coefnames[(`__ergm_c0'+1)..`__ergm_c1']))
		local ntermtok "`ntermtok' `__ergm_newn'"
		capture mata: mata drop __nwergm_bipG
	}

	// --- bipartite (two-mode) terms: bcov1()/bcov2()/bfactor1()/
	// bfactor2()/bdegree1()/bdegree2()/bstar1()/bstar2()/bnodematch1()/
	// bnodematch2()/bgwdegree1()/bgwdegree2(), ported from the
	// estimation path above - only ever registered when `bipartite'!=0
	// (validated above). bfactor1()/bfactor2()'s own level-set is built
	// from the mode-1/mode-2 node INDEX RANGES directly (1::`bipartite''
	// / (`bipartite'+1)::`nodes'), not `__nwergm_last_G.mode1nodes'/
	// `mode2nodes' as the estimation path uses - simulate registers
	// every term BEFORE any ErgmGraph exists at all (a fresh one is
	// built per draw, inside the `nsim' loop below), whereas estimation
	// builds its one graph first. Both give the identical index set
	// here since this program's own `bipartite()' option IS exactly
	// that contiguous "mode-1 nodes are indices 1..bipartite()"
	// convention (see the validation block above's own header comment).
	local __ergm_termidx = 0
	foreach __ergm_v of local bcov1 {
		_nwergm_numvar `__ergm_v' bcov1
		local ++__ergm_termidx
		local __td_b1c`__ergm_termidx' "__netds_`++__nes_n'"
		mata: `__td_b1c`__ergm_termidx'' = ErgmTermData()
		mata: `__td_b1c`__ergm_termidx''.attr = st_data(1::`nodes', "`__ergm_v'")
		mata: __nwergm_last_M.addterm("b1cov", 1, &stat_b1cov(), &change_b1cov(), `__td_b1c`__ergm_termidx'', ("b1cov_`__ergm_v'"))
		local ntermtok "`ntermtok' b1cov_`__ergm_v'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_b1c`__ergm_termidx''"
	}
	local __ergm_termidx = 0
	foreach __ergm_v of local bcov2 {
		_nwergm_numvar `__ergm_v' bcov2
		local ++__ergm_termidx
		local __td_b2c`__ergm_termidx' "__netds_`++__nes_n'"
		mata: `__td_b2c`__ergm_termidx'' = ErgmTermData()
		mata: `__td_b2c`__ergm_termidx''.attr = st_data(1::`nodes', "`__ergm_v'")
		mata: __nwergm_last_M.addterm("b2cov", 1, &stat_b2cov(), &change_b2cov(), `__td_b2c`__ergm_termidx'', ("b2cov_`__ergm_v'"))
		local ntermtok "`ntermtok' b2cov_`__ergm_v'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_b2c`__ergm_termidx''"
	}
	local __ergm_termidx = 0
	foreach __ergm_v of local bfactor1 {
		_nwergm_numvar `__ergm_v' bfactor1
		local ++__ergm_termidx
		local __td_b1f`__ergm_termidx' "__netds_`++__nes_n'"
		mata: `__td_b1f`__ergm_termidx'' = ErgmTermData()
		mata: `__td_b1f`__ergm_termidx''.attr = st_data(1::`nodes', "`__ergm_v'")
		mata: `__td_b1f`__ergm_termidx''.levels = uniqrows(`__td_b1f`__ergm_termidx''.attr[1::`bipartite'])
		mata: `__td_b1f`__ergm_termidx''.levels = _ergm_drop_base_level(`__td_b1f`__ergm_termidx''.levels)
		mata: st_local("__ergm_nlev", strofreal(rows(`__td_b1f`__ergm_termidx''.levels)))
		tempname __ergm_levvec_b1f
		mata: st_matrix("`__ergm_levvec_b1f'", `__td_b1f`__ergm_termidx''.levels')
		local __ergm_cnames ""
		forvalues __k = 1/`__ergm_nlev' {
			local __ergm_cnames "`__ergm_cnames' b1factor_`__ergm_v'_`=`__ergm_levvec_b1f'[1,`__k']'"
		}
		mata: __nwergm_last_M.addterm("b1factor", `__ergm_nlev', &stat_b1factor(), &change_b1factor(), `__td_b1f`__ergm_termidx'', tokens("`__ergm_cnames'"))
		local ntermtok "`ntermtok' `__ergm_cnames'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_b1f`__ergm_termidx''"
	}
	local __ergm_termidx = 0
	foreach __ergm_v of local bfactor2 {
		_nwergm_numvar `__ergm_v' bfactor2
		local ++__ergm_termidx
		local __td_b2f`__ergm_termidx' "__netds_`++__nes_n'"
		mata: `__td_b2f`__ergm_termidx'' = ErgmTermData()
		mata: `__td_b2f`__ergm_termidx''.attr = st_data(1::`nodes', "`__ergm_v'")
		mata: `__td_b2f`__ergm_termidx''.levels = uniqrows(`__td_b2f`__ergm_termidx''.attr[(`bipartite'+1)::`nodes'])
		mata: `__td_b2f`__ergm_termidx''.levels = _ergm_drop_base_level(`__td_b2f`__ergm_termidx''.levels)
		mata: st_local("__ergm_nlev", strofreal(rows(`__td_b2f`__ergm_termidx''.levels)))
		tempname __ergm_levvec_b2f
		mata: st_matrix("`__ergm_levvec_b2f'", `__td_b2f`__ergm_termidx''.levels')
		local __ergm_cnames ""
		forvalues __k = 1/`__ergm_nlev' {
			local __ergm_cnames "`__ergm_cnames' b2factor_`__ergm_v'_`=`__ergm_levvec_b2f'[1,`__k']'"
		}
		mata: __nwergm_last_M.addterm("b2factor", `__ergm_nlev', &stat_b2factor(), &change_b2factor(), `__td_b2f`__ergm_termidx'', tokens("`__ergm_cnames'"))
		local ntermtok "`ntermtok' `__ergm_cnames'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_b2f`__ergm_termidx''"
	}
	if "`bdegree1'" != "" {
		local __td_bd1 "__netds_`++__nes_n'"
		mata: `__td_bd1' = ErgmTermData()
		mata: `__td_bd1'.levels = strtoreal(tokens("`bdegree1'"))'
		mata: st_local("__ergm_ndeg", strofreal(rows(`__td_bd1'.levels)))
		local __ergm_cnames ""
		foreach __ergm_dv of numlist `bdegree1' {
			local __ergm_cnames "`__ergm_cnames' b1degree_`__ergm_dv'"
		}
		mata: __nwergm_last_M.addterm("b1degree", `__ergm_ndeg', &stat_b1degree(), &change_b1degree(), `__td_bd1', tokens("`__ergm_cnames'"))
		local ntermtok "`ntermtok' `__ergm_cnames'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_bd1'"
	}
	if "`bdegree2'" != "" {
		local __td_bd2 "__netds_`++__nes_n'"
		mata: `__td_bd2' = ErgmTermData()
		mata: `__td_bd2'.levels = strtoreal(tokens("`bdegree2'"))'
		mata: st_local("__ergm_ndeg", strofreal(rows(`__td_bd2'.levels)))
		local __ergm_cnames ""
		foreach __ergm_dv of numlist `bdegree2' {
			local __ergm_cnames "`__ergm_cnames' b2degree_`__ergm_dv'"
		}
		mata: __nwergm_last_M.addterm("b2degree", `__ergm_ndeg', &stat_b2degree(), &change_b2degree(), `__td_bd2', tokens("`__ergm_cnames'"))
		local ntermtok "`ntermtok' `__ergm_cnames'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_bd2'"
	}
	if "`bstar1'" != "" {
		local __td_bs1 "__netds_`++__nes_n'"
		mata: `__td_bs1' = ErgmTermData()
		mata: `__td_bs1'.levels = strtoreal(tokens("`bstar1'"))'
		mata: st_local("__ergm_nk", strofreal(rows(`__td_bs1'.levels)))
		local __ergm_cnames ""
		foreach __ergm_kv of numlist `bstar1' {
			local __ergm_cnames "`__ergm_cnames' b1star_`__ergm_kv'"
		}
		mata: __nwergm_last_M.addterm("b1star", `__ergm_nk', &stat_b1star(), &change_b1star(), `__td_bs1', tokens("`__ergm_cnames'"))
		local ntermtok "`ntermtok' `__ergm_cnames'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_bs1'"
	}
	if "`bstar2'" != "" {
		local __td_bs2 "__netds_`++__nes_n'"
		mata: `__td_bs2' = ErgmTermData()
		mata: `__td_bs2'.levels = strtoreal(tokens("`bstar2'"))'
		mata: st_local("__ergm_nk", strofreal(rows(`__td_bs2'.levels)))
		local __ergm_cnames ""
		foreach __ergm_kv of numlist `bstar2' {
			local __ergm_cnames "`__ergm_cnames' b2star_`__ergm_kv'"
		}
		mata: __nwergm_last_M.addterm("b2star", `__ergm_nk', &stat_b2star(), &change_b2star(), `__td_bs2', tokens("`__ergm_cnames'"))
		local ntermtok "`ntermtok' `__ergm_cnames'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_bs2'"
	}
	local __ergm_termidx = 0
	foreach __ergm_v of local bnodematch1 {
		_nwergm_numvar `__ergm_v' bnodematch1
		local ++__ergm_termidx
		local __td_b1nm`__ergm_termidx' "__netds_`++__nes_n'"
		mata: `__td_b1nm`__ergm_termidx'' = ErgmTermData()
		mata: `__td_b1nm`__ergm_termidx''.attr = st_data(1::`nodes', "`__ergm_v'")
		mata: __nwergm_last_M.addterm("b1nodematch", 1, &stat_b1nodematch(), &change_b1nodematch(), `__td_b1nm`__ergm_termidx'', ("b1nodematch_`__ergm_v'"))
		local ntermtok "`ntermtok' b1nodematch_`__ergm_v'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_b1nm`__ergm_termidx''"
	}
	local __ergm_termidx = 0
	foreach __ergm_v of local bnodematch2 {
		_nwergm_numvar `__ergm_v' bnodematch2
		local ++__ergm_termidx
		local __td_b2nm`__ergm_termidx' "__netds_`++__nes_n'"
		mata: `__td_b2nm`__ergm_termidx'' = ErgmTermData()
		mata: `__td_b2nm`__ergm_termidx''.attr = st_data(1::`nodes', "`__ergm_v'")
		mata: __nwergm_last_M.addterm("b2nodematch", 1, &stat_b2nodematch(), &change_b2nodematch(), `__td_b2nm`__ergm_termidx'', ("b2nodematch_`__ergm_v'"))
		local ntermtok "`ntermtok' b2nodematch_`__ergm_v'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_b2nm`__ergm_termidx''"
	}
	if "`bgwdegree1'" != "" {
		local __td_bgwd1 "__netds_`++__nes_n'"
		mata: `__td_bgwd1' = ErgmTermData()
		mata: `__td_bgwd1'.decay = `bgwdegree1'
		mata: __nwergm_last_M.addterm("bgwdegree1", 1, &stat_bgwdegree1(), &change_bgwdegree1(), `__td_bgwd1', ("bgwdegree1"))
		local ntermtok "`ntermtok' bgwdegree1"
		local __ergm_matatemps "`__ergm_matatemps' `__td_bgwd1'"
	}
	if "`bgwdegree2'" != "" {
		local __td_bgwd2 "__netds_`++__nes_n'"
		mata: `__td_bgwd2' = ErgmTermData()
		mata: `__td_bgwd2'.decay = `bgwdegree2'
		mata: __nwergm_last_M.addterm("bgwdegree2", 1, &stat_bgwdegree2(), &change_bgwdegree2(), `__td_bgwd2', ("bgwdegree2"))
		local ntermtok "`ntermtok' bgwdegree2"
		local __ergm_matatemps "`__ergm_matatemps' `__td_bgwd2'"
	}

	// --- structural terms with no covariate data at all: numlist-
	// parameterized (degree()/odegree()/idegree()/kstar()/ostar()/
	// istar()/degrange()/odegrange()/idegrange()/esp()/dsp()) or plain
	// flags (concurrent/triangle/ctriple/transitiveties/cyclicalties) -
	// ported verbatim from the estimation path, which needs nothing
	// beyond the term's own parameters either.
	if "`degree'" != "" {
		local __td_deg "__netds_`++__nes_n'"
		mata: `__td_deg' = ErgmTermData()
		mata: `__td_deg'.levels = strtoreal(tokens("`degree'"))'
		mata: st_local("__ergm_ndeg", strofreal(rows(`__td_deg'.levels)))
		local __ergm_cnames ""
		foreach __ergm_dv of numlist `degree' {
			local __ergm_cnames "`__ergm_cnames' degree_`__ergm_dv'"
		}
		mata: __nwergm_last_M.addterm("degree", `__ergm_ndeg', &stat_degree(), &change_degree(), `__td_deg', tokens("`__ergm_cnames'"))
		local ntermtok "`ntermtok' `__ergm_cnames'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_deg'"
	}
	if "`odegree'" != "" {
		local __td_odeg "__netds_`++__nes_n'"
		mata: `__td_odeg' = ErgmTermData()
		mata: `__td_odeg'.levels = strtoreal(tokens("`odegree'"))'
		mata: st_local("__ergm_ndeg", strofreal(rows(`__td_odeg'.levels)))
		local __ergm_cnames ""
		foreach __ergm_dv of numlist `odegree' {
			local __ergm_cnames "`__ergm_cnames' odegree_`__ergm_dv'"
		}
		mata: __nwergm_last_M.addterm("odegree", `__ergm_ndeg', &stat_odegree(), &change_odegree(), `__td_odeg', tokens("`__ergm_cnames'"))
		local ntermtok "`ntermtok' `__ergm_cnames'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_odeg'"
	}
	if "`idegree'" != "" {
		local __td_ideg "__netds_`++__nes_n'"
		mata: `__td_ideg' = ErgmTermData()
		mata: `__td_ideg'.levels = strtoreal(tokens("`idegree'"))'
		mata: st_local("__ergm_ndeg", strofreal(rows(`__td_ideg'.levels)))
		local __ergm_cnames ""
		foreach __ergm_dv of numlist `idegree' {
			local __ergm_cnames "`__ergm_cnames' idegree_`__ergm_dv'"
		}
		mata: __nwergm_last_M.addterm("idegree", `__ergm_ndeg', &stat_idegree(), &change_idegree(), `__td_ideg', tokens("`__ergm_cnames'"))
		local ntermtok "`ntermtok' `__ergm_cnames'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_ideg'"
	}
	if "`concurrent'" != "" {
		local __td_conc "__netds_`++__nes_n'"
		mata: `__td_conc' = ErgmTermData()
		mata: __nwergm_last_M.addterm("concurrent", 1, &stat_concurrent(), &change_concurrent(), `__td_conc', ("concurrent"))
		local ntermtok "`ntermtok' concurrent"
		local __ergm_matatemps "`__ergm_matatemps' `__td_conc'"
	}
	if "`triangle'" != "" {
		local __td_tri "__netds_`++__nes_n'"
		mata: `__td_tri' = ErgmTermData()
		mata: __nwergm_last_M.addterm("triangle", 1, &stat_triangle(), &change_triangle(), `__td_tri', ("triangle"))
		local ntermtok "`ntermtok' triangle"
		local __ergm_matatemps "`__ergm_matatemps' `__td_tri'"
	}
	if "`ctriple'" != "" {
		local __td_ctri "__netds_`++__nes_n'"
		mata: `__td_ctri' = ErgmTermData()
		mata: __nwergm_last_M.addterm("ctriple", 1, &stat_ctriple(), &change_ctriple(), `__td_ctri', ("ctriple"))
		local ntermtok "`ntermtok' ctriple"
		local __ergm_matatemps "`__ergm_matatemps' `__td_ctri'"
	}

	local __ergm_termidx = 0
	foreach __ergm_v of local nodeofactor {
		_nwergm_numvar `__ergm_v' nodeofactor
		local ++__ergm_termidx
		local __td_nof`__ergm_termidx' "__netds_`++__nes_n'"
		mata: `__td_nof`__ergm_termidx'' = ErgmTermData()
		mata: `__td_nof`__ergm_termidx''.attr = st_data(1::`nodes', "`__ergm_v'")
		mata: `__td_nof`__ergm_termidx''.levels = uniqrows(`__td_nof`__ergm_termidx''.attr)
		mata: `__td_nof`__ergm_termidx''.levels = _ergm_drop_base_level(`__td_nof`__ergm_termidx''.levels)
		mata: st_local("__ergm_nlev", strofreal(rows(`__td_nof`__ergm_termidx''.levels)))
		tempname __ergm_levvec3
		mata: st_matrix("`__ergm_levvec3'", `__td_nof`__ergm_termidx''.levels')
		local __ergm_cnames ""
		forvalues __k = 1/`__ergm_nlev' {
			local __ergm_cnames "`__ergm_cnames' nodeofactor_`__ergm_v'_`=`__ergm_levvec3'[1,`__k']'"
		}
		mata: __nwergm_last_M.addterm("nodeofactor", `__ergm_nlev', &stat_nodeofactor(), &change_nodeofactor(), `__td_nof`__ergm_termidx'', tokens("`__ergm_cnames'"))
		local ntermtok "`ntermtok' `__ergm_cnames'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_nof`__ergm_termidx''"
	}
	local __ergm_termidx = 0
	foreach __ergm_v of local nodeifactor {
		_nwergm_numvar `__ergm_v' nodeifactor
		local ++__ergm_termidx
		local __td_nif`__ergm_termidx' "__netds_`++__nes_n'"
		mata: `__td_nif`__ergm_termidx'' = ErgmTermData()
		mata: `__td_nif`__ergm_termidx''.attr = st_data(1::`nodes', "`__ergm_v'")
		mata: `__td_nif`__ergm_termidx''.levels = uniqrows(`__td_nif`__ergm_termidx''.attr)
		mata: `__td_nif`__ergm_termidx''.levels = _ergm_drop_base_level(`__td_nif`__ergm_termidx''.levels)
		mata: st_local("__ergm_nlev", strofreal(rows(`__td_nif`__ergm_termidx''.levels)))
		tempname __ergm_levvec4
		mata: st_matrix("`__ergm_levvec4'", `__td_nif`__ergm_termidx''.levels')
		local __ergm_cnames ""
		forvalues __k = 1/`__ergm_nlev' {
			local __ergm_cnames "`__ergm_cnames' nodeifactor_`__ergm_v'_`=`__ergm_levvec4'[1,`__k']'"
		}
		mata: __nwergm_last_M.addterm("nodeifactor", `__ergm_nlev', &stat_nodeifactor(), &change_nodeifactor(), `__td_nif`__ergm_termidx'', tokens("`__ergm_cnames'"))
		local ntermtok "`ntermtok' `__ergm_cnames'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_nif`__ergm_termidx''"
	}

	if "`kstar'" != "" {
		local __td_kstar "__netds_`++__nes_n'"
		mata: `__td_kstar' = ErgmTermData()
		mata: `__td_kstar'.levels = strtoreal(tokens("`kstar'"))'
		mata: st_local("__ergm_nk", strofreal(rows(`__td_kstar'.levels)))
		local __ergm_cnames ""
		foreach __ergm_kv of numlist `kstar' {
			local __ergm_cnames "`__ergm_cnames' kstar_`__ergm_kv'"
		}
		mata: __nwergm_last_M.addterm("kstar", `__ergm_nk', &stat_kstar(), &change_kstar(), `__td_kstar', tokens("`__ergm_cnames'"))
		local ntermtok "`ntermtok' `__ergm_cnames'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_kstar'"
	}
	if "`ostar'" != "" {
		local __td_ostar "__netds_`++__nes_n'"
		mata: `__td_ostar' = ErgmTermData()
		mata: `__td_ostar'.levels = strtoreal(tokens("`ostar'"))'
		mata: st_local("__ergm_nk", strofreal(rows(`__td_ostar'.levels)))
		local __ergm_cnames ""
		foreach __ergm_kv of numlist `ostar' {
			local __ergm_cnames "`__ergm_cnames' ostar_`__ergm_kv'"
		}
		mata: __nwergm_last_M.addterm("ostar", `__ergm_nk', &stat_ostar(), &change_ostar(), `__td_ostar', tokens("`__ergm_cnames'"))
		local ntermtok "`ntermtok' `__ergm_cnames'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_ostar'"
	}
	if "`istar'" != "" {
		local __td_istar "__netds_`++__nes_n'"
		mata: `__td_istar' = ErgmTermData()
		mata: `__td_istar'.levels = strtoreal(tokens("`istar'"))'
		mata: st_local("__ergm_nk", strofreal(rows(`__td_istar'.levels)))
		local __ergm_cnames ""
		foreach __ergm_kv of numlist `istar' {
			local __ergm_cnames "`__ergm_cnames' istar_`__ergm_kv'"
		}
		mata: __nwergm_last_M.addterm("istar", `__ergm_nk', &stat_istar(), &change_istar(), `__td_istar', tokens("`__ergm_cnames'"))
		local ntermtok "`ntermtok' `__ergm_cnames'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_istar'"
	}

	if "`degrange'" != "" {
		local __ergm_ndr : word count `degrange'
		if "`degrangeto'" == "" {
			local __ergm_dto ""
			forvalues __k = 1/`__ergm_ndr' {
				local __ergm_dto "`__ergm_dto' ."
			}
		}
		else {
			local __ergm_dto "`degrangeto'"
			local __ergm_ndto : word count `degrangeto'
			if `__ergm_ndto' != `__ergm_ndr' {
				di "{err}degrange() and degrangeto() must supply the same number of values."
				error 198
			}
		}
		local __td_dr "__netds_`++__nes_n'"
		mata: `__td_dr' = ErgmTermData()
		mata: `__td_dr'.levelpairs = strtoreal(tokens("`degrange'"))' , strtoreal(tokens("`__ergm_dto'"))'
		local __ergm_cnames ""
		forvalues __k = 1/`__ergm_ndr' {
			local __ergm_cnames "`__ergm_cnames' degrange_`__k'"
		}
		mata: __nwergm_last_M.addterm("degrange", `__ergm_ndr', &stat_degrange(), &change_degrange(), `__td_dr', tokens("`__ergm_cnames'"))
		local ntermtok "`ntermtok' `__ergm_cnames'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_dr'"
	}
	if "`odegrange'" != "" {
		local __ergm_ndr : word count `odegrange'
		if "`odegrangeto'" == "" {
			local __ergm_dto ""
			forvalues __k = 1/`__ergm_ndr' {
				local __ergm_dto "`__ergm_dto' ."
			}
		}
		else {
			local __ergm_dto "`odegrangeto'"
			local __ergm_ndto : word count `odegrangeto'
			if `__ergm_ndto' != `__ergm_ndr' {
				di "{err}odegrange() and odegrangeto() must supply the same number of values."
				error 198
			}
		}
		local __td_odr "__netds_`++__nes_n'"
		mata: `__td_odr' = ErgmTermData()
		mata: `__td_odr'.levelpairs = strtoreal(tokens("`odegrange'"))' , strtoreal(tokens("`__ergm_dto'"))'
		local __ergm_cnames ""
		forvalues __k = 1/`__ergm_ndr' {
			local __ergm_cnames "`__ergm_cnames' odegrange_`__k'"
		}
		mata: __nwergm_last_M.addterm("odegrange", `__ergm_ndr', &stat_odegrange(), &change_odegrange(), `__td_odr', tokens("`__ergm_cnames'"))
		local ntermtok "`ntermtok' `__ergm_cnames'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_odr'"
	}
	if "`idegrange'" != "" {
		local __ergm_ndr : word count `idegrange'
		if "`idegrangeto'" == "" {
			local __ergm_dto ""
			forvalues __k = 1/`__ergm_ndr' {
				local __ergm_dto "`__ergm_dto' ."
			}
		}
		else {
			local __ergm_dto "`idegrangeto'"
			local __ergm_ndto : word count `idegrangeto'
			if `__ergm_ndto' != `__ergm_ndr' {
				di "{err}idegrange() and idegrangeto() must supply the same number of values."
				error 198
			}
		}
		local __td_idr "__netds_`++__nes_n'"
		mata: `__td_idr' = ErgmTermData()
		mata: `__td_idr'.levelpairs = strtoreal(tokens("`idegrange'"))' , strtoreal(tokens("`__ergm_dto'"))'
		local __ergm_cnames ""
		forvalues __k = 1/`__ergm_ndr' {
			local __ergm_cnames "`__ergm_cnames' idegrange_`__k'"
		}
		mata: __nwergm_last_M.addterm("idegrange", `__ergm_ndr', &stat_idegrange(), &change_idegrange(), `__td_idr', tokens("`__ergm_cnames'"))
		local ntermtok "`ntermtok' `__ergm_cnames'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_idr'"
	}

	if "`esp'" != "" {
		local __ergm_nd : word count `esp'
		local __td_esp "__netds_`++__nes_n'"
		mata: `__td_esp' = ErgmTermData()
		mata: `__td_esp'.levels = strtoreal(tokens("`esp'"))'
		if "`directed'" != "" {
			mata: `__td_esp'.sptype = "`type'"
		}
		local __ergm_cnames ""
		foreach __ergm_dv of numlist `esp' {
			local __ergm_cnames "`__ergm_cnames' esp`__ergm_dv'"
		}
		mata: __nwergm_last_M.addterm("esp", `__ergm_nd', &stat_esp(), &change_esp(), `__td_esp', tokens("`__ergm_cnames'"))
		local ntermtok "`ntermtok' `__ergm_cnames'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_esp'"
	}
	if "`dsp'" != "" {
		local __ergm_nd : word count `dsp'
		local __td_dsp2 "__netds_`++__nes_n'"
		mata: `__td_dsp2' = ErgmTermData()
		mata: `__td_dsp2'.levels = strtoreal(tokens("`dsp'"))'
		if "`directed'" != "" {
			mata: `__td_dsp2'.sptype = "`type'"
		}
		local __ergm_cnames ""
		foreach __ergm_dv of numlist `dsp' {
			local __ergm_cnames "`__ergm_cnames' dsp`__ergm_dv'"
		}
		mata: __nwergm_last_M.addterm("dsp", `__ergm_nd', &stat_dsp(), &change_dsp(), `__td_dsp2', tokens("`__ergm_cnames'"))
		local ntermtok "`ntermtok' `__ergm_cnames'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_dsp2'"
	}

	if "`transitiveties'" != "" {
		local __td_tt "__netds_`++__nes_n'"
		mata: `__td_tt' = ErgmTermData()
		mata: __nwergm_last_M.addterm("transitiveties", 1, &stat_transitiveties(), &change_transitiveties(), `__td_tt', ("transitiveties"))
		local ntermtok "`ntermtok' transitiveties"
		local __ergm_matatemps "`__ergm_matatemps' `__td_tt'"
	}
	if "`cyclicalties'" != "" {
		local __td_ct "__netds_`++__nes_n'"
		mata: `__td_ct' = ErgmTermData()
		mata: __nwergm_last_M.addterm("cyclicalties", 1, &stat_cyclicalties(), &change_cyclicalties(), `__td_ct', ("cyclicalties"))
		local ntermtok "`ntermtok' cyclicalties"
		local __ergm_matatemps "`__ergm_matatemps' `__td_ct'"
	}
	if `"`structural'"' != "" {
		_nwergm_struct simulated, terms(`structural') nodes(`nodes') directed(`=cond("`directed'" != "", "true", "false")') type(`type')
		local __ergm_matatemps "`__ergm_matatemps' `r(temps)'"
		local ntermtok "`ntermtok' `r(cnames)'"
	}

	// sender()/receiver(): per-node out-/in-degree fixed effects, base=1
	// omitted - the node's own identity (1..nodes) IS the "attribute",
	// reusing stat_nodeofactor()/stat_nodeifactor() with no new Mata code,
	// exactly as the estimation path does.
	if "`sender'" != "" {
		local __td_send "__netds_`++__nes_n'"
		mata: `__td_send' = ErgmTermData()
		mata: `__td_send'.attr = (1::`nodes')
		mata: `__td_send'.levels = (2::`nodes')
		local __ergm_cnames ""
		forvalues __k = 2/`nodes' {
			local __ergm_cnames "`__ergm_cnames' sender`__k'"
		}
		mata: __nwergm_last_M.addterm("sender", `nodes'-1, &stat_nodeofactor(), &change_nodeofactor(), `__td_send', tokens("`__ergm_cnames'"))
		local ntermtok "`ntermtok' `__ergm_cnames'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_send'"
	}
	if "`receiver'" != "" {
		local __td_recv "__netds_`++__nes_n'"
		mata: `__td_recv' = ErgmTermData()
		mata: `__td_recv'.attr = (1::`nodes')
		mata: `__td_recv'.levels = (2::`nodes')
		local __ergm_cnames ""
		forvalues __k = 2/`nodes' {
			local __ergm_cnames "`__ergm_cnames' receiver`__k'"
		}
		mata: __nwergm_last_M.addterm("receiver", `nodes'-1, &stat_nodeifactor(), &change_nodeifactor(), `__td_recv', tokens("`__ergm_cnames'"))
		local ntermtok "`ntermtok' `__ergm_cnames'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_recv'"
	}

	// --- dyadic-covariate terms: edgecov()/hamming() reference ANOTHER
	// already-loaded network (not a plain variable) - resolved via
	// _nwsyntax exactly as the estimation path does, just checked
	// against the `nodes' argument instead of an observed netname's own
	// size (simulate has no observed network to compare against).
	local __ergm_termidx = 0
	foreach __ergm_v of local edgecov {
		local ++__ergm_termidx
		local __td_ec`__ergm_termidx' "__netds_`++__nes_n'"
		mata: `__td_ec`__ergm_termidx'' = ErgmTermData()
		_nwsyntax `__ergm_v', max(1) other(ec`__ergm_termidx')
		if `ec`__ergm_termidx'nodes' != `nodes' {
			di "{p 0 0 2}{err}edgecov() network {bf:`__ergm_v'} has a different number of nodes than requested ({bf:`nodes'}).{p_end}"
			error 198
		}
		mata: `__td_ec`__ergm_termidx''.edgecovmat = *(`ec`__ergm_termidx'netobj'->get_matrix_mod(1,("`directed'"!="")))
		mata: __nwergm_last_M.addterm("edgecov", 1, &stat_edgecov(), &change_edgecov(), `__td_ec`__ergm_termidx'', ("edgecov_`__ergm_v'"))
		local ntermtok "`ntermtok' edgecov_`__ergm_v'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_ec`__ergm_termidx''"
	}
	local __ergm_termidx = 0
	foreach __ergm_v of local hamming {
		local ++__ergm_termidx
		local __td_hm`__ergm_termidx' "__netds_`++__nes_n'"
		mata: `__td_hm`__ergm_termidx'' = ErgmTermData()
		_nwsyntax `__ergm_v', max(1) other(hm`__ergm_termidx')
		if `hm`__ergm_termidx'nodes' != `nodes' {
			di "{p 0 0 2}{err}hamming() network {bf:`__ergm_v'} has a different number of nodes than requested ({bf:`nodes'}).{p_end}"
			error 198
		}
		mata: `__td_hm`__ergm_termidx''.edgecovmat = *(`hm`__ergm_termidx'netobj'->get_matrix_mod(0,("`directed'"!="")))
		mata: __nwergm_last_M.addterm("hamming", 1, &stat_hamming(), &change_hamming(), `__td_hm`__ergm_termidx'', ("hamming_`__ergm_v'"))
		local ntermtok "`ntermtok' hamming_`__ergm_v'"
		local __ergm_matatemps "`__ergm_matatemps' `__td_hm`__ergm_termidx''"
	}

	if `__has_gwesp' {
		tempname td_gwesp
		mata: `td_gwesp' = ErgmTermData()
		mata: `td_gwesp'.decay = `gwesp'
		if "`directed'" != "" {
			mata: `td_gwesp'.sptype = "`type'"
		}
		mata: __nwergm_last_M.addterm("gwesp", 1, &stat_gwesp(), &change_gwesp(), `td_gwesp', ("gwesp"))
		local ntermtok "`ntermtok' gwesp"
		local __ergm_matatemps "`__ergm_matatemps' `td_gwesp'"
	}
	if `__has_gwdsp' {
		tempname td_gwdsp
		mata: `td_gwdsp' = ErgmTermData()
		mata: `td_gwdsp'.decay = `gwdsp'
		if "`directed'" != "" {
			mata: `td_gwdsp'.sptype = "`type'"
		}
		mata: __nwergm_last_M.addterm("gwdsp", 1, &stat_gwdsp(), &change_gwdsp(), `td_gwdsp', ("gwdsp"))
		local ntermtok "`ntermtok' gwdsp"
		local __ergm_matatemps "`__ergm_matatemps' `td_gwdsp'"
	}
	if `__has_gwnsp' {
		tempname td_gwnsp
		mata: `td_gwnsp' = ErgmTermData()
		mata: `td_gwnsp'.decay = `gwnsp'
		if "`directed'" != "" {
			mata: `td_gwnsp'.sptype = "`type'"
		}
		mata: __nwergm_last_M.addterm("gwnsp", 1, &stat_gwnsp(), &change_gwnsp(), `td_gwnsp', ("gwnsp"))
		local ntermtok "`ntermtok' gwnsp"
		local __ergm_matatemps "`__ergm_matatemps' `td_gwnsp'"
	}
	if `__has_gwdegree' {
		tempname td_gwdeg
		mata: `td_gwdeg' = ErgmTermData()
		mata: `td_gwdeg'.decay = `gwdegree'
		mata: __nwergm_last_M.addterm("gwdegree", 1, &stat_gwdegree(), &change_gwdegree(), `td_gwdeg', ("gwdegree"))
		local ntermtok "`ntermtok' gwdegree"
		local __ergm_matatemps "`__ergm_matatemps' `td_gwdeg'"
	}
	if `__has_gwodegree' {
		tempname td_gwod
		mata: `td_gwod' = ErgmTermData()
		mata: `td_gwod'.decay = `gwodegree'
		mata: __nwergm_last_M.addterm("gwodegree", 1, &stat_gwodegree(), &change_gwodegree(), `td_gwod', ("gwodegree"))
		local ntermtok "`ntermtok' gwodegree"
		local __ergm_matatemps "`__ergm_matatemps' `td_gwod'"
	}
	if `__has_gwidegree' {
		tempname td_gwid
		mata: `td_gwid' = ErgmTermData()
		mata: `td_gwid'.decay = `gwidegree'
		mata: __nwergm_last_M.addterm("gwidegree", 1, &stat_gwidegree(), &change_gwidegree(), `td_gwid', ("gwidegree"))
		local ntermtok "`ntermtok' gwidegree"
		local __ergm_matatemps "`__ergm_matatemps' `td_gwid'"
	}

	local nterm : word count `ntermtok'
	local nth : word count `theta'
	if `nth' != `nterm' {
		di "{p 0 0 2}{err}theta() supplies `nth' coefficient(s) but `nterm' term(s) were requested (`ntermtok') - exactly one coefficient per term, in listed order.{p_end}"
		error 198
	}
	tempname thetamat
	matrix `thetamat' = J(1, `nterm', 0)
	forvalues __k = 1/`nterm' {
		matrix `thetamat'[1,`__k'] = `: word `__k' of `theta''
	}

	// spcache: same option/cache as the main nwergm program (see its own
	// build-up comment), computed ONCE here rather than per-draw below.
	// Note the cost-benefit here is even less favorable than in
	// estimation: each simulated draw gets a FRESH ErgmGraph (see the
	// loop below), so the cache's O(sum deg^2) build cost is paid nsim
	// times over, against only `mcmcburnin' toggles of benefit per draw
	// (not an entire MCMLE run's worth) - offered for consistency with
	// the estimation command, not because it is expected to help here.
	mata: __nwergm_last_M.coefnames = ergm_coefnames32(__nwergm_last_M.coefnames)
	local __ergm_spcache_relevant = (`__has_gwesp' | `__has_gwdsp' | `__has_gwnsp' | "`esp'"!="" | "`dsp'"!="" | "`triangle'"!="" | "`ctriple'"!="")
	if "`spcache'" != "" {
		if "`directed'" != "" {
			di "{p 0 0 2}{err}note: option {bf:spcache} has no effect on a directed simulation; the incremental shared-partner cache only implements the undirected shared-partner definition.{p_end}"
		}
		else if !`__ergm_spcache_relevant' {
			di "{p 0 0 2}{err}note: option {bf:spcache} has no effect without gwesp()/gwdsp()/gwnsp()/esp()/dsp()/triangle/ctriple; none of those terms was requested.{p_end}"
		}
	}
	local __ergm_spcache_used = ("`spcache'"!="" & "`directed'"=="" & `__ergm_spcache_relevant')

	// BUGFIX: used to render the simulated draw's dense adjacency matrix
	// as a literal Stata matrix-expression string (ErgmMatToLiteral())
	// and hand that to nwset's own mat() option, which hits Stata's own
	// "too many tokens" command-line limit somewhere around 16 nodes
	// (confirmed directly - see nwergm_estat.ado's identical fix for the
	// full account) - `nwergm ..., simulate' was completely broken for
	// any network that size or larger, not merely slow. Fixed the same
	// way: pass the matrix as a bare Mata variable name instead of a
	// literal expression string, which nwset's own mat() option already
	// accepts directly (the same pattern nwrandom.ado's own generators
	// already use) and has no size limit to hit.
	tempname __ergm_simmat
	tempname __ergm_simmat_bip
	// basis()/constraints(): R's simulate(basis=, constraints=) - one chain started from the basis
	// network, burn-in once, `interval' steps between draws, all within the constrained sample space.
	// the SPDyad proposal (R's default hint .triadic) on a one-mode network with the tie/no-tie weighting
	local __spd = (`__spdfocus' >= 0 & "`proposal'" == "tnt" & `bipartite' == 0)
	local __sim_con 0
	local __simlabs ""
	if "`basis'" != "" | `"`constraints'"' != "" {
		if "`basis'" == "" {
			di "{err}constraints() needs basis(): the network the constraints refer to."
			error 198
		}
		if `bipartite' != 0 {
			di "{err}basis()/constraints() are not available together with bipartite()."
			error 198
		}
		_nwsyntax `basis', max(1) other(b)
		if `bnodes' != `nodes' | ("`bdirected'" == "true") != ("`directed'" != "") {
			di "{err}basis() must have `nodes' nodes and the same directedness as the simulation."
			error 198
		}
		capture mata: mata drop __nwergm_last_G
		mata: __nwergm_last_G = ErgmGraph()
		mata: __nwergm_last_G.init(`nodes', ("`directed'"!=""))
		mata: ergm_bridge_from_netobj(`bnetobj', __nwergm_last_G, ("`directed'"!=""))
		// node i of the chain is node i of the basis, in the order the basis stores its nodes (which need not be
		// n1, n2, ...: lazega has n1, n10, n11, ...): the draws get the basis's node names
		mata: st_local("__simlabs", invtokens((`bnetobj'->get_nodenames())[1..`nodes'], ","))
		if `"`constraints'"' != "" {
			_nwergm_constr, spec(`constraints') nodes(`nodes') directed(`bdirected') twomode(false) matobj(`bnetobj') weights(`=cond("`proposal'"=="uniform","random","default")')
			if `con_hasdyad' mata: __nwergm_last_G.set_dyadmask(__ncon_free)
			if "`con_code'" != "10" | "`con_maxonly'" == "1" local __spd 0
		}
		mata: __nwergm_last_G.spd_focus = `__spdfocus'
		mata: __sim_rc = ErgmNativeSetup(__nwergm_last_M, `=cond(`__spd', 3 + `__spdfocus' / 2, 2)', __nwergm_last_G)
		mata: mata drop __sim_rc
		mata: st_local("__sim_ok", strofreal(__nwergm_last_M.native_enabled_sample))
		if `__sim_ok' != 1 {
			di "{p 0 0 2}{err}basis()/constraints() need the native plugin, which is not available for this model or platform.{p_end}"
			error 198
		}
		if `"`constraints'"' != "" {
			mata: __nwergm_last_M.con_par = __ncon_par
			mata: __nwergm_last_M.con_cols = __ncon_cols
		}
		local __sim_con 1
	}
	// the data in memory is kept (all variables, in their row order) when the draws are on its nodes, that is when it
	// has one row per node and either holds no network (node attributes made with set obs, as for nodematch()), or
	// basis() names a network whose nodes are the rows, in the order of the rows, or (without basis()) the networks in
	// memory are on these rows: the draws then get the node names of the rows (_nwnode), since the node-attribute terms
	// read row i for node i. Otherwise (another number of nodes) the data is replaced by the node data of the draws.
	local __keepdata 0
	if _N == `nodes' & `nodes' > 0 {
		capture mata: st_local("__nnets", strofreal(__nw.nws.get_number()))
		if _rc local __nnets 0
		if "`__nnets'" == "" local __nnets 0
		if `__nnets' == 0 local __keepdata 1
		else if `bipartite' == 0 {
			capture confirm string variable _nwnode, exact
			if !_rc {
				mata: st_local("__rowlabs", invtokens(st_sdata(., "_nwnode")', ","))
				if "`basis'" != "" {
					if `"`__rowlabs'"' == `"`__simlabs'"' local __keepdata 1
				}
				else {
					local __simlabs `"`__rowlabs'"'
					local __keepdata 1
				}
			}
		}
	}
	if "`output'" == "stats" local __keepdata 0
	if `__keepdata' preserve
	if "`output'" == "stats" {
		mata: `__ergm_simmat' = J(1, 1, 0)
		mata: __sim_stats = J(`nsim', __nwergm_last_M.nparam(), .)
	}
	forvalues __s = 1/`nsim' {
		if !`__sim_con' {
		capture mata: mata drop __nwergm_last_G
		mata: __nwergm_last_G = ErgmGraph()
		mata: __nwergm_last_G.init(`nodes', ("`directed'"!=""))
		if `bipartite' != 0 {
			// same contiguous mode-1-first convention as the validation
			// block's own header comment (nodes 1..`bipartite'' = mode 1,
			// the rest = mode 2) - set_bipartite() itself just wants a
			// plain n x 1 vector of 1/2 mode labels, built directly here
			// rather than via nwset/an NWdef object (simulate has no
			// existing network to read one from).
			mata: __nwergm_last_G.set_bipartite((J(`bipartite',1,1) \ J(`nodes'-`bipartite',1,2)))
		}
		// enable_sp_cache() only when the user explicitly opted in via
		// spcache (see this program's own build-up comment above for why
		// it is off by default and why simulate's own cost-benefit is
		// even less favorable than estimation's).
		if `__ergm_spcache_used' {
			mata: __nwergm_last_G.enable_sp_cache()
		}
		// ErgmNativeSetup() is called for every draw's graph (see below): the native sampler's per-call boundary cost is
		// small against the Mata sampler's per-step cost (harmonisation unit 83 judged the opposite; measured otherwise).
		// structural() terms have no Mata change statistic: they need the native sampler
		if `__spd' mata: __nwergm_last_G.spd_focus = `__spdfocus'
		// the native sampler is used whenever the plug-in supports the model (ErgmNativeSetup() leaves the Mata sampler
		// in place otherwise); the option nonative keeps the Mata sampler (only structural() terms, which have no Mata
		// change statistic, still run natively)
		if !`__sim_con' {
			if "`nonative'" == "" {
				mata: __ergm_nsrc = ErgmNativeSetup(__nwergm_last_M, `=cond(`__spd', 3 + `__spdfocus' / 2, cond("`proposal'"=="tnt",2,1))', __nwergm_last_G)
			}
			else {
				mata: ns_native_setup(__nwergm_last_M, `=cond(`__spd', 3 + `__spdfocus' / 2, cond("`proposal'"=="tnt",2,1))', __nwergm_last_G)
			}
		}
		}
		local __sim_burn = cond(`__sim_con' & `__s' > 1, 0, `mcmcburnin')
		mata: __gof_discard = ErgmMCMCSample(__nwergm_last_M, __nwergm_last_G, st_matrix("`thetamat'"), `__sim_burn', `mcmcinterval', 1, `=cond(`__spd', "&ergm_propose_spdyad()", cond("`proposal'"=="tnt","&ergm_propose_tnt()","&ergm_propose_uniform()"))')
		if "`output'" == "stats" {
			mata: __sim_stats[`__s', .] = ergm_full_stat(__nwergm_last_M, __nwergm_last_G)
			continue
		}
		mata: `__ergm_simmat' = __nwergm_last_G.to_dense()

		local __ergm_simname = cond(`nsim'==1, "`generate'", "`generate'_`__s'")
		// a draw is replaced when it exists; asking nwdrop for a name that does not exist costs far more than the draw itself
		// once many networks are stored, so the name is looked up first (one compiled call)
		local __sim_exists 1
		if !(strpos("`__ergm_simname'", "*") | strpos("`__ergm_simname'", "?") | strpos("`__ergm_simname'", "~") | strpos("`__ergm_simname'", "-") | strpos("`__ergm_simname'", "$")) {
			local __sim_exists 0
			capture mata: nwf_syntax_named("`__ergm_simname'", 1)
			if _rc == 0 {
				capture confirm number `r(id)'
				if _rc == 0 {
					if `r(id)' > 0 local __sim_exists 1
				}
			}
		}
		if `__sim_exists' capture nwdrop `__ergm_simname'
		qui drop _all
		qui set obs `nodes'
		if `bipartite' != 0 {
			// nwset's own mat()+bipartite branch (check_bipartite()/
			// get_2mode_edge() in nwset.ado) wants a genuinely
			// RECTANGULAR mode2-count x mode1-count affiliation matrix,
			// not the full n x n dense form G.to_dense() returns (whose
			// only nonzero block is exactly this cross-mode rectangle,
			// since the bipartite MCMC proposal above never touches a
			// same-mode dyad) - `mode1 = cols(mat)' there, so this
			// project's own mode1-nodes-first convention above means the
			// needed rectangle is rows (mode-2 nodes) x cols (mode-1
			// nodes).
			mata: `__ergm_simmat_bip' = `__ergm_simmat'[(`bipartite'+1)::`nodes', (1::`bipartite')]
			nwset, mat(`__ergm_simmat_bip') bipartite name(`__ergm_simname')
		}
		else {
			nwset, mat(`__ergm_simmat') `=cond("`directed'"!="","directed","undirected")' name(`__ergm_simname') `=cond(`"`__simlabs'"' != "", `"labs(`__simlabs')"', "")'
		}
	}
	if `__keepdata' restore
	if "`output'" == "stats" {
		// a frame has no matrix-size limit (a Stata matrix stops at c(max_matdim), 800 rows in Stata/BE) and leaves the data
		// in memory alone; an existing frame of that name is replaced, as an existing draw is
		capture frame drop `generate'
		frame create `generate'
		frame `generate' {
			quietly set obs `nsim'
			mata: ergm_post_stats(__sim_stats, ergm_coefnames32(__nwergm_last_M.coefnames))
		}
		mata: mata drop __sim_stats
		di "{txt}Statistics of `nsim' simulated network" cond(`nsim' == 1, "", "s") " stored in the frame {bf:`generate'} (one row per draw, one variable per model term)."
	}

	// `__ergm_simmat_bip' is only ever assigned inside the `bipartite'!=0
	// branch above - dropped conditionally on the SAME test, rather than
	// via a `capture'd unconditional drop, so a one-mode simulate call
	// (the common case) never has to swallow a real "not found" error
	// here (a lingering nonzero `_rc' from a `capture'd failure survives
	// every ordinary successful command after it - confirmed directly -
	// and would otherwise leak out to this program's own caller as a
	// spurious nonzero `_rc' despite the simulate call itself having
	// fully succeeded).
	if `bipartite' != 0 {
		mata: mata drop `__ergm_simmat_bip'
	}
	capture mata: mata drop __ergm_nsrc
	mata: mata drop __nwergm_last_M __nwergm_last_G __gof_discard `__ergm_simmat' `__ergm_matatemps'
end

/*
	Bridge from an NWdef network to a fresh ErgmGraph: one-time read via
	NWdef's own neighbors() sparse accessor, undirected ties added once
	each (nb[k] <= i skipped, since ErgmGraph.toggle() already mirrors
	an undirected tie in both directions internally). Defined once at
	file scope (guarded, matching nwqap.ado's own established pattern
	for file-scope Mata helpers) rather than inside the program body -
	redefining a Mata function on every single nwergm call would error
	on the second call within the same session ("already exists").
*/
// The Mata block below is compiled when this file is loaded and uses classes of the Mata library of the package, so the
// library must be visible by then (Stata indexes the .mlib files once per session): index it first if needed.
capture quietly _nwergm_libcheck
capture mata: mata drop ergm_post_stats()
capture mata: mata drop ergm_bridge_from_netobj()
capture mata: mata drop ergm_hold_rebuildG()
mata:
// rebuild a plain graph (no modes, mask or cache) from its node count, direction and tie list in elist order
void ergm_hold_rebuildG(class ErgmGraph scalar G, real rowvector gnd, real matrix ties)
{
	real scalar k
	G.init(gnd[1], gnd[2])
	for (k=1; k<=rows(ties); k++) G.toggle(ties[k,1], ties[k,2])
}
// one double variable per statistic (valid, distinct names) holding the column of the statistics of the draws
void ergm_post_stats(real matrix S, string vector nm)
{
	string rowvector v
	real scalar j, k
	v = J(1, cols(S), "")
	for (j = 1; j <= cols(S); j++) {
		v[j] = strtoname(nm[j])
		for (k = 1; k < j; k++) {
			if (v[k] == v[j]) {
				v[j] = strtoname(v[j] + "_" + strofreal(j))
				break
			}
		}
	}
	for (j = 1; j <= cols(S); j++) {
		(void) st_addvar("double", v[j])
		st_store(., v[j], S[., j])
	}
}

void ergm_bridge_from_netobj(pointer(class nw_def scalar) scalar netobj,
	class ErgmGraph scalar G, real scalar directed){
	real scalar i, k
	real matrix nb

	for (i=1; i<=G.n; i++) {
		// sorted: the order in which the core returns the neighbors is not reproducible between sessions,
		// and the edge order of the starting network steers the MCMC (seed() would not reproduce a fit)
		nb = sort(netobj->neighbors(i), 1)
		for (k=1; k<=rows(nb); k++) {
			if (!directed & nb[k] <= i) continue
			G.toggle(i, nb[k])
		}
	}
}
end

* _nwergm_numvar: every node-attribute term reads its variable with Mata's
* st_data(), which silently returns missing values for a STRING variable.
* For nodematch() that made every pair "match" (missing == missing), so
* the term became an exact copy of edges (coefficient 0, "rank k-1 of k"
* warnings, and a meaningless fit). Refuse string attributes explicitly.
capture program drop _nwergm_numvar
program _nwergm_numvar
	args v term
	confirm variable `v'
	capture confirm numeric variable `v'
	if _rc {
		di "{p 0 0 2}{err}{bf:`term'(`v')}: {bf:`v'} is a string variable; nwergm needs a numeric attribute.{p_end}"
		di "{p 0 0 2}{err}Encode it first, e.g. {bf:encode `v', generate(`v'_n)}, and specify {bf:`term'(`v'_n)}. Categorical terms such as {bf:nodematch()}, {bf:nodefactor()} and {bf:nodemix()} take a string variable given by its full name.{p_end}"
		error 109
	}
	local __nn = _N
	capture mata: st_local("__nn", strofreal(__nwergm_last_G.n, "%18.0g"))
	if `__nn' > _N {
		di "{p 0 0 2}{err}In term {bf:`term'}: the model has `__nn' nodes, but the data in memory has only `=_N' observations; the attribute {bf:`v'} is read from the first `__nn' observations (one row per node).{p_end}"
		error 198
	}
	qui count if missing(`v') in 1/`__nn'
	local __nna = r(N)
	if `__nna' > 0 & inlist("`term'", "bcov1", "bfactor1", "bnodematch1", "bcov2", "bfactor2", "bnodematch2") {
		// two-mode terms only use the attribute of their own mode (R trims before checking)
		local __md = substr("`term'", -1, 1)
		capture mata: st_local("__nna", strofreal(missing(st_data(1::`__nn', "`v'")[__nwergm_last_G.mode`__md'nodes])))
	}
	if `__nna' > 0 {
		di "{p 0 0 2}{err}In term {bf:`term'}: attribute {bf:`v'} has missing data, which is not currently supported by ergm.{p_end}"
		error 416
	}
end

// replay of the last nwergm fit (nwergm alone, nwergm, level(#) and other display options, estimates replay)
capture program drop _nwergm_replay
program _nwergm_replay
	syntax [, *]
	if "`e(method)'" == "bayes" {
		_nwergm_bayes_display, tabopts(`"`options'"')
		exit
	}
	if "`e(estimate)'" == "Ego" {
		_nwergm_egodisplay, tabopts(`"`options'"')
		exit
	}
	local m = cond("`e(method)'" == "mple", "MPLE", cond("`e(estimate)'" == "CD", "CD", cond("`e(estimate)'" == "SA", "SA", "MCMLE")))
	nwergm_display "`e(depvar)'" "`=e(nodes)'" "`e(directed)'" "`m'" "`=e(converged)'" "`=e(mcmle_iterations)'" "`=e(mcmc_samplesize)'" "`options'"
	if "`e(ll)'" != "" & "`e(ll_method)'" != "" {
		local k = e(df_m)
		local pd = cond("`e(ll_method)'" == "pseudolikelihood", "Pseudo-", "")
		di
		di as txt %28s "Null `pd'`=cond("`pd'"=="","D","d")'eviance: " as res %9.1f e(deviance_0) as txt "  on " as res e(N) as txt " degrees of freedom"
		di as txt %28s "Residual `pd'`=cond("`pd'"=="","D","d")'eviance: " as res %9.1f e(deviance) as txt "  on " as res e(N) - `k' as txt " degrees of freedom"
		di
		di as txt "Log-likelihood: " as res %10.4f e(ll) as txt " (df = `k')   AIC: " as res %9.1f e(aic) as txt "   BIC: " as res %9.1f e(bic)
		if e(ll_se) > 0 & e(ll_se) < . {
			di as txt "Monte Carlo standard error of the log-likelihood: " as res %7.5g e(ll_se)
		}
		if "`e(exactll)'" == "1" {
			di as txt "(Exact log-likelihood at the estimate; not a Monte Carlo value.)"
		}
		if "`e(method)'" == "mple" & "`e(ll_method)'" != "exact" {
			di as txt "(For a dyad-dependent model fitted by MPLE, this is the pseudolikelihood.)"
		}
	}
end

// the options of ereturn display for the coefficient table. The coefficient names are shown in full: the
// confidence intervals are left out (noci) at a linesize below 100, where names of up to 32 characters do not fit next
// to them. ci, or level(#) given explicitly, shows the intervals (long names are then cut, e.g. nodematch_o~e); noci,
// nopvalues, cformat() and the other display options of Stata's estimation commands are passed on. With check, only
// the options are checked (before a fit).
// Use: _nwergm_tabopts <local> [check] [, options]; the options for ereturn display are returned in <local>.
capture program drop _nwergm_tabopts
program _nwergm_tabopts
	version 14
	gettoken __mac 0 : 0, parse(" ,")
	gettoken __chk : 0, parse(" ,")
	if `"`__chk'"' == "check" gettoken __chk 0 : 0, parse(" ,")
	else local __chk
	syntax [, Level(string) *]
	local __lev `"`level'"'
	// ci is picked out by hand: declared to syntax, ci would also take noci (as its negation)
	local ci
	local __rest
	while `"`options'"' != "" {
		gettoken __o options : options, bind
		if strlower(`"`__o'"') == "ci" local ci ci
		else local __rest `"`__rest' `__o'"'
	}
	_get_diopts __di, `__rest'
	local __noci : list posof "noci" in __di
	local __nopv : list posof "nopvalues" in __di
	if "`ci'" != "" & `__noci' {
		di as err "only one of options ci or noci is allowed"
		exit 198
	}
	local __show = ("`ci'" != "" | `"`__lev'"' != "")
	if `"`__lev'"' != "" {
		local 0 , level(`__lev')
		syntax [, Level(cilevel)]
		local __lev `level'
	}
	else local __lev = c(level)
	if "`__chk'" != "" exit
	local __add
	if !`__show' & !`__noci' & !`__nopv' {
		// full names: at a linesize below 100 (or with lstretch off) the names of up to 32 characters do not fit next
		// to the intervals; from 100 on both fit
		if c(linesize) < 100 | c(lstretch) == "off" | `: list posof "nolstretch" in __di' local __add noci
	}
	c_local `__mac' `"level(`__lev') `__di' `__add'"'
end

// seed(): an integer from 0 to 2147483647; set it (or only check it, option check)
capture program drop _nwergm_seed
program _nwergm_seed
	syntax anything(name=seed) [, CHECK]
	capture confirm integer number `seed'
	if _rc | real(`"`seed'"') < 0 | real(`"`seed'"') > 2147483647 {
		di as error "seed() must be an integer between 0 and 2147483647"
		exit 198
	}
	if "`check'" == "" set seed `seed'
end

// the decay of a geometrically weighted term must not be negative (R: the statistic is NaN)
capture program drop _nwergm_decaycheck
program _nwergm_decaycheck
	syntax [, *]
	while `"`options'"' != "" {
		gettoken opt options : options, bind
		if regexm(`"`opt'"', "^([a-z0-9]+)\((.*)\)$") {
			local nm = regexs(1)
			local val = regexs(2)
			gettoken first : val, parse(" ,")
			capture confirm number `first'
			if !_rc {
				if `first' < 0 {
					di as error "{p 0 0 2}option {bf:`nm'()}: the decay must be zero or positive; got `first'.{p_end}"
					exit 198
				}
			}
		}
	}
end

// identification of the fitted model held in Mata (__nwergm_last_M, __nwergm_last_G): set when a fit is posted and
// stored in e(fittag); cleared when another nwergm call replaces the model. Postestimation commands compare it with
// e(fittag) (subcommand check).
capture program drop _nwergm_tag
program _nwergm_tag, eclass
	args what
	if "`what'" == "clear" {
		mata: __nwergm_last_tag = ""
	}
	else if "`what'" == "set" {
		if "$NWERGM_TAGN" == "" global NWERGM_TAGN 0
		global NWERGM_TAGN = $NWERGM_TAGN + 1
		local tag "`c(current_date)' `c(current_time)' $NWERGM_TAGN"
		mata: __nwergm_last_tag = "`tag'"
		ereturn local fittag "`tag'"
	}
end

// keep the model of the last fit (Mata objects __nwergm_last_M/G, the missing-dyad matrix and the fit tag) while
// another nwergm call may replace it: save, then restore (call refused, or a simulation from a given model) or drop
program _nwergm_hold
	_nwergm_hold_body `0'
	// the captures in the body leave _rc set; reset it so that a successful nwergm leaves _rc at 0
	capture confirm number 0
end

program _nwergm_hold_body
	args what how
	if "`what'" == "save" {
		capture mata: mata drop __nwergm_bak_M __nwergm_bak_G
		capture mata: mata drop __nwergm_bak_mm
		capture mata: mata drop __nwergm_bak_tag
		capture mata: mata drop __nwergm_bak_ties __nwergm_bak_gnd
		capture mata: st_local("__t", __nwergm_last_tag)
		if _rc | `"`__t'"' == "" exit
		capture mata: __nwergm_last_M.nparam()
		if _rc exit
		capture mata: __nwergm_last_G.n
		if _rc exit
		mata: __nwergm_bak_M = ErgmModel()
		mata: ergm_ops_copyM(__nwergm_bak_M, __nwergm_last_M)
		capture mata: __nwergm_bak_mm = __nwergm_missmat
		mata: __nwergm_bak_tag = __nwergm_last_tag
		// A live ErgmGraph (a pointer vector of asarrays) makes every later Mata statement that touches a class object
		// slower (about 1.5 ms per statement at 1000 nodes), and the old graph and its backup copy (which shares the
		// asarrays) stayed alive during the whole next fit: each fit after the first took about twice as long. A plain
		// graph (no bipartite modes, no dyad mask, no shared-partner cache) is therefore kept as its tie list only,
		// and the old graph is dropped; restore rebuilds it with the ties in the same order.
		local __compact 0
		if "`how'" == "compact" {
			mata: st_local("__compact", strofreal(!__nwergm_last_G.bipartite & !__nwergm_last_G.has_dyadmask & !__nwergm_last_G.sp_cache_enabled))
		}
		if `__compact' {
			mata: __nwergm_bak_ties = __nwergm_last_G.all_ties()
			mata: __nwergm_bak_gnd = (__nwergm_last_G.n, __nwergm_last_G.directed)
			mata: mata drop __nwergm_last_G
		}
		else {
			mata: __nwergm_bak_G = ErgmGraph()
			mata: ergm_ops_copyG(__nwergm_bak_G, __nwergm_last_G)
		}
	}
	else if "`what'" == "restore" {
		capture mata: st_local("__t", __nwergm_bak_tag)
		if _rc exit
		capture mata: mata drop __nwergm_last_M
		capture mata: mata drop __nwergm_last_G
		mata: __nwergm_last_M = ErgmModel()
		mata: ergm_ops_copyM(__nwergm_last_M, __nwergm_bak_M)
		mata: st_local("__compact", strofreal(findexternal("__nwergm_bak_ties") != NULL))
		if `__compact' {
			mata: __nwergm_last_G = ErgmGraph()
			mata: ergm_hold_rebuildG(__nwergm_last_G, __nwergm_bak_gnd, __nwergm_bak_ties)
		}
		else {
			mata: __nwergm_last_G = ErgmGraph()
			mata: ergm_ops_copyG(__nwergm_last_G, __nwergm_bak_G)
		}
		capture mata: mata drop __nwergm_missmat
		capture mata: __nwergm_missmat = __nwergm_bak_mm
		mata: __nwergm_last_tag = __nwergm_bak_tag
		_nwergm_hold drop
	}
	else {
		// a call that ended without error but built no new graph keeps the graph of the previous fit
		capture mata: st_local("__need", strofreal(findexternal("__nwergm_bak_ties") != NULL & findexternal("__nwergm_last_G") == NULL))
		if "`__need'" == "1" {
			mata: __nwergm_last_G = ErgmGraph()
			mata: ergm_hold_rebuildG(__nwergm_last_G, __nwergm_bak_gnd, __nwergm_bak_ties)
		}
		capture mata: mata drop __nwergm_bak_M __nwergm_bak_G
		capture mata: mata drop __nwergm_bak_mm
		capture mata: mata drop __nwergm_bak_tag
		capture mata: mata drop __nwergm_bak_ties __nwergm_bak_gnd
	}
end

// The data in memory are the egos (one row per ego, with the attributes of the ego); the alters are in a second frame
// (one row per alter, with the identifier of the ego and the attributes of the alter). The statistics of the model are
// estimated from the egos, scaled to the size of a pseudopopulation, and the ERGM is fitted to them with the Monte Carlo
// sampler of nwergm on a network of that size (R: ergm.ego, target.stats). The covariance is the design-based covariance of
// the estimated statistics, passed through the information of the model.
capture program drop _nwergm_ego
program _nwergm_ego, eclass
	version 17
	syntax [if] [in] , [EDGES DEGREE(numlist integer >=0) DEGRANGE(numlist integer >=0) DEGRANGETO(numlist integer >=1) CONCURRENT ///
		NODEFACTOR(string) NODECOV(string) NODEMATCH(string) NODEMATCHDIFF(string) ABSDIST(string) ///
		EGOID(varname) ALTERS(string) ALTEREGOID(string) EGODEGREE(varname) WEIGHTS(varname) ///
		POPSIZE(real 1) PPOPSIZE(string) PPOPMUL(real 1) PPOPWT(string) SEED(string) ///
		MCMCBURNIN(integer -1) MCMCINTERVAL(integer 1024) MCMCSAMPLESIZE(integer -1) MCMLEITERATIONS(integer 60) ///
		MCMLEEFFECTIVESIZE(real -1) MCMLETERMINATION(string) PROPOSAL(string) NONATIVE VERBOSE NOPPSAVE * ]
	set more off
	if "`edges'" == "" {
		di as err "option {bf:edges} is required, as in every nwergm model."
		exit 198
	}
	if "`egoid'" == "" & "`alters'" != "" {
		di as err "option {bf:egoid()} is required with {bf:alters()}: the variable that identifies the egos."
		exit 198
	}
	if "`alters'" == "" & "`egodegree'" == "" {
		di as err "{p 0 0 2}the ego data need the alters: give {bf:alters(}{it:framename}{bf:)} (a frame with one row per alter), or {bf:egodegree(}{it:varname}{bf:)} with the number of alters of each ego when only the degree was collected.{p_end}"
		exit 198
	}
	if "`alters'" != "" & "`egodegree'" != "" {
		di as err "options alters() and egodegree() cannot be combined: the degree is the number of alters of the ego."
		exit 198
	}
	if "`alters'" != "" {
		capture confirm frame `alters'
		if _rc {
			di as err "frame {bf:`alters'} not found."
			exit 111
		}
	}
	local ppopwt = lower("`ppopwt'")
	if "`ppopwt'" == "" local ppopwt "round"
	_opts_oneof "round sample" "ppopwt" "`ppopwt'" 198
	if `popsize' < 0 {
		di as err "option popsize() must be zero or positive."
		exit 198
	}
	if `ppopmul' <= 0 {
		di as err "option ppopmul() must be positive."
		exit 198
	}
	_nwergm_tabopts __ergm_chk check, `options'
	local __tabopts `"`options'"'
	if `"`seed'"' != "" _nwergm_seed `seed', check

	// ---- terms
	local spec "edges"
	local termopts "edges"
	local catattrs ""
	local numattrs ""
	foreach d of local degree {
		local spec "`spec' degree:`d'"
	}
	if "`degree'" != "" local termopts "`termopts' degree(`degree')"
	if "`degrange'" != "" {
		local nr : word count `degrange'
		local nt : word count `degrangeto'
		if `nt' != 0 & `nt' != `nr' {
			di as err "degrangeto() needs one value for each value of degrange()."
			exit 198
		}
		forvalues k = 1/`nr' {
			local f : word `k' of `degrange'
			local t "."
			if `nt' > 0 local t : word `k' of `degrangeto'
			if "`t'" != "." & `t' <= `f' {
				di as err "degrange(): the upper limit must be larger than the lower."
				exit 198
			}
			local spec "`spec' degrange:`f':`t':`k'"
		}
		local termopts "`termopts' degrange(`degrange')"
		if `nt' > 0 local termopts "`termopts' degrangeto(`degrangeto')"
	}
	else if "`degrangeto'" != "" {
		di as err "degrangeto() needs degrange()."
		exit 198
	}
	if "`concurrent'" != "" {
		local spec "`spec' concurrent"
		local termopts "`termopts' concurrent"
	}
	foreach v of local nodefactor {
		local spec "`spec' nodefactor:`v'"
		local catattrs "`catattrs' `v'"
	}
	if "`nodefactor'" != "" local termopts "`termopts' nodefactor(`nodefactor')"
	foreach v of local nodematch {
		local spec "`spec' nodematch:`v'"
		local catattrs "`catattrs' `v'"
	}
	if "`nodematch'" != "" local termopts "`termopts' nodematch(`nodematch')"
	foreach v of local nodematchdiff {
		local spec "`spec' nodematchdiff:`v'"
		local catattrs "`catattrs' `v'"
	}
	if "`nodematchdiff'" != "" local termopts "`termopts' nodematchdiff(`nodematchdiff')"
	foreach v of local nodecov {
		local spec "`spec' nodecov:`v'"
		local numattrs "`numattrs' `v'"
	}
	if "`nodecov'" != "" local termopts "`termopts' nodecov(`nodecov')"
	foreach v of local absdist {
		local spec "`spec' absdist:`v'"
		local numattrs "`numattrs' `v'"
	}
	if "`absdist'" != "" local termopts "`termopts' absdist(`absdist')"
	foreach v in `catattrs' `numattrs' {
		capture confirm variable `v', exact
		if _rc {
			di as err "variable {bf:`v'} not found among the egos."
			exit 111
		}
	}
	foreach v of local numattrs {
		capture confirm numeric variable `v', exact
		if _rc {
			di as err "variable {bf:`v'} is a string; nodecov() and absdist() need numbers."
			exit 109
		}
	}
	local attrs : list catattrs | numattrs
	local attrs : list uniq attrs
	local catattrs : list uniq catattrs
	if "`alters'" != "" & "`attrs'" != "" {
		foreach v of local attrs {
			// nothing to check here: a term that needs the attribute of the alters says so
		}
	}

	// ---- the ego data
	marksample touse, novarlist
	tempvar __id
	if "`egoid'" == "" quietly generate double `__id' = _n
	else local __id "`egoid'"
	local nwcheck 0
	capture mata: mata drop __ego_n __ego_m __ego_key __ego_akey __ego_w __ego_degv __ego_deg __ego_aidx __ego_Ev __ego_Av __ego_lev __ego_attrs __ego_ahas __ego_H
	mata: ergm_ego_load("`touse'", "`__id'", tokens("`attrs'"), "`weights'", "`egodegree'")
	capture confirm numeric variable `__id'
	local numid = (_rc == 0)
	if "`alters'" != "" {
		if "`alteregoid'" == "" local alteregoid "`egoid'"
		capture frame `alters': confirm variable `alteregoid', exact
		if _rc {
			di as err "the frame {bf:`alters'} has no variable {bf:`alteregoid'} (the identifier of the ego of each alter); name it in {bf:alteregoid()}."
			exit 111
		}
		frame `alters': mata: ergm_ego_loadalt("`alteregoid'", tokens("`attrs'"), "`numid'")
		mata: ergm_ego_prep(tokens("`catattrs'"), 1)
	}
	else mata: ergm_ego_prep(tokens("`catattrs'"), 0)
	if scalar(__ego_unmatched) > 0 {
		di as txt "{p 0 0 2}(note: " as res scalar(__ego_unmatched) as txt " alters belong to egos that are not in the sample and are ignored){p_end}"
	}
	mata: st_numscalar("__ego_nn", __ego_n)
	local nego = scalar(__ego_nn)
	if `nego' < 3 {
		di as err "at least 3 egos are needed."
		exit 2001
	}
	mata: st_local("__sumw", strofreal(sum(__ego_w), "%18.0g"))
	mata: st_local("__wvar", strofreal(variance(__ego_w) > 1e-12 * mean(__ego_w)^2))

	// ---- the sizes of the pseudopopulation and of the population
	local pp = lower("`ppopsize'")
	if "`pp'" == "" local pp "auto"
	if "`pp'" == "auto" {
		if `popsize' == 0 | `popsize' == 1 local ppreq = `nego' * `ppopmul'
		else local ppreq = `popsize' * `ppopmul'
	}
	else if "`pp'" == "samp" local ppreq = `nego' * `ppopmul'
	else if "`pp'" == "pop" local ppreq = `popsize' * `ppopmul'
	else {
		capture confirm number `pp'
		if _rc {
			di as err "option ppopsize() takes auto, samp, pop or a number."
			exit 198
		}
		local ppreq = `pp'
	}
	local ppreq = round(`ppreq')
	if `ppreq' < 10 {
		di as err "the pseudopopulation would have fewer than 10 nodes; set popsize() or ppopsize()."
		exit 198
	}
	if `ppreq' < `nego' {
		di as txt "{p 0 0 2}Warning: a pseudopopulation smaller than the sample usually does not make sense.{p_end}"
	}
	else if `ppreq' == `nego' & `__wvar' {
		di as txt "{p 0 0 2}Warning: a pseudopopulation as large as the sample under weighted sampling: the results may be highly biased; increase popsize() or ppopmul().{p_end}"
	}
	if `ppreq' > 20000 {
		di as err "{p 0 0 2}the pseudopopulation would have `ppreq' nodes; the sampler keeps dyad-sized memory only for much smaller networks. Lower ppopsize().{p_end}"
		exit 198
	}
	if `"`seed'"' != "" set seed `seed'
	mata: __ego_reps = ergm_ego_reps(`ppreq', ("`ppopwt'" == "sample"))
	mata: st_numscalar("__ego_pp", sum(__ego_reps))
	local pp = scalar(__ego_pp)
	if `pp' != `ppreq' {
		if `popsize' > 0 di as txt "{p 0 0 2}(note: the pseudopopulation has " as res `pp' as txt " nodes, not the requested " as res `ppreq' as txt "; the estimates are not meaningfully affected){p_end}"
		else di as txt "{p 0 0 2}Warning: the pseudopopulation has `pp' nodes, not the requested `ppreq', with the network size adjustment off (popsize(0)); the estimates may be affected.{p_end}"
	}
	// R: the offset coefficient of the network size adjustment (an edges statistic): -log(ppopsize / popsize); none for popsize(0)
	local shift = 0
	if `popsize' > 0 local shift = -ln(`pp' / `popsize')

	// ---- the statistics of the egos, scaled to the pseudopopulation
	mata: __ego_names = ergm_ego_terms(tokens("`spec'"))
	mata: st_local("egonames", invtokens(__ego_names))
	tempname T VT
	mata: ergm_ego_survey(`pp', "`T'", "`VT'")
	mata: st_numscalar("__ego_edges", st_matrix("`T'")[1])
	local ptot = `pp' * (`pp' - 1) / 2
	local dens = scalar(__ego_edges) / `ptot'
	if `dens' <= 0 | `dens' >= 1 {
		di as err "the egos report no ties (or every possible tie): the density of the pseudopopulation is `dens'."
		exit 498
	}

	// ---- the pseudopopulation: the egos, copied in proportion to their weights, on an empty network of that size; the
	// chain starts at a random network of the density that the statistics imply
	preserve
	quietly keep if `touse'
	local keepattrs "`attrs'"
	if "`keepattrs'" == "" {
		tempvar __dummy
		quietly generate byte `__dummy' = 1
		local keepattrs "`__dummy'"
	}
	quietly keep `keepattrs'
	foreach v of local attrs {
		capture confirm string variable `v', exact
		if !_rc {
			tempvar __c
			quietly generate double `__c' = .
			mata: st_store(., "`__c'", ergm_ego_attrcol("`v'"))
			quietly drop `v'
			rename `__c' `v'
		}
	}
	tempvar __r
	quietly generate double `__r' = .
	mata: st_store(., "`__r'", __ego_reps)
	quietly drop if `__r' == 0
	quietly expand `__r'
	quietly drop `__r'
	if _N != `pp' {
		di as err "internal error: the pseudopopulation has " _N " rows, not `pp'."
		exit 498
	}
	capture nwdrop _egopp
	quietly nwrandom `pp', prob(`dens') name(_egopp) undirected
	if `"`seed'"' != "" set seed `seed'
	local fitopts "method(mcmle) mcmcburnin(`mcmcburnin') mcmcinterval(`mcmcinterval') mcmcsamplesize(`mcmcsamplesize') mcmleiterations(`mcmleiterations') mcmleeffectivesize(`mcmleeffectivesize')"
	if "`mcmletermination'" != "" local fitopts "`fitopts' mcmletermination(`mcmletermination')"
	if "`proposal'" != "" local fitopts "`fitopts' proposal(`proposal')"
	if "`nonative'" != "" local fitopts "`fitopts' nonative"
	if "`verbose'" != "" local fitopts "`fitopts' verbose"
	if `"`seed'"' != "" local fitopts "`fitopts' seed(`seed')"
	capture noisily _nwergm_fit _egopp, `termopts' `fitopts' egotarget(`T') egonames(`egonames') egovt(`VT') egoshift(`shift') `options'
	local rc = _rc
	capture nwdrop _egopp
	if `rc' {
		capture mata: mata drop ergm_target
		exit `rc'
	}
	restore

	// ---- results
	tempname A Tm Vm
	matrix `A' = __ego_A
	capture matrix drop __ego_A
	local cn : colnames e(b)
	mata: st_matrix("`Tm'", ergm_ego_order(__nwergm_last_M, __ego_names, "`T'"))
	matrix colnames `Tm' = `cn'
	matrix rownames `Tm' = target
	mata: st_matrix("`Vm'", ergm_ego_orderv(__nwergm_last_M, __ego_names, "`VT'"))
	matrix colnames `Vm' = `cn'
	matrix rownames `Vm' = `cn'
	matrix colnames `A' = `cn'
	matrix rownames `A' = `cn'
	ereturn local depvar "ego"
	ereturn local cmdline `"nwergm ego, `0'"'
	ereturn local egoframe "`c(frame)'"
	ereturn local alterframe "`alters'"
	ereturn scalar N = `nego'
	ereturn scalar nodes = `pp'
	ereturn scalar egos = `nego'
	mata: st_numscalar("__ego_t1", st_matrix("`Tm'")[1, selectindex(tokens("`cn'") :== "edges")])
	ereturn scalar ties = scalar(__ego_t1)
	ereturn scalar popsize = `popsize'
	ereturn scalar ppopsize = `pp'
	ereturn scalar sum_weights = `__sumw'
	ereturn local ppopwt "`ppopwt'"
	ereturn matrix target = `Tm'
	ereturn matrix V_target = `Vm'
	ereturn matrix info = `A'
	// the degree distribution of the egos, for estat gof (R: gof.ergm.ego compares degrees 0 to maxdeg - 1 and maxdeg or more)
	mata: st_numscalar("__ego_md", ergm_ego_maxdeg())
	local md = min(scalar(__ego_md), `pp' - 1)
	tempname DD
	mata: st_matrix("`DD'", ergm_ego_degdist(`md'))
	ereturn scalar maxdeg = `md'
	ereturn matrix degdist = `DD'
	capture mata: mata drop __ego_reps __ego_names
	capture mata: mata drop __ego_n __ego_m __ego_key __ego_akey __ego_w __ego_degv __ego_deg __ego_aidx __ego_Ev __ego_Av __ego_lev __ego_attrs __ego_ahas __ego_H
	_nwergm_egodisplay, tabopts(`"`__tabopts'"')
end

capture program drop _nwergm_egodisplay
program _nwergm_egodisplay
	syntax [, TABOPTS(string asis)]
	di
	di as txt "Egocentric exponential-family random graph model"
	di
	di as txt "Egos in the sample:{col 28}={res}  " e(egos)
	di as txt "Population size:{col 28}={res}  " cond(e(popsize) == 1, "1 (scaled per person)", cond(e(popsize) == 0, "not adjusted", string(e(popsize))))
	di as txt "Pseudopopulation size:{col 28}={res}  " e(ppopsize)
	di as txt "MCMC sample size:{col 28}={res}  " e(mcmc_samplesize)
	di
	_nwergm_tabopts __t, `tabopts'
	ereturn display, `__t'
	di
	if e(converged) == 1 di as txt "MCMLE converged after " e(mcmle_iterations) " iteration(s)."
	else di as err "MCMLE did not converge after " e(mcmle_iterations) " iteration(s)."
	di as txt "{p 0 0 2}Standard errors: design-based covariance of the statistics estimated from the egos, passed through the information of the model at the size of the pseudopopulation (as in R's ergm.ego).{p_end}"
end

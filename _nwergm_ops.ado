*! version 1.3.2  27oct2026 _nwergm_ops: the operator terms of R's ergm (Sum, Prod, S, F, NodematchFilter, Symmetrize, Project, I, For, Label) for nwergm's operators() option
* Copyright (C) 2026 Thomas U. Grund
* This file is part of nwergm, a Stata package derived from the R package 'ergm (statnet)' (Mark S. Handcock, David R. Hunter, Carter T. Butts, Steven M. Goodreau, Pavel N. Krivitsky, Martina Morris and contributors; GPL-3 (+ file LICENSE)).
* nwergm is free software: you can redistribute it and/or modify it under the terms of the GNU General
* Public License, version 3, as published by the Free Software Foundation. It is distributed in the hope
* that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
* or FITNESS FOR A PARTICULAR PURPOSE. See the file LICENSE for the full text.
*
* operators(spec): spec is a list of operator calls, Name(terms [, suboptions]).  The terms inside are written as
* nwergm options (for example  triangle nodematch(sex) gwesp(0.5)); each operator builds its sub-model(s) by calling
* nwergm again on the network (or on the network the operator derives from it) and adds one term instance to the model.
capture program drop _nwergm_ops
program _nwergm_ops, rclass
	version 14
	syntax anything(name=netname), SPEC(string asis) NODES(integer) DIRECTED(string) TWOMODE(string) NEBASE(integer) [TYPE(string)]
	local ne = `nebase'
	local temps ""
	local dep 0
	local d 0
	if "$NWERGM_DEPTH" != "" local d $NWERGM_DEPTH
	mata: __ops_calls`d' = ergm_ops_calls(st_local("spec"))
	mata: st_local("ncall", strofreal(rows(__ops_calls`d')))
	forvalues c = 1/`ncall' {
		mata: st_local("opname", strlower(__ops_calls`d'[`c',1]))
		mata: st_local("opargs", __ops_calls`d'[`c',2])
		if inlist("`opname'", "sum", "prod") {
			_nwergm_ops_sumprod `netname', args(`"`opargs'"') nodes(`nodes') directed(`directed') twomode(`twomode') nebase(`ne') type(`type') kind(`opname')
		}
		else if inlist("`opname'", "s", "f", "nodematchfilter", "symmetrize", "project", "proj1", "proj2") {
			_nwergm_ops_derived `netname', args(`"`opargs'"') nodes(`nodes') directed(`directed') twomode(`twomode') nebase(`ne') type(`type') kind(`opname')
		}
		else if inlist("`opname'", "curve", "parametrise", "parametrize") {
			_nwergm_ops_curve `netname', args(`"`opargs'"') nodes(`nodes') directed(`directed') twomode(`twomode') nebase(`ne') type(`type')
		}
		else if inlist("`opname'", "i", "for", "label", "log", "exp", "offset") {
			_nwergm_ops_inline `netname', args(`"`opargs'"') nodes(`nodes') directed(`directed') twomode(`twomode') nebase(`ne') type(`type') kind(`opname')
		}
		else {
			mata: mata drop __ops_calls`d'
			di "{err}operators(): unknown operator {bf:`opname'}; the operators are Sum, Prod, S, F, NodematchFilter, Symmetrize, Project, Proj1, Proj2, I, For, Label, Log, Exp, Offset and Curve."
			error 198
		}
		local ne = r(nebase)
		local dep = max(`dep', r(dep))
		local temps "`temps' `r(temps)'"
	}
	mata: mata drop __ops_calls`d'
	return local temps "`temps'"
	return scalar dep = `dep'
	return scalar nebase = `ne'
end

* builds the model of a list of terms (written as nwergm options).  The terms are built one by one, so that the
* statistics come in the order in which the terms are written, as in an R formula
capture program drop _nwergm_opsub
program _nwergm_opsub, rclass
	version 14
	syntax anything(name=netname), TERMS(string asis) NODES(string) DIRECTED(string) TWOMODE(string) NEBASE(integer) [TYPE(string) GRAPH(string)]
	mata: st_local("nw", strofreal(cols(ergm_ops_words(st_local("terms")))))
	if `nw' < 1 | strpos(`"`terms'"', "rangeto") > 0 {
		_nwergm_opsub1 `netname', terms(`terms') nodes(`nodes') directed(`directed') twomode(`twomode') nebase(`nebase') type(`type') graph(`graph')
		return add
		exit
	}
	if "$NWERGM_SUBSEQ" == "" global NWERGM_SUBSEQ 0
	global NWERGM_SUBSEQ = $NWERGM_SUBSEQ + 1
	local name "__nwergm_sub_${NWERGM_SUBSEQ}"
	capture mata: mata drop `name'
	mata: `name' = ErgmModel()
	mata: `name'.init()
	mata: __ow = ergm_ops_words(st_local("terms"))
	local dind 1
	local cn ""
	forvalues w = 1/`nw' {
		mata: st_local("oneterm", ergm_ops_wrapop(__ow[`w']))
		_nwergm_opsub1 `netname', terms(`oneterm') nodes(`nodes') directed(`directed') twomode(`twomode') nebase(`nebase') type(`type') graph(`graph')
		local part "`r(name)'"
		local pcn "`r(cn)'"
		if !r(dind) local dind 0
		mata: ergm_ops_mergemodel(`name', `part', ergm_ops_words(st_local("pcn")))
		local cn "`cn' `pcn'"
	}
	mata: st_local("np", strofreal(`name'.nparam()))
	return local name "`name'"
	return scalar np = `np'
	return local cn "`cn'"
	return scalar dind = `dind'
end

capture program drop _nwergm_opsub1
program _nwergm_opsub1, rclass
	version 14
	syntax anything(name=netname), TERMS(string asis) NODES(string) DIRECTED(string) TWOMODE(string) NEBASE(integer) [TYPE(string) GRAPH(string)]
	if "$NWERGM_SUBSEQ" == "" global NWERGM_SUBSEQ 0
	global NWERGM_SUBSEQ = $NWERGM_SUBSEQ + 1
	local name "__nwergm_sub_${NWERGM_SUBSEQ}"
	local d 1
	if "$NWERGM_DEPTH" != "" local d = $NWERGM_DEPTH + 1
	global NWERGM_DEPTH `d'
	capture mata: mata drop __nwergm_hold`d'_M __nwergm_hold`d'_G
	mata: __nwergm_hold`d'_M = ErgmModel()
	mata: __nwergm_hold`d'_G = ErgmGraph()
	mata: ergm_ops_copyM(__nwergm_hold`d'_M, __nwergm_last_M)
	mata: ergm_ops_copyG(__nwergm_hold`d'_G, __nwergm_last_G)
	if "`graph'" != "" mata: ergm_ops_copyG(__nwergm_last_G, `graph')
	local tp ""
	if "`type'" != "" local tp "type(`type')"
	local base = 1000 * ${NWERGM_SUBSEQ} + 100000
	capture noisily nwergm `netname', `terms' submodel(`name' `base' `nodes' `directed' `twomode') `tp'
	local rc = _rc
	global NWERGM_DEPTH = `d' - 1
	mata: ergm_ops_copyM(__nwergm_last_M, __nwergm_hold`d'_M)
	mata: ergm_ops_copyG(__nwergm_last_G, __nwergm_hold`d'_G)
	mata: mata drop __nwergm_hold`d'_M __nwergm_hold`d'_G
	if `rc' exit `rc'
	mata: st_local("np", strofreal(`name'.nparam()))
	mata: st_local("cn", invtokens(`name'.coefnames))
	if ${NWERGM_SUBCURVED} > 0 {
		di "{err}operators(): curved (free-decay) terms cannot be used inside an operator."
		error 198
	}
	return local name "`name'"
	return scalar np = `np'
	return local cn "`cn'"
	return scalar dind = ${NWERGM_SUBDIND}
end

* Sum(f1 | f2 ..., label()) and Prod(...)
capture program drop _nwergm_ops_sumprod
program _nwergm_ops_sumprod, rclass
	version 14
	syntax anything(name=netname), KIND(string) ARGS(string) NODES(integer) DIRECTED(string) TWOMODE(string) NEBASE(integer) [TYPE(string)]
	local ne = `nebase'
	local Kind = proper("`kind'")
	mata: __a = ergm_ops_split1(st_local("args"))
	mata: st_local("first", __a[1])
	mata: st_local("opts", __a[2])
	mata: __ok = 0
	mata: __lab = ergm_ops_getopt(st_local("opts"), "label", __ok)
	mata: st_local("label", __lab)
	mata: st_local("haslabel", strofreal(__ok))
	mata: st_local("badopt", ergm_ops_badopts(st_local("opts"), "label"))
	if "`badopt'" != "" {
		di "{err}`Kind'(): unknown suboption {bf:`badopt'}; the suboption is label()."
		error 198
	}
	if !`haslabel' {
		di "{err}`Kind'(): the argument {bf:label} is required."
		error 198
	}
	mata: __fs = ergm_ops_split(st_local("first"), "|")
	mata: st_local("nf", strofreal(cols(__fs)))
	local subs ""
	local dims ""
	local lhss ""
	local dep 0
	forvalues f = 1/`nf' {
		mata: st_local("ftxt", __fs[`f'])
		// optional weights before a colon: a number, numbers, matrix(name), or sum / mean (prod / geomean for Prod)
		local lhs ""
		mata: st_local("hascolon", strofreal(cols(ergm_ops_split(st_local("ftxt"), ":")) > 1))
		if `hascolon' {
			mata: __cc = ergm_ops_split(st_local("ftxt"), ":")
			mata: st_local("lhs", __cc[1])
			mata: st_local("ftxt", __cc[2])
		}
		_nwergm_opsub `netname', terms(`ftxt') nodes(.) directed(.) twomode(.) nebase(`ne') type(`type')
		local subs "`subs' `r(name)'"
		local dims "`dims' `r(np)'"
		local lhss `"`lhss'`lhs'|"'
		if !r(dind) local dep 1
	}
	local td "__netd_`++ne'"
	mata: `td' = ErgmTermData()
	mata: `td'.opkind = "`kind'"
	local ptrs ""
	foreach s of local subs {
		local ptrs "`ptrs'&`s', "
	}
	mata: `td'.opsub = (`=substr("`ptrs'", 1, strlen("`ptrs'") - 2)')
	mata: `td'.opdims = (`=subinstr(strtrim("`dims'"), " ", ",", .)')
	mata: __ls = ergm_ops_split(st_local("lhss"), "|")
	mata: `td'.opW = J(0, 0, .)
	mata: ergm_ops_setW(`td', __ls, "`kind'")
	mata: st_local("P", strofreal(rows(`td'.opW)))
	mata: st_local("cnames", invtokens(ergm_ops_names(st_local("label"), `P', "`Kind'")))
	mata: __nwergm_last_M.addterm("op:`kind'", `P', &stat_op(), &change_op(), `td', tokens("`cnames'"))
	return local temps "`td'"
	return scalar dep = `dep'
	return scalar nebase = `ne'
end

* S, F, NodematchFilter, Symmetrize, Project: the formula is evaluated on a network derived from the one at hand
capture program drop _nwergm_ops_derived
program _nwergm_ops_derived, rclass
	version 14
	syntax anything(name=netname), KIND(string) ARGS(string) NODES(integer) DIRECTED(string) TWOMODE(string) NEBASE(integer) [TYPE(string)]
	local ne = `nebase'
	mata: __a = ergm_ops_split1(st_local("args"))
	mata: st_local("first", __a[1])
	mata: st_local("opts", __a[2])
	local td "__netd_`++ne'"
	mata: `td' = ErgmTermData()
	local subnodes "."
	local subdir "."
	local subtwo "."
	local restrict ""
	local prefix ""
	local dep 0
	if "`kind'" == "f" {
		mata: st_local("bad", ergm_ops_badopts(st_local("opts"), "filter"))
		mata: __ok = 0
		mata: __flt = ergm_ops_getopt(st_local("opts"), "filter", __ok)
		mata: st_local("filter", __flt)
		mata: st_local("hasf", strofreal(__ok))
		if "`bad'" != "" | !`hasf' {
			di "{err}F(): the syntax is F(terms, filter(term)), for example F(triangle, filter(nodematch(sex)))."
			error 198
		}
		// a leading ! or a trailing comparison with a number selects the filter's comparison, as in R
		local cmp 0
		local val 0
		local ftxt `"`filter'"'
		if substr(trim(`"`ftxt'"'), 1, 1) == "!" {
			local cmp 1
			local ftxt = substr(trim(`"`ftxt'"'), 2, .)
		}
		else if regexm(`"`ftxt'"', "^(.*\))[ ]*(==|!=|>=|<=|>|<)[ ]*(-?[0-9.]+([eE][-+]?[0-9]+)?)[ ]*$") {
			local ftxt = regexs(1)
			local cop = regexs(2)
			local val = regexs(3)
			local cmp = cond("`cop'" == "==", 2, cond("`cop'" == "!=", 3, cond("`cop'" == ">", 4, cond("`cop'" == "<", 5, cond("`cop'" == ">=", 6, 7)))))
		}
		_nwergm_opsub `netname', terms(`ftxt') nodes(.) directed(.) twomode(.) nebase(`ne') type(`type')
		if r(np) != 1 | !r(dind) {
			di "{err}F(): the filter must be one dyad-independent term with exactly one statistic."
			error 198
		}
		local fname "`r(name)'"
		mata: st_local("e0", strofreal(ergm_ops_emptystat(`fname', __nwergm_last_G)[1]))
		if `e0' != 0 {
			di "{err}F(): the filter term must have the property that its dyadwise components are 0 for 0-valued relations."
			error 198
		}
		mata: `td'.opkind = "filter"
		mata: `td'.opnum = (`cmp', `val')
		mata: `td'.opfilter = &`fname'
		local prefix = "F(" + subinstr(`"`filter'"', " ", "", .) + ")~"
	}
	else if "`kind'" == "nodematchfilter" {
		mata: st_local("bad", ergm_ops_badopts(st_local("opts"), "attrname"))
		mata: __ok = 0
		mata: __atn = ergm_ops_getopt(st_local("opts"), "attrname", __ok)
		mata: st_local("attrname", __atn)
		mata: st_local("hasa", strofreal(__ok))
		if "`bad'" != "" | !`hasa' {
			di "{err}NodematchFilter(): the syntax is NodematchFilter(terms, attrname(varlist))."
			error 198
		}
		foreach v of local attrname {
			confirm variable `v'
			capture confirm numeric variable `v'
			if _rc {
				di "{err}{bf:NodematchFilter(`v')}: {bf:`v'} is a string variable; nwergm needs a numeric attribute."
				di "{err}Encode it first, e.g. {bf:encode `v', generate(`v'_n)}."
				error 109
			}
			mata: st_local("nmiss", strofreal(missing(st_data(1::__nwergm_last_G.n, "`v'"))))
			if `nmiss' > 0 {
				di "{err}In term {bf:NodematchFilter}: attribute {bf:`v'} has missing data, which is not currently supported by ergm."
				error 416
			}
		}
		local fname "__nwergm_sub_nmf`ne'"
		local ftd "__netd_`++ne'"
		mata: `ftd' = ErgmTermData()
		mata: `ftd'.attr = ergm_ops_blockcode(st_data(1::__nwergm_last_G.n, tokens(st_local("attrname"))))
		mata: `fname' = ErgmModel()
		mata: `fname'.init()
		mata: `fname'.addterm("nodematch", 1, &stat_nodematch(), &change_nodematch(), `ftd', ("nodematch"))
		mata: `td'.opkind = "filter"
		mata: `td'.opnum = (0, 0)
		mata: `td'.opfilter = &`fname'
		local prefix = "NodematchFilter(" + subinstr(trim("`attrname'"), " ", ",", .) + ")~"
	}
	else if "`kind'" == "symmetrize" {
		mata: st_local("bad", ergm_ops_badopts(st_local("opts"), "rule"))
		mata: __ok = 0
		mata: __rl = ergm_ops_getopt(st_local("opts"), "rule", __ok)
		mata: st_local("rule", __rl)
		if "`bad'" != "" {
			di "{err}Symmetrize(): the syntax is Symmetrize(terms [, rule(weak|strong|upper|lower)])."
			error 198
		}
		if "`rule'" == "" local rule "weak"
		local rule = lower("`rule'")
		if "`rule'" == "max" local rule "weak"
		if "`rule'" == "min" local rule "strong"
		local rc = cond("`rule'" == "weak", 1, cond("`rule'" == "strong", 2, cond("`rule'" == "upper", 3, cond("`rule'" == "lower", 4, 0))))
		if !`rc' {
			di "{err}Symmetrize(): rule() is one of weak, strong, upper, lower, max, min."
			error 198
		}
		if "`directed'" != "true" {
			di "{err}In term {bf:Symmetrize}: Term may not be used with networks with directed==FALSE."
			error 198
		}
		mata: `td'.opkind = "sym"
		mata: `td'.opnum = (`rc')
		local subdir "false"
		local prefix "Symmetrize(`rule')~"
		if `rc' <= 2 local dep 1
	}
	else if "`kind'" == "s" {
		mata: st_local("bad", ergm_ops_badopts(st_local("opts"), "attrs"))
		mata: __ok = 0
		mata: __at = ergm_ops_getopt(st_local("opts"), "attrs", __ok)
		mata: st_local("attrs", __at)
		mata: st_local("hasa", strofreal(__ok))
		if "`bad'" != "" | !`hasa' {
			di "{err}S(): the syntax is S(terms, attrs(varname or condition)), for example S(triangle, attrs(sex==1))."
			error 198
		}
		if "`twomode'" == "true" {
			di "{err}S(): induced subgraphs of two-mode networks are not available."
			error 198
		}
		tempvar sel
		capture qui generate byte `sel' = (`attrs') if _n <= `nodes'
		if _rc {
			di "{err}S(): attrs(`attrs') is not a variable or a condition on the node attributes."
			error 198
		}
		qui replace `sel' = 0 if missing(`sel') & _n <= `nodes'
		qui replace `sel' = 1 if `sel' != 0 & _n <= `nodes'
		qui count if `sel' == 1
		local nsel = r(N)
		if `nsel' == 0 {
			di "{err}S(): empty subgraph selected."
			error 198
		}
		mata: `td'.opkind = "sub"
		mata: `td'.opnodes = selectindex(st_data(1::`nodes', "`sel'") :== 1)
		mata: `td'.opnum = (0, `nodes')
		local subnodes `nsel'
		local restrict "keep if `sel' == 1"
		local prefix = "S(" + subinstr(`"`attrs'"', " ", "", .) + ")~"
	}
	else {
		// project, proj1, proj2
		mata: st_local("bad", ergm_ops_badopts(st_local("opts"), "mode"))
		mata: __ok = 0
		mata: __md = ergm_ops_getopt(st_local("opts"), "mode", __ok)
		mata: st_local("mode", __md)
		mata: st_local("hasm", strofreal(__ok))
		if "`bad'" != "" {
			di "{err}Project(): the syntax is Project(terms, mode(1|2)); Proj1(terms) and Proj2(terms) are the short forms."
			error 198
		}
		if "`kind'" == "proj1" local mode 1
		if "`kind'" == "proj2" local mode 2
		if "`kind'" == "project" & !`hasm' {
			di "{err}Project(): mode() is required."
			error 198
		}
		if !inlist("`mode'", "1", "2") {
			di "{err}Project(): mode must be 1 or 2."
			error 198
		}
		if "`twomode'" != "true" {
			di "{err}In term {bf:Project}: Term may not be used with networks with bipartite==FALSE."
			error 198
		}
		mata: `td'.opkind = "proj"
		mata: `td'.opnum = (`mode')
		mata: st_local("subnodes", strofreal(sum(__nwergm_last_G.mode :== `mode'), "%18.0g"))
		tempvar mvar
		qui gen byte `mvar' = .
		mata: st_store(1::`nodes', "`mvar'", __nwergm_last_G.mode)
		local restrict "keep if `mvar' == `mode'"
		local subdir "false"
		local subtwo "false"
		local prefix "Proj`mode'~"
		local dep 1
	}
	if inlist("`kind'", "s", "project", "proj1", "proj2") {
		foreach dc in edgecov hamming dyadcov attrcov {
			if strpos(lower(`"`first'"'), "`dc'(") > 0 {
				di "{err}`=upper(substr("`kind'", 1, 1))'`=substr("`kind'", 2, .)'(): the dyadic covariate term {bf:`dc'()} cannot be used where the set of nodes changes."
				error 198
			}
		}
	}
	// the derived network and the model on it
	local gname "__nwergm_opG`ne'"
	capture mata: mata drop `gname'
	mata: `gname' = ErgmGraph()
	mata: ergm_ops_derive_into(__nwergm_last_G, `td', `gname')
	if "`restrict'" != "" {
		preserve
		qui `restrict'
		capture noisily _nwergm_opsub `netname', terms(`first') nodes(`subnodes') directed(`subdir') twomode(`subtwo') nebase(`ne') type(`type') graph(`gname')
		local rc = _rc
		restore
		if `rc' exit `rc'
	}
	else {
		_nwergm_opsub `netname', terms(`first') nodes(`subnodes') directed(`subdir') twomode(`subtwo') nebase(`ne') type(`type') graph(`gname')
	}
	local sname "`r(name)'"
	local np = r(np)
	local cn "`r(cn)'"
	if !r(dind) local dep 1
	local prefix = subinstr(`"`prefix'"', ".", "_", .)
	mata: `td'.opsub = (&`sname')
	mata: `gname' = ErgmGraph()
	local names ""
	foreach c of local cn {
		local names "`names' `prefix'`c'"
	}
	mata: __nwergm_last_M.addterm("op:" + `td'.opkind, `np', &stat_op(), &change_op(), `td', ergm_ops_words(st_local("names")))
	return local temps "`td'"
	return scalar dep = `dep'
	return scalar nebase = `ne'
end

* I(terms), For(...), Label(terms, label(), pos()), Log(terms [, log0()]), Exp(terms), Offset(terms [, coef() which()]):
* the terms of the formula are added to the model themselves
capture program drop _nwergm_ops_inline
program _nwergm_ops_inline, rclass
	version 14
	syntax anything(name=netname), KIND(string) ARGS(string) NODES(integer) DIRECTED(string) TWOMODE(string) NEBASE(integer) [TYPE(string)]
	local ne = `nebase'
	local Kind = proper("`kind'")
	local names ""
	local log0 = -1/sqrt(c(epsdouble))
	local coef 0
	local which ""
	if "`kind'" == "i" {
		local terms `"`args'"'
	}
	else if "`kind'" == "for" {
		mata: st_local("terms", ergm_ops_for(st_local("args")))
	}
	else {
		mata: __a = ergm_ops_split1(st_local("args"))
		mata: st_local("terms", __a[1])
		mata: st_local("opts", __a[2])
		local allowed "label pos"
		if "`kind'" == "log" local allowed "log0"
		if "`kind'" == "exp" local allowed ""
		if "`kind'" == "offset" local allowed "coef which"
		mata: st_local("bad", ergm_ops_badopts(st_local("opts"), st_local("allowed")))
		if "`bad'" != "" {
			di "{err}`Kind'(): unknown suboption {bf:`bad'}."
			error 198
		}
		mata: __ok = 0
		mata: st_local("label", ergm_ops_getopt(st_local("opts"), "label", __ok))
		mata: st_local("haslab", strofreal(__ok))
		mata: __ok = 0
		mata: st_local("pos", ergm_ops_getopt(st_local("opts"), "pos", __ok))
		mata: __ok = 0
		mata: st_local("o2", ergm_ops_getopt(st_local("opts"), "log0", __ok))
		if "`o2'" != "" local log0 "`o2'"
		mata: __ok = 0
		mata: st_local("o3", ergm_ops_getopt(st_local("opts"), "coef", __ok))
		if "`o3'" != "" local coef "`o3'"
		mata: __ok = 0
		mata: st_local("o4", ergm_ops_getopt(st_local("opts"), "which", __ok))
		if "`o4'" != "" local which "`o4'"
		if "`kind'" == "label" {
			if !`haslab' {
				di "{err}Label(): the syntax is Label(terms, label(string) [pos(prepend|replace|append|paren)])."
				error 198
			}
			if "`pos'" == "" local pos "paren"
			if !inlist("`pos'", "prepend", "replace", "append", "paren") {
				di "{err}Label(): pos() is one of prepend, replace, append, paren."
				error 198
			}
		}
	}
	_nwergm_opsub `netname', terms(`terms') nodes(.) directed(.) twomode(.) nebase(`ne') type(`type')
	local sname "`r(name)'"
	local np = r(np)
	local dep = !r(dind)
	local cn "`r(cn)'"
	local names "`cn'"
	if "`kind'" == "label" {
		mata: st_local("names", invtokens(ergm_ops_label(ergm_ops_words(st_local("cn")), st_local("label"), st_local("pos"))))
	}
	if inlist("`kind'", "log", "exp") {
		local names ""
		foreach c of local cn {
			local names "`names' `Kind'~`c'"
		}
	}
	if "`kind'" == "offset" {
		mata: ergm_ops_setoffset(`sname', st_local("coef"), st_local("which"))
	}
	mata: st_local("first", strofreal(__nwergm_last_M.nparam() + 1))
	mata: ergm_ops_mergemodel(__nwergm_last_M, `sname', ergm_ops_words(st_local("names")))
	if inlist("`kind'", "log", "exp") {
		mata: ergm_ops_setkind(__nwergm_last_M, `first', `first' + `np' - 1, `=cond("`kind'" == "log", 1, 2)', `log0')
	}
	return local temps ""
	return scalar dep = `dep'
	return scalar nebase = `ne'
end

* Curve(terms, params(names), map(rep | matrix(name))): the coefficients of the terms are a linear function of the parameters,
* eta = L * theta (map(rep) recycles the parameters, as R's map = "rep"; matrix(name) is the n x q matrix L).  Maximum likelihood
* with eta = L * theta is the model with the statistics L' * g(y), which is how it is estimated (a weighted Sum).
capture program drop _nwergm_ops_curve
program _nwergm_ops_curve, rclass
	version 14
	syntax anything(name=netname), ARGS(string) NODES(integer) DIRECTED(string) TWOMODE(string) NEBASE(integer) [TYPE(string)]
	local ne = `nebase'
	mata: __a = ergm_ops_split1(st_local("args"))
	mata: st_local("terms", __a[1])
	mata: st_local("opts", __a[2])
	mata: st_local("bad", ergm_ops_badopts(st_local("opts"), "params map"))
	mata: __ok = 0
	mata: st_local("params", ergm_ops_getopt(st_local("opts"), "params", __ok))
	mata: __ok = 0
	mata: st_local("map", ergm_ops_getopt(st_local("opts"), "map", __ok))
	if "`bad'" != "" | "`params'" == "" | "`map'" == "" {
		di "{err}Curve(): the syntax is Curve(terms, params(names) map(rep)) or map(matrix(name)); R's other arguments (gradient, minpar, maxpar, cov) and map functions are not available."
		error 198
	}
	_nwergm_opsub `netname', terms(`terms') nodes(.) directed(.) twomode(.) nebase(`ne') type(`type')
	local sname "`r(name)'"
	local np = r(np)
	local dep = !r(dind)
	local q : word count `params'
	local td "__netd_`++ne'"
	mata: `td' = ErgmTermData()
	mata: `td'.opkind = "sum"
	mata: `td'.opsub = (&`sname')
	mata: `td'.opdims = (`np')
	mata: ergm_ops_curve_W(`td', st_local("map"), `q', `np')
	mata: __nwergm_last_M.addterm("op:sum", `q', &stat_op(), &change_op(), `td', ergm_ops_words(st_local("params")))
	return local temps "`td'"
	return scalar dep = `dep'
	return scalar nebase = `ne'
end

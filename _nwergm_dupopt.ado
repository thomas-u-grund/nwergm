*! version 1.7.0  13nov2026 _nwergm_dupopt: a clear error for an option given twice
* Copyright (C) 2026 Thomas U. Grund
* This file is part of nwergm, a Stata package derived from the R package 'ergm (statnet)' (Mark S. Handcock, David R. Hunter, Carter T. Butts, Steven M. Goodreau, Pavel N. Krivitsky, Martina Morris and contributors; GPL-3 (+ file LICENSE)).
* nwergm is free software: you can redistribute it and/or modify it under the terms of the GNU General
* Public License, version 3, as published by the Free Software Foundation. It is distributed in the hope
* that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
* or FITNESS FOR A PARTICULAR PURPOSE. See the file LICENSE for the full text.
/* Stata's -syntax- answers an option given twice, such as
   edgecov(lazega_fr) edgecov(lazega_cow), with "option edgecov() not allowed",
   which reads as if edgecov() did not exist. This helper looks at the options
   of the nwergm call (top level only, not inside structural() or other
   parentheses) and stops with r(198) and a message that says to give the
   option once: several networks or variables go into one option, as in
   edgecov(lazega_fr lazega_cow). A call without repeated options is not
   changed. */
capture program drop _nwergm_dupopt
program _nwergm_dupopt
	version 14
	mata: _nwergm_dupopt_scan(st_local("0"))
	if `"`__dup'"' == "" exit
	local a1 `"`__arg1'"'
	local a2 `"`__arg2'"'
	local both = trim(`"`a1' `a2'"')
	local net = inlist("`__dup'", "edgecov", "dyadcov", "hamming")
	local what = cond(`net', "networks", "variables or values")
	if strpos(`"`a1'`a2'"', ",") | strpos(`"`a1'`a2'"', "(") {
		di "{p 0 0 2}{err}option {bf:`__dup'()} is given more than once. Give it once, with everything it should contain; several `what' go into one {bf:`__dup'()}.{p_end}"
	}
	else {
		di "{p 0 0 2}{err}option {bf:`__dup'()} is given more than once. Give it once and list the `what' in it: {bf:`__dup'(`both')}.{p_end}"
	}
	exit 198
end

mata:
// finds the first option name that occurs twice at the top level of the
// options (after the first comma outside parentheses and quotes); returns
// the name and the arguments of its first two occurrences in locals
void _nwergm_dupopt_scan(string scalar s)
{
	real scalar i, n, depth, inq, start, j, opened
	string scalar c, k, name, args, opts
	string rowvector names, argl

	st_local("__dup", "")
	n = strlen(s)
	depth = 0
	inq = 0
	start = 0
	for (i = 1; i <= n; i++) {
		c = substr(s, i, 1)
		if (c == `"""') inq = !inq
		if (inq) continue
		if (c == "(") depth++
		else if (c == ")") depth--
		else if (c == "," & depth == 0) {
			start = i + 1
			break
		}
	}
	if (start == 0) return
	opts = substr(s, start, .)
	n = strlen(opts)
	names = J(1, 0, "")
	argl = J(1, 0, "")
	depth = 0
	inq = 0
	name = ""
	for (i = 1; i <= n; i++) {
		c = substr(opts, i, 1)
		if (c == `"""') inq = !inq
		if (inq) continue
		if (depth == 0 & regexm(c, "[A-Za-z0-9_]")) {
			name = name + c
			continue
		}
		if (c == "(") {
			if (depth == 0 & name != "") {
				// collect the argument up to the matching parenthesis
				opened = 1
				args = ""
				for (j = i + 1; j <= n; j++) {
					k = substr(opts, j, 1)
					if (k == "(") opened++
					else if (k == ")") opened--
					if (opened == 0) break
					args = args + k
				}
				names = (names, strlower(name))
				argl = (argl, args)
				i = j
				name = ""
				continue
			}
			depth++
		}
		else if (c == ")") depth--
		name = ""
	}
	for (i = 1; i <= cols(names); i++) {
		for (j = i + 1; j <= cols(names); j++) {
			if (names[j] == names[i]) {
				st_local("__dup", names[i])
				st_local("__arg1", strtrim(argl[i]))
				st_local("__arg2", strtrim(argl[j]))
				return
			}
		}
	}
}
end

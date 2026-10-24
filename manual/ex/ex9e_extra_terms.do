do setup.doh
* Terms whose entry in the inventory has no comparison with R: observed statistic (e(obs_stats)) and pseudolikelihood fit on the Lazega friendship network.
* The estimates are written to r/stata_extra.csv, the R side is r/extra.R.
nwwebuse lazega, nwclear
encode practice, generate(prac)
encode office, generate(off)
keep seniority age prac off
save "r/laz_extra_nodes.dta", replace
export delimited using "r/laz_extra_nodes.csv", replace
nwtomata lazega_cow, mat(C)
mata: st_matrix("CC", C)
preserve
clear
svmat double CC, names(c)
export delimited using "r/laz_cow.csv", replace novarnames
restore
matrix AM = (0, 0.5 \ 1, 2)
file open fh using "r/stata_extra.csv", write replace text
file write fh "fit,kind,term,value,se" _n
foreach spec in "attrcov(prac, mat(AM))" "dyadcov(lazega_cow)" "mm(prac)" "nodeicovrange(seniority)" "nodeofactordistinct(off)" "nodeocovrange(age)" "nodefactordistinct(off)" {
	quietly nwergm lazega_fr, edges `spec' estimate(mple)
	local lab = subinstr("`spec'", ",", ";", .)
	matrix b = e(b)
	matrix V = e(V)
	matrix o = e(obs_stats)
	local k 0
	foreach nm in `: colnames b' {
		local ++k
		file write fh `"`lab',coef,`nm',"' %18.10g (b[1,`k']) "," %18.10g (sqrt(V[`k',`k'])) _n
		file write fh `"`lab',obs,`nm',"' %18.10g (o[1,`k']) ",." _n
	}
}
file close fh

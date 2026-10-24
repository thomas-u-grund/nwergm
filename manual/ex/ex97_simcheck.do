do setup.doh
nwwebuse lazega, nwclear
encode practice, generate(prac)
quietly nwergm lazega_fr, edges mutual nodematch(prac) nodeicov(seniority) gwesp(0.5) seed(1)
forvalues s = 21/23 {
	quietly nwergm simulate, nsim(4000) output(stats) seed(`s') burnin(20000) interval(1000)
	matrix SS = r(stats)
	matrix colnames SS = e m n s g
	preserve
	clear
	svmat double SS, names(col)
	export delimited using "r/stata_sim_`s'.csv", replace
	restore
}

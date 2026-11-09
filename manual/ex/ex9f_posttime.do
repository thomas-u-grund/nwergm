do setup.doh
* Run times of the steps after a fit (Section "Postestimation and the other algorithms"); one run each, written to r/posttime.csv
file open fh using "r/posttime.csv", write replace text
file write fh "network,step,seconds" _n
capture program drop tstep
program define tstep
	args net step
	quietly timer list 9
	file write fh "`net',`step'," %9.2f (r(t9)) _n
	display "RESULT `net' `step' " r(t9)
end
* Lazega advice network, the model of the benchmark table
nwwebuse lazega, nwclear
foreach v in office practice status {
	encode `v', generate(`v'n)
}
quietly nwergm lazega_adv, edges mutual nodematch(officen practicen) nodeofactor(statusn) nodeifactor(statusn) gwesp(.5) seed(1)
timer clear 9
timer on 9
quietly estat gof, gof(model distance odegree idegree espartners) seed(1)
timer off 9
tstep lazega "estat gof (five statistics)"
timer clear 9
timer on 9
quietly nwergm simulate, nsim(100) output(stats) seed(1)
timer off 9
tstep lazega "nwergm simulate nsim(100)"
* Faux Mesa High
nwwebuse mesa, nwclear
encode race, generate(racen)
quietly nwergm mesa, edges nodematch(grade racen) gwesp(.25) seed(1)
timer clear 9
timer on 9
quietly estat gof, seed(1)
timer off 9
tstep mesa "estat gof (default)"
* random undirected network, 1000 nodes, mean degree 6 (as in ex98_scaling.do)
capture program drop mknet
program define mknet
	args n
	clear
	nwclear
	set seed 20261025
	mata: n = `n'; m = round(3 * n); i = ceil(runiform(m, 1) * n); j = ceil(runiform(m, 1) * n); k = selectindex(i :< j); E = i[k], j[k]; E = uniqrows(E); st_matrix("EE", E)
	svmat double EE, names(e)
	drop if missing(e1)
	nwfromedge e1 e2, undirected name(rnet)
	nwset
	quietly nwsummarize rnet
	* the node dataset
	capture drop e1 e2
	clear
	set obs `n'
	generate g = ceil(runiform() * 3)
	generate x = rnormal()
end
mknet 1000
timer clear 9
timer on 9
quietly nwergm rnet, edges gwesp(.5) nodefactor(g) nodecov(x) seed(1)
timer off 9
tstep random1000 "fit (MCMLE)"
timer clear 9
timer on 9
quietly estat gof, seed(1)
timer off 9
tstep random1000 "estat gof (default)"
timer clear 9
timer on 9
quietly nwergm simulate, nsim(100) output(stats) seed(1)
timer off 9
tstep random1000 "nwergm simulate nsim(100)"
timer clear 9
timer on 9
quietly nwergm rnet, edges gwesp(.5) nodefactor(g) nodecov(x) seed(1) mainmethod(sa)
timer off 9
tstep random1000 "fit (stochastic approximation)"
file close fh

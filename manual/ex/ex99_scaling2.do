do setup.doh
* Timing of nwergm on random networks of increasing size: mean degree 6, three groups (g, independent of the ties).
* The result is written to r/scaling.csv (n, model, seconds, converged, iterations, native).
file open fh using "r/scaling2.csv", write replace text
file write fh "n,model,seconds,converged,iterations,native" _n
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
foreach n in 8000 {
	mknet `n'
	timer clear 1
	timer on 1
	capture quietly nwergm rnet, edges nodematch(g) nodecov(x)
	local rc = _rc
	timer off 1
	quietly timer list 1
	file write fh "`n',MPLE edges nodematch nodecov," %9.2f (r(t1)) ",.,.," (e(native)) _n
	display "RESULT `n' MPLE rc=`rc' t=" r(t1)
}
foreach n in 5000 10000 {
	mknet `n'
	timer clear 2
	timer on 2
	capture quietly nwergm rnet, edges nodematch(g) nodecov(x) gwesp(0.5) seed(1)
	local rc = _rc
	timer off 2
	quietly timer list 2
	file write fh "`n',MCMLE edges nodematch nodecov gwesp," %9.2f (r(t2)) "," (e(converged)) "," (e(mcmle_iterations)) "," (e(native)) _n
	display "RESULT `n' MCMLE rc=`rc' t=" r(t2) " conv=" e(converged)
}
file close fh

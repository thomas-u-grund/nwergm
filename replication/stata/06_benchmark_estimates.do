* Estimates of the eight benchmark models of Table 3 with nwergm, seeds 1 to 5 (default settings, as timed in Table 3).
* Writes results/bench_est_nwergm.csv; tools/compare_bench_estimates.py compares it with the ergm results.
* Run time: about 1 minute.   stata -e do stata/06_benchmark_estimates.do
do stata/setup.do
tempname fh
file open `fh' using "results/bench_est_nwergm.csv", write replace
file write `fh' "model,seed,term,b,se,iterations" _n
foreach id in B1 B2 B3 B4 B5 B6 Lazega Mesa {
	capture mata: mata drop loadcsv()
	include stata/benchmark_models.do
	forvalues s = 1/5 {
		quietly nwergm `net', `cmd' seed(`s')
		matrix b = e(b)
		matrix V = e(V)
		forvalues k = 1/`=colsof(b)' {
			file write `fh' "`id',`s',`k'," %21.15g (b[1,`k']) "," %21.15g (sqrt(V[`k',`k'])) "," (e(mcmle_iterations)) _n
		}
	}
}
file close `fh'
display "written results/bench_est_nwergm.csv"

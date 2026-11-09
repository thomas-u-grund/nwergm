* The samplers at given coefficients (manual of nwergm, Appendix C), Stata side: five times (seeds 11 to 15) draws 1,000 networks at the coefficients that
* R/05_sampler_check.R wrote to results/theta_<id>.csv, from the observed network, burn-in 16,384, interval 1,024,
* and writes the mean of each statistic to results/sampler_nwergm_<id>.csv; the draws of the first run go to
* results/draws_nwergm_<id>.csv. Run R/05_sampler_check.R first.
*   stata -e do stata/05_sampler_check.do Lazega
args id
do stata/setup.do
include stata/benchmark_models.do
preserve
quietly import delimited using "results/theta_`id'.csv", clear varnames(1)
mkmat b, matrix(TH)
restore
matrix TH = TH'
* the MPLE fit sets up the model; the draws are made at the coefficients TH, not at the MPLE
quietly nwergm `net', `cmd' estimate(mple)
matrix colnames TH = `: colnames e(b)'
tempname fh
file open `fh' using "results/sampler_nwergm_`id'.csv", write replace
file write `fh' "run,stat,mean" _n
forvalues s = 11/15 {
	quietly nwergm simulate, nsim(1000) output(stats) basis(`net') burnin(16384) interval(1024) coef(TH) seed(`s')
	matrix S = r(stats)
	if `s' == 11 {
		capture erase "results/draws_nwergm_`id'.csv"
		mata: S = st_matrix("S"); fd = fopen("results/draws_nwergm_`id'.csv", "w")
		mata: for (i = 1; i <= rows(S); i++) fput(fd, invtokens(strofreal(S[i, .], "%21.10g"), ","))
		mata: fclose(fd)
	}
	forvalues j = 1/`=colsof(S)' {
		mata: st_local("m", strofreal(mean(st_matrix("S")[., `j']), "%21.10g"))
		file write `fh' "`s',`j',`m'" _n
	}
}
file close `fh'
display "written results/sampler_nwergm_`id'.csv"

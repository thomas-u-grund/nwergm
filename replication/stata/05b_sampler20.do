* The samplers at given coefficients, Stata side of the 20 further runs: 20 times (seeds 31 to 50) draws 1,000 networks at the
* coefficients that R/05_sampler_check.R wrote to results/theta_<id>.csv, from the observed network, burn-in 16,384,
* interval 1,024, and writes the mean of each statistic to results/sampler20_nwergm_<id>.csv. Run
* R/05_sampler_check.R first; compare with R/05b_sampler20.R by  python3 tools/compare_sampler.py --runs20 <id>.
*   stata -e do stata/05b_sampler20.do B4
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
file open `fh' using "results/sampler20_nwergm_`id'.csv", write replace
file write `fh' "run,stat,mean" _n
forvalues s = 31/50 {
	quietly nwergm simulate, nsim(1000) output(stats) basis(`net') burnin(16384) interval(1024) coef(TH) seed(`s')
	matrix S = r(stats)
	forvalues j = 1/`=colsof(S)' {
		mata: st_local("m", strofreal(mean(st_matrix("S")[., `j']), "%21.10g"))
		file write `fh' "`s',`j',`m'" _n
	}
}
file close `fh'
display "written results/sampler20_nwergm_`id'.csv"

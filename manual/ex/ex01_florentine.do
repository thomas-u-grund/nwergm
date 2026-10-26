do setup.doh
*# flo_data
nwwebuse florentine, nwclear
nwset
nwsummarize flomarriage
summarize wealth
*# flo_mple
nwergm flomarriage, edges nodecov(wealth)
*# flo_mcmle
nwergm flomarriage, edges nodecov(wealth) gwesp(0.5) seed(1)
*# flo_ic
estat ic
*# flo_scalars
display "converged: " e(converged) "   iterations: " e(mcmle_iterations) "   native: " e(native)
display "sample size: " e(mcmc_samplesize) "   burn-in: " e(mcmc_burnin) "   interval: " e(mcmc_interval_final)
display "version: " e(version)
matrix list e(b)
*# flo_ereturn
ereturn list
*# flo_seed
quietly nwergm flomarriage, edges nodecov(wealth) gwesp(0.5) seed(7)
matrix b1 = e(b)
quietly nwergm flomarriage, edges nodecov(wealth) gwesp(0.5) seed(7)
matrix b2 = e(b)
quietly nwergm flomarriage, edges nodecov(wealth) gwesp(0.5) seed(8)
matrix b3 = e(b)
matrix list b1, format(%10.6f)
matrix list b2, format(%10.6f)
matrix list b3, format(%10.6f)
*# flo_pl
nwergm flomarriage, edges nodecov(wealth) gwesp(0.5) estimate(mple)
*# flo_cd
nwergm flomarriage, edges nodecov(wealth) gwesp(0.5) estimate(cd) seed(1)
*# flo_sa
nwergm flomarriage, edges nodecov(wealth) gwesp(0.5) mainmethod(sa) seed(1)
*# flo_pen
nwergm flomarriage, edges nodecov(wealth) estimate(mple) mpletype(penalized)
*# flo_offset
nwergm flomarriage, edges nodecov(wealth) gwesp(0.5) offset(nodecov_wealth 0.01) seed(1)
*# flo_init
nwergm flomarriage, edges nodecov(wealth) gwesp(0.5) init(-2.6 0.01 0) seed(1)
*# flo_curved
nwergm flomarriage, edges nodecov(wealth) gwespfree(0.5) estimate(mple)
*# flo_ereturn_mple
quietly nwergm flomarriage, edges nodecov(wealth)
ereturn list
*# flo_version
nwergm version
return list
*# flo_logstat
nwergm flomarriage, edges nodecov(wealth) logstat(nodecov_wealth)
*# flo_end

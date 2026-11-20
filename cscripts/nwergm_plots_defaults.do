* Default calls of the plots of nwergm as released in 1.10.0 (no saving, export or graph options); each default picture is exported to the
* directory in the global NWP_OUT. Run with the released version and with the changed one (after `cscript`, from the repository root, the core
* and the repository on the adopath): the PNG files must be identical. Used by test_nwergm_plots.do (reference directory: environment
* variable NWERGM_PLOT_REF) and by hand. Includes the call of the article (directed network, gof(odegree idegree distance)).
set graphics off
capture mkdir "$NWP_OUT"
local mc mcmcsamplesize(300) mcmcburnin(500) mcmcinterval(20) mcmleiterations(3) seed(1)
capture program drop __nwp_exp
program define __nwp_exp
	args file
	quietly graph export "$NWP_OUT/`file'.png", replace width(800)
	graph drop _all
end

* undirected: default statistics, explicit degree + distance, explicit default set
nwclear
nwwebuse florentine, nwclear
qui nwergm flomarriage, edges gwesp(.5) `mc'
estat gof, nsim(20) seed(3) plot
__nwp_exp und_default
estat gof, nsim(20) seed(3) plot gof(degree distance)
__nwp_exp und_degdist
estat gof, nsim(20) seed(3) plot gof(model degree espartners distance) name(mygof)
__nwp_exp und_explicit
estat mcmcdiag, plot
__nwp_exp und_mcmcdiag

* directed: default, and the call of the article
nwclear
nwset, mat((0,1,1,0,0,1,0,1\1,0,0,0,0,0,1,0\0,0,0,1,0,0,0,1\0,0,0,0,1,0,1,0\1,0,0,0,0,1,0,0\0,1,0,0,0,0,1,0\1,0,1,0,0,0,0,1\0,0,0,1,0,1,0,0)) directed name(toynet)
qui nwergm toynet, edges mutual `mc'
estat gof, nsim(15) seed(3) plot
__nwp_exp dir_default
estat gof, nsim(15) seed(3) plot gof(odegree idegree distance) name(fig_gof)
__nwp_exp dir_article

* Bayesian fit
nwclear
nwwebuse florentine, nwclear
qui nwergm flomarriage, edges triangle estimate(bayes) seed(2) iterations(300) burnin(100)
estat posterior, plot(both)
__nwp_exp bayes_both
estat posterior, plot(trace)
__nwp_exp bayes_trace
estat posterior, plot(density)
__nwp_exp bayes_density
estat mcmcdiag, plot
__nwp_exp bayes_mcmcdiag


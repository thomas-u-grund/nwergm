do setup.doh
nwwebuse lazega, nwclear
encode practice, generate(prac)
quietly nwergm lazega_fr, edges mutual nodematch(prac) nodeicov(seniority) gwesp(0.5) seed(1) mcmcinterval(1000) mcmcburnin(20000)
*# gr_mcmc
estat mcmcdiag, plot name(mcmcdiag)
graph display mcmcdiag, xsize(6.5) ysize(7.5)
graph export "../fig/mcmcdiag.pdf", name(mcmcdiag) replace
*# gr_gof
estat gof, gof(idegree espartners distance) nsim(100) seed(2) plot name(gof)
graph export "../fig/gof.pdf", name(gof) replace
*# gr_end

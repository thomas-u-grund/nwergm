do setup.doh
*# lz_data
nwwebuse lazega, nwclear
nwset
describe, short
summarize seniority age
tabulate practice
*# lz_encode
encode practice, generate(prac)
*# lz_fit
nwergm lazega_fr, edges mutual nodematch(prac) nodeicov(seniority) gwesp(0.5) seed(1)
*# lz_diag
estat mcmcdiag
*# lz_fit2
nwergm lazega_fr, edges mutual nodematch(prac) nodeicov(seniority) gwesp(0.5) seed(1) mcmcburnin(3000) mcmcinterval(50)
*# lz_diag2
estat mcmcdiag
* back to the default settings for the goodness of fit
quietly nwergm lazega_fr, edges mutual nodematch(prac) nodeicov(seniority) gwesp(0.5) seed(1)
*# lz_gof
estat gof, nsim(100) seed(2)
*# lz_gof2
estat gof, gof(idegree odegree espartners) nsim(100) seed(2)
*# lz_gofmat
matrix list r(gof_espartners)
*# lz_simstats
nwergm simulate, nsim(4) output(stats) seed(3)
matrix list r(stats)
*# lz_simnet
nwergm simulate, nsim(2) output(network) generate(lzsim) seed(3)
nwset
nwsummarize lzsim_1
*# lz_theta
nwergm simulate 20, edges mutual theta(-2 1) directed nsim(3) seed(1) generate(toy)
nwset
*# lz_end

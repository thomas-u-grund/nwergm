do setup.doh
set linesize 96
nwwebuse lazega, nwclear
encode practice, generate(prac)
quietly nwergm lazega_fr, edges mutual nodematch(prac) nodeicov(seniority) gwesp(0.5) seed(1)
*# gr_mcmc
estat mcmcdiag, plot name(mcmcdiag)
graph display mcmcdiag, xsize(6.5) ysize(7.5)
graph export "../fig/mcmcdiag.pdf", name(mcmcdiag) replace
*# gr_gof
estat gof, gof(idegree espartners distance) nsim(100) seed(2) plot xsize(6.5) ysize(5) name(gof)
graph export "../fig/gof.pdf", name(gof) replace
*# gr_gof_def
estat gof, nsim(100) seed(2) plot xsize(6.5) ysize(4) export("../fig/gof_default.pdf") name(gofdef, replace)
*# gr_gof_pan
estat gof, gof(model idegree odegree espartners distance) nsim(100) seed(2) plot panels title("Lazega friendship: goodness of fit") xsize(6.5) ysize(7.5) export("../fig/gof_panels.pdf") name(gofpan, replace)
*# gr_gof_two
clear
set seed 20261024
nwclear
mata: g1 = (runiform(30,1) :> 0.5) :+ 1
mata: g2 = (runiform(12,1) :> 0.5) :+ 1
mata: P = 0.08 :+ 0.22 :* ((g1 * J(1,12,1)) :== (J(30,1,1) * rowshape(g2,1)))
mata: B = (runiform(30,12) :< P)
mata: st_matrix("B", transposeonly(B))
nwset, mat(B) bipartite name(clubs)
set obs 42
generate byte kind = .
mata: st_store(., "kind", (g1 \ g2))
quietly nwergm clubs, edges nodemix(kind) bgwdegree2(0.5) seed(1)
estat gof, nsim(100) seed(2) plot xsize(6.5) ysize(7.5) export("../fig/gof_twomode.pdf") name(goftwo, replace)
*# gr_post
nwclear
nwwebuse florentine, nwclear
quietly nwergm flomarriage, edges triangle estimate(bayes) iterations(5000) burnin(2000) seed(1)
estat posterior, plot(both) xsize(6.5) ysize(5) export("../fig/posterior.pdf") name(post, replace)
*# gr_end

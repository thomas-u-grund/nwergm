do setup.doh
*# con_edges
nwwebuse florentine, nwclear
nwergm flomarriage, edges nodecov(wealth) gwesp(0.5) seed(1)
nwergm flomarriage, edges nodecov(wealth) gwesp(0.5) constraints(edges) seed(1)
*# two_make
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
nwsummarize clubs
*# two_fit
nwergm clubs, edges nodemix(kind)
*# two_fit2
nwergm clubs, edges nodemix(kind) bgwdegree2(0.5) seed(1)
*# two_gof
estat gof, gof(b1degree b2degree dspartners distance model) nsim(100) seed(2)
*# two_ops
nwergm clubs, edges nodemix(kind) operators(Proj1(edges triangle)) seed(1)
*# op_sym
nwwebuse lazega, nwclear
encode practice, generate(prac)
nwergm lazega_fr, edges mutual nodematch(prac) operators(Symmetrize(triangle, rule(strong))) seed(1)
*# st_fit
nwergm lazega_fr, edges mutual nodematch(prac) structural(twopath cycle(k=3)) seed(1)
*# lab_fit
nwergm lazega_fr, edges mutual nodematch(prac) coeflabel(nodematch_prac samepractice) 
*# fix_fit
nwergm lazega_fr, edges mutual nodematch(prac) constraints(odegrees) seed(1)
*# ex_end

do setup.doh
*# cons_prep
nwwebuse lazega, nwclear
encode practice, generate(prac)
encode office, generate(off)
tempfile lnodes
save `lnodes'
mata: o = st_data(., "off"); F = (o :== 1) * (o :== 1)'; _diag(F, 0); st_matrix("F", F)
nwset, mat(F) directed name(boston)
use `lnodes', clear
*# cons_block
nwergm lazega_fr, edges mutual nodematch(prac) constraints(fixallbut(boston)) seed(1)
*# cons_deg
nwergm lazega_fr, edges mutual nodematch(prac) constraints(odegrees) seed(1)
*# cons_sim
nwergm simulate, nsim(3) output(stats) seed(1)
matrix list r(stats)
*# obs_prep
nwwebuse florentine, nwclear
nwtomata flomarriage, mat(A)
mata: A[1,2] = A[2,1] = 0
mata: A[3,5] = A[5,3] = 0
mata: A[4,9] = A[9,4] = 0
mata: U = J(16, 16, 0)
mata: U[1,2] = U[2,1] = U[3,5] = U[5,3] = U[4,9] = U[9,4] = 1
mata: st_matrix("A0", A); st_matrix("U", U)
tempfile nodes
save `nodes'
nwset, mat(A0) undirected name(flo0)
nwset, mat(U) undirected name(unobs)
use `nodes', clear
*# obs_fit
nwergm flo0, edges nodecov(wealth) gwesp(0.5) obsconstraints(fixallbut(unobs)) seed(1)
*# obs_end

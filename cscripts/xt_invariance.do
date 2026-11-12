cscript

* DRAFT, not yet run.
* xt_invariance: statistics and pseudolikelihood estimates do not depend on the order in which a network stores its
* nodes. Routes: a permuted adjacency matrix (with the node attributes permuted the same way), an edge list with names
* n1..n14 (stored as n1, n10, n11, ..., n2, ...), the lawyers' advice network (stored as n1, n10, ...) against a copy in
* natural order. Also: predict permutes with the nodes; the observed column of estat gof is unchanged.
* No R reference is needed: the reference is the unpermuted network.
* Expected runtime: about 30-60 seconds.
* Runs from the repository root; the runner sets PLUS, the adopath and the plugin path.
capture program drop nwinstall
set graphics off
local nwcore : env NWCORE

* U14 (see xt_mple_crossroute.do) and a permutation that also moves an isolate-free hub (node 13) to the front
nwclear
clear
mata: ui = (1,2,3,1,4,4,5,1,6,1,5,1,6,7,9,10,4,7,10,2,5,6,10,11,2,7,10)
mata: uj = (2,4,4,5,5,6,6,7,8,9,9,10,11,11,11,11,12,12,12,13,13,13,13,13,14,14,14)
mata: A = J(14, 14, 0)
mata: for (k = 1; k <= 27; k++) A[ui[k], uj[k]] = 1
mata: A = A + A'
mata: p = (13, 3, 7, 1, 12, 5, 9, 2, 11, 6, 14, 4, 10, 8)
mata: st_matrix("AU", A)
mata: st_matrix("AP", A[p, p])
mata: st_matrix("PERM", p)
nwset, mat(AU) undirected name(U) nooutput
nwset, mat(AP) undirected name(UP) nooutput
clear
set obs 14
gen double g = mod(_n - 1, 2) + 1
gen double z = sqrt(_n)
* the permuted attributes: row r of UP is node p[r] of U
gen double gp = .
gen double zp = .
mata: gg = st_data(., "g"); zz = st_data(., "z"); st_store(., "gp", gg[p]); st_store(., "zp", zz[p])

* (the first draft used 14 terms on 14 nodes: the MPLE is separated (residual deviance 0, |b| up to 900), so b is
* not determined and cannot be compared across node orders; a smaller identified model instead; the statistics of
* the large model are still compared below)
local mbig "triangle kstar(2) gwesp(.5) gwdsp(.3) degree(1/3) esp(0/2) gwdegree(.8)"
qui nwergm U, edges `mbig' nodematch(g) nodecov(z) method(mple)
matrix SB0 = e(obs_stats)
qui nwergm UP, edges `mbig' nodematch(gp) nodecov(zp) method(mple)
assert mreldif(SB0, e(obs_stats)) < 1e-12
local m1 "gwesp(.5) gwdegree(.8)"
nwergm U, edges `m1' nodematch(g) nodecov(z) method(mple)
matrix S0 = e(obs_stats)
matrix b0 = e(b)
matrix V0 = e(V)
local ll0 = e(ll)
predict, matrix(P0)
nwergm UP, edges `m1' nodematch(gp) nodecov(zp) method(mple)
matrix S1 = e(obs_stats)
matrix b1 = e(b)
matrix V1 = e(V)
assert mreldif(S0, S1) < 1e-12
assert mreldif(b0, b1) < 1e-8
assert mreldif(V0, V1) < 1e-8
assert reldif(`ll0', e(ll)) < 1e-10
predict, matrix(P1)
* P1[r, s] is the dyad (p[r], p[s]) of U
mata: P0 = st_matrix("P0"); P1 = st_matrix("P1"); p = st_matrix("PERM")
mata: D = abs(P0[p, p] - P1); D = editmissing(D, 0); st_numscalar("dmax", max(D))
mata: st_numscalar("nmis", sum(missing(P0[p, p]) :!= missing(P1)))
assert dmax < 1e-8
assert nmis == 0
di "PASS permuted matrix: statistics, MPLE, covariance, pseudolikelihood and predict are permutation invariant"

* the observed column of estat gof does not depend on the node order
qui nwergm U, edges triangle method(mple)
qui estat gof, gof(degree espartners dspartners model) nsim(5) seed(1)
matrix Gd0 = r(gof_degree)
matrix Ge0 = r(gof_espartners)
matrix Gs0 = r(gof_dspartners)
local tri0 = r(obs_triad_300)
qui nwergm UP, edges triangle method(mple)
qui estat gof, gof(degree espartners dspartners model) nsim(5) seed(1)
matrix Gd1 = r(gof_degree)
matrix Ge1 = r(gof_espartners)
matrix Gs1 = r(gof_dspartners)
foreach t in d e s {
	matrix c0 = G`t'0[1..., 1]
	matrix c1 = G`t'1[1..., 1]
	assert mreldif(c0, c1) == 0
}
assert r(obs_triad_300) == `tri0'
* hand-derived: the degree column sums to the number of nodes, the edgewise shared partner column to the ties,
* the dyadwise one to the dyads; 5 triangles (R: summary(nw ~ triangle) = 5)
mata: st_numscalar("sd", colsum(st_matrix("Gd1")[., 1])); st_numscalar("se", colsum(st_matrix("Ge1")[., 1])); st_numscalar("ss", colsum(st_matrix("Gs1")[., 1]))
assert sd == 14
assert se == 27
assert ss == 91
assert `tri0' == 5
di "PASS estat gof observed values: permutation invariant and consistent"

* ---------------------------------------------------------------------------------------------------------------
* edge list with string names: the network stores its nodes in the order of the sorted names (n1, n10, n11, ..., n2, ...)
* (the node attributes are not needed any more; no preserve, nwset may preserve the data itself)
clear
mata: st_addobs(27)
gen str4 ego = ""
gen str4 alter = ""
mata: st_sstore(., "ego", "n" :+ strofreal(ui')); st_sstore(., "alter", "n" :+ strofreal(uj'))
nwset ego alter, edgelist undirected name(UE)
qui nwsummarize UE
assert r(nodes) == 14 & r(edges) == 27
assert "`r(directed)'" == "false"
nwergm UE, edges `m1' method(mple)
matrix S2 = e(obs_stats)
matrix b2 = e(b)
nwergm U, edges `m1' method(mple)
matrix S3 = e(obs_stats)
matrix b3 = e(b)
assert mreldif(S2, S3) < 1e-12
assert mreldif(b2, b3) < 1e-8
di "PASS edge list with name-sorted node order: same statistics and MPLE"

* ---------------------------------------------------------------------------------------------------------------
* the lawyers' advice network (directed, 71 nodes, stored as n1, n10, n11, ...): a copy in natural order n1, n2, ...
nwuse `"`nwcore'/data/lazega"', nwclear
_nwsyntax lazega_adv
mata: nm = (`netobj'->get_nodenames()); nm = nm[1..`nodes']
mata: num = strtoreal(substr(nm, 2, .)); pl = order(num', 1)'
nwtomata lazega_adv, mat(__L)
mata: st_matrix("LN", __L[pl, pl])
mata: st_local("labsnat", invtokens(nm[pl], ","))
* first stored name must not be n1, n2, ... in sequence (otherwise this block tests nothing)
mata: st_numscalar("natural", all(num :== (1..cols(num))))
assert natural == 0
nwset, mat(LN) directed name(lazcopy) labs(`labsnat') nooutput
local m2 "mutual ctriple transitiveties gwesp(.5) gwidegree(.7) ostar(2) idegree(0/2) esp(1/2) type(OTP)"
nwergm lazega_adv, edges `m2' method(mple)
matrix S4 = e(obs_stats)
matrix b4 = e(b)
nwergm lazcopy, edges `m2' method(mple)
matrix S5 = e(obs_stats)
matrix b5 = e(b)
assert mreldif(S4, S5) < 1e-12
assert mreldif(b4, b5) < 1e-8
di "PASS lazega in stored order and in natural order: same statistics and MPLE"

di "ALL PASS"

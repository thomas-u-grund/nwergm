cscript

* DRAFT, not yet run.
* xt_tiny: the smallest networks and models with a single coefficient or a single column (1 x 1 Mata matrices, one-row
* tables): 2- and 3-node networks, a 1 x 2 two-mode network, terms that expand into one column, offset() leaving one
* free coefficient, nwergm simulate with 1-3 nodes and with coefficients at the boundary.
* Every number is derived by hand (closed form of the edges-only model: b = logit(ties / dyads),
* se = 1 / sqrt(N p (1 - p)), ll = ties ln p + (N - ties) ln(1 - p)).
* Expected runtime: about 30 seconds.
* Runs from the repository root; the runner sets PLUS, the adopath and the plugin path.
capture program drop nwinstall
set graphics off

nwclear
clear
mata: st_matrix("T3", (0,1,0 \ 1,0,0 \ 0,0,0))
mata: st_matrix("D2", (0,1 \ 0,0))
mata: st_matrix("U2", (0,1 \ 1,0))
mata: st_matrix("B12", (1 \ 0))
mata: st_matrix("U5", (0,1,1,0,0 \ 1,0,1,0,0 \ 1,1,0,1,0 \ 0,0,1,0,1 \ 0,0,0,1,0))
nwset, mat(T3) undirected name(T3) nooutput
nwset, mat(D2) directed name(D2) nooutput
nwset, mat(U2) undirected name(U2) nooutput
* two-mode: one mode-1 node (the column) and two mode-2 nodes (the rows), one tie
nwset, mat(B12) bipartite name(B12) nooutput
nwset, mat(U5) undirected name(U5) nooutput
clear
set obs 5
gen double g2 = (_n > 2) + 1
gen double x = _n

* ---------------------------------------------------------------------------------------------------------------
* 3 nodes, 1 tie: p = 1/3, b = ln(1/2), se = 1/sqrt(3 * 1/3 * 2/3) = 1.224744871391589, ll = ln(1/3) + 2 ln(2/3)
nwergm T3, edges
assert e(N) == 3 & e(ties) == 1 & e(nodes) == 3
assert colsof(e(b)) == 1
assert abs(_b[edges] - ln(0.5)) < 1e-8
assert abs(_se[edges] - 1.224744871391589) < 1e-7
assert abs(e(ll) - (ln(1/3) + 2 * ln(2/3))) < 1e-8
estat ic
matrix IC = r(S)
assert IC[1,1] == 3 & IC[1,4] == 1
predict, matrix(P)
mata: P = st_matrix("P"); O = 1 :- I(3); st_numscalar("dp", max(editmissing(abs(P :- 1/3) :* O, 0)))
assert dp < 1e-8
predict, frame(FT)
frame FT: assert _N == 3
frame drop FT
estat gof, nsim(2) seed(1)
matrix GM = r(gof_model)
assert rowsof(GM) == 1 & GM[1,1] == 1
nwergm simulate, nsim(1) generate(t3s) seed(1)
qui nwsummarize t3s
assert r(nodes) == 3
di "PASS 3-node network, edges only"

* 2 nodes directed, one arc: 2 ordered dyads, p = 1/2: b = 0, se = 1/sqrt(2 * 1/4) = sqrt(2)
nwergm D2, edges
assert e(N) == 2
assert abs(_b[edges]) < 1e-8
assert abs(_se[edges] - sqrt(2)) < 1e-7
* receiver on 2 nodes expands into ONE column (receiver2 = in-degree of node 2 = 1); edges + receiver separate the
* data completely (MPLE does not exist), the statistics are still exact: (1, 1). R: summary(D2 ~ edges + receiver) = 1 1
nwergm D2, edges receiver method(mple)
matrix S = e(obs_stats)
assert colsof(S) == 2 & S[1,1] == 1 & S[1,2] == 1
nwergm D2, edges sender method(mple)
matrix S = e(obs_stats)
assert colsof(S) == 2 & S[1,1] == 1 & S[1,2] == 0       // sender2 = out-degree of node 2 = 0
di "PASS 2-node directed network"

* 2 nodes undirected with its single dyad tied: the outcome does not vary, r(2000) (nwergm.ado ~2234)
capture noisily nwergm U2, edges
* one dyad: logit stops with r(2001) "insufficient observations" (r(2000) needs more than one observation)
assert _rc == 2001
* two-mode 1 x 2 with one tie: 2 informative dyads, b = 0
nwergm B12, edges
assert e(N) == 2
assert abs(_b[edges]) < 1e-8
di "PASS 2-node undirected and 1 x 2 two-mode networks"

* ---------------------------------------------------------------------------------------------------------------
* terms that expand into a single column on U5 (ties 1-2 1-3 2-3 3-4 4-5; degrees 2 2 3 2 1; g2 = 1 1 2 2 2)
* nodefactor(g2) with two levels -> one column: sum of degrees of level-2 nodes = 3 + 2 + 1 = 6
* degree(1) -> one column: 1 node; kstar(2) = 1 + 1 + 3 + 1 + 0 = 6; triangle = 1
nwergm U5, edges nodefactor(g2) method(mple)
matrix S = e(obs_stats)
assert colsof(S) == 2 & S[1,1] == 5 & S[1,2] == 6
nwergm U5, edges degree(1) method(mple)
matrix S = e(obs_stats)
assert colsof(S) == 2 & S[1,2] == 1
* offset() leaving one free coefficient: e(V) has one non-zero cell
nwergm U5, edges kstar(2) offset(kstar_2 0) method(mple)
matrix S = e(obs_stats)
assert S[1,2] == 6
assert e(df_m) == 1
matrix V = e(V)
assert V[2,2] == 0 & V[1,1] > 0
* with kstar_2 fixed at 0 the model is the edges-only model: b = logit(5/10) = 0
assert abs(_b[edges]) < 1e-8
assert _b[kstar_2] == 0
predict, matrix(P5)
mata: P = st_matrix("P5"); O = 1 :- I(5); st_numscalar("dp", max(editmissing(abs(P :- 0.5) :* O, 0)))
assert dp < 1e-8
estat gof, gof(model) nsim(3) seed(2)
matrix GM = r(gof_model)
assert rowsof(GM) == 2 & GM[1,1] == 5 & GM[2,1] == 6
di "PASS one-column terms and one free coefficient"

* ---------------------------------------------------------------------------------------------------------------
* nwergm simulate with a number of nodes: boundary coefficients and the smallest sizes
nwergm simulate 6, edges theta(-50) nsim(1) generate(e6) seed(1)
qui nwsummarize e6
assert r(nodes) == 6 & r(edges) == 0
nwergm simulate 6, edges theta(50) nsim(1) generate(k6) seed(1)
qui nwsummarize k6
assert r(nodes) == 6 & r(edges) == 15
nwergm simulate 6, edges theta(50) directed nsim(1) generate(k6d) seed(1)
qui nwsummarize k6d
assert "`r(directed)'" == "true" & r(arcs) == 30
nwergm simulate 5, edges theta(50) bipartite(2) nsim(1) generate(k23) seed(1)
qui nwsummarize k23
assert "`r(mode2)'" == "true" & r(nodes1) == 2 & r(nodes2) == 3 & r(edges) == 6
nwergm simulate 2, edges theta(0) nsim(3) generate(two) seed(1)
forvalues s = 1/3 {
	qui nwsummarize two_`s'
	assert r(nodes) == 2 & inlist(r(edges), 0, 1)
}
* theta() must have one value per statistic (nwergm.ado nwergm_simulate: error 198)
capture noisily nwergm simulate 6, edges mutual theta(-1) directed nsim(1)
assert _rc == 198
capture noisily nwergm simulate 6, edges theta(-1 2) nsim(1)
assert _rc == 198
* a 1-node network has no dyad: refused or an empty network, never a Mata error
capture noisily nwergm simulate 1, edges theta(0) nsim(1) generate(one)
local rc1 = _rc
assert `rc1' < 3000 | `rc1' > 3999
if `rc1' == 0 {
	qui nwsummarize one
	assert r(nodes) == 1 & r(edges) == 0
}
di "PASS nwergm simulate: boundary coefficients and tiny networks"

di "ALL PASS"

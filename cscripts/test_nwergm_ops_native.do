cscript

capture adopath ++ "."
capture adopath ++ "lib"
* The core package nwcommands is found through the environment variable NWCORE (path of the core checkout).
local nwcore : env NWCORE
if `"`nwcore'"' == "" {
	di as error "set the environment variable NWCORE to the directory of the nwcommands (core) package"
	exit 198
}
adopath ++ `"`nwcore'"'
adopath ++ `"`c(pwd)'"'
quietly do `"`nwcore'/unw_core.do"'
do unw_ergm.do
capture adopath ++ "lib/plugins/macos"
capture adopath ++ "lib/plugins/unix"
capture adopath ++ "lib/plugins/windows"

* Certifies the native engine of the operator terms (Sum, Prod, F, Symmetrize, S, Project, nested operators):
*  (1) the plugin's change statistics (MPLE design, mode 1) equal brute-force differences of the Mata statistic of the
*      operator term on the network with the dyad set to 1 and to 0,
*  (2) after an MCMC run in the plugin the statistics it tracked incrementally equal the statistic recomputed from the
*      final network (this exercises the toggles carried through to the derived networks).
set seed 20261101

mata:
mata set matastrict off

void ot_rand_graph(class ErgmGraph G, real scalar n, real scalar dir, real scalar p)
{
	real scalar i, j
	G.init(n, dir)
	for (i=1; i<=n; i++) for (j=1; j<=n; j++) {
		if (i == j) continue
		if (!dir & j < i) continue
		if (runiform(1,1) < p) G.toggle(i,j)
	}
}
void ot_rand_bip(class ErgmGraph G, real scalar n1, real scalar n2, real scalar p)
{
	real scalar i, j
	G.init(n1+n2, 0)
	G.set_bipartite((J(n1,1,1) \ J(n2,1,2)))
	for (i=1; i<=n1; i++) for (j=n1+1; j<=n1+n2; j++) if (runiform(1,1) < p) G.toggle(i,j)
}
// maximum |native - brute force| over all dyads of the toward-one change statistic
real scalar ot_check_mple(class ErgmModel M, class ErgmGraph G)
{
	real matrix D
	class ErgmGraph scalar H
	real rowvector s0, s1
	real scalar r, i, j, p, dmax, n, tied, a, b, ii, jj
	if (ErgmNativeSetup(M, 1, G) != 1) {
		printf("native setup refused the model\n")
		return(9e9)
	}
	D = ErgmNativeBuildMPLEData(M, G)
	p = M.nparam()
	n = G.n
	r = 0
	dmax = 0
	for (i=1; i<=(G.bipartite ? rows(G.mode1nodes) : n); i++) {
		for (j=1; j<=(G.bipartite ? rows(G.mode2nodes) : n); j++) {
			a = G.bipartite ? G.mode1nodes[i] : i
			b = G.bipartite ? G.mode2nodes[j] : j
			if (!G.bipartite) {
				if (a == b) continue
				if (!G.directed & b < a) continue
			}
			r++
			H = ergm_graph_clone(G)
			tied = H.has_edge(a,b)
			if (tied) {
				s1 = M.full_statistic(H)
				H.toggle(a,b)
				s0 = M.full_statistic(H)
			}
			else {
				s0 = M.full_statistic(H)
				H.toggle(a,b)
				s1 = M.full_statistic(H)
			}
			dmax = max((dmax, max(abs((s1 - s0) - D[r, 1..p]))))
		}
	}
	if (r != rows(D)) {
		printf("dyad count mismatch %g vs %g\n", r, rows(D))
		return(9e9)
	}
	return(dmax)
}
// the statistics tracked by the plugin equal the statistics of the final network
real scalar ot_check_mcmc(class ErgmModel M, class ErgmGraph G, real scalar nsamp)
{
	real matrix S
	real rowvector theta
	if (ErgmNativeSetup(M, 1, G) != 1) return(9e9)
	theta = J(1, M.nparam(), 0)
	theta[1] = -0.2
	S = ErgmMCMCSample(M, G, theta, 2000, 200, nsamp, &ergm_propose_uniform())
	return(max(abs(S[nsamp, .] - M.full_statistic(G))))
}
end

* ---------- one undirected graph with a categorical attribute, one directed graph, one bipartite graph ----------
mata:
GU = ErgmGraph()
ot_rand_graph(GU, 24, 0, 0.18)
xU = ceil(3 * runiform(24, 1))
GD = ErgmGraph()
ot_rand_graph(GD, 20, 1, 0.12)
xD = ceil(2 * runiform(20, 1))
GB = ErgmGraph()
ot_rand_bip(GB, 9, 12, 0.3)
xB = ceil(2 * runiform(21, 1))

// ---- sub-models ----
// A = edges + triangle + nodematch(x) on the undirected graph
tdA1 = ErgmTermData()
tdA2 = ErgmTermData()
tdA3 = ErgmTermData()
tdA3.attr = xU
MA = ErgmModel()
MA.init()
MA.addterm("edges", 1, &stat_edges(), &change_edges(), tdA1, ("edges"))
MA.addterm("triangle", 1, &stat_triangle(), &change_triangle(), tdA2, ("triangle"))
MA.addterm("nodematch", 1, &stat_nodematch(), &change_nodematch(), tdA3, ("nodematch_x"))
// A2: the same terms again (for Sum with two formulas)
tdA1b = ErgmTermData()
tdA2b = ErgmTermData()
tdA3b = ErgmTermData()
tdA3b.attr = xU
MA2 = ErgmModel()
MA2.init()
MA2.addterm("edges", 1, &stat_edges(), &change_edges(), tdA1b, ("edges"))
MA2.addterm("triangle", 1, &stat_triangle(), &change_triangle(), tdA2b, ("triangle"))
MA2.addterm("nodematch", 1, &stat_nodematch(), &change_nodematch(), tdA3b, ("nodematch_x"))
// F: nodematch(x) filter model
tdF = ErgmTermData()
tdF.attr = xU
MF = ErgmModel()
MF.init()
MF.addterm("nodematch", 1, &stat_nodematch(), &change_nodematch(), tdF, ("nodematch_x"))
// B = edges + mutual + triangle... on the directed graph: edges, mutual, nodematch(x)
tdB1 = ErgmTermData()
tdB2 = ErgmTermData()
tdB3 = ErgmTermData()
tdB3.attr = xD
MB = ErgmModel()
MB.init()
MB.addterm("edges", 1, &stat_edges(), &change_edges(), tdB1, ("edges"))
MB.addterm("mutual", 1, &stat_mutual(), &change_mutual(), tdB2, ("mutual"))
MB.addterm("nodematch", 1, &stat_nodematch(), &change_nodematch(), tdB3, ("nodematch_x"))
// U on the symmetrized directed graph: edges + triangle + degree(1)
tdU1 = ErgmTermData()
tdU2 = ErgmTermData()
MU = ErgmModel()
MU.init()
MU.addterm("edges", 1, &stat_edges(), &change_edges(), tdU1, ("edges"))
MU.addterm("triangle", 1, &stat_triangle(), &change_triangle(), tdU2, ("triangle"))
// projection model: edges + triangle on the one-mode projection
tdP1 = ErgmTermData()
tdP2 = ErgmTermData()
MP = ErgmModel()
MP.init()
MP.addterm("edges", 1, &stat_edges(), &change_edges(), tdP1, ("edges"))
MP.addterm("triangle", 1, &stat_triangle(), &change_triangle(), tdP2, ("triangle"))
end

di "operator engine: Sum"
mata:
tdOp = ErgmTermData()
tdOp.opsub = (&MA, &MA2)
tdOp.opW = (I(3), 2 * I(3))
tdOp.opdims = (3, 3)
tdOp.opkind = "sum"
M1 = ErgmModel()
M1.init()
tdE = ErgmTermData()
M1.addterm("edges", 1, &stat_edges(), &change_edges(), tdE, ("edges"))
M1.addterm("op:sum", 3, &stat_op(), &change_op(), tdOp, ("Sum~a", "Sum~b", "Sum~c"))
d = ot_check_mple(M1, GU)
printf("  Sum: MPLE design max difference %g\n", d)
assert(d < 1e-9)
d = ot_check_mcmc(M1, GU, 40)
printf("  Sum: MCMC max difference %g\n", d)
assert(d < 1e-9)
end

di "operator engine: Sum with a sum preset"
mata:
tdOpS = ErgmTermData()
tdOpS.opsub = (&MA)
tdOpS.opW = J(1, 3, 1)
tdOpS.opdims = (3)
tdOpS.opkind = "sum"
M2 = ErgmModel()
M2.init()
tdE2 = ErgmTermData()
M2.addterm("edges", 1, &stat_edges(), &change_edges(), tdE2, ("edges"))
M2.addterm("op:sum", 1, &stat_op(), &change_op(), tdOpS, ("Sum~s"))
d = ot_check_mple(M2, GU)
printf("  Sum preset: MPLE design max difference %g\n", d)
assert(d < 1e-9)
d = ot_check_mcmc(M2, GU, 40)
printf("  Sum preset: MCMC max difference %g\n", d)
assert(d < 1e-9)
end

di "operator engine: Prod"
mata:
tdOpP = ErgmTermData()
tdOpP.opsub = (&MA, &MA2)
tdOpP.opW = (I(3), 2 * I(3))
tdOpP.opdims = (3, 3)
tdOpP.opkind = "prod"
M3 = ErgmModel()
M3.init()
tdE3 = ErgmTermData()
M3.addterm("edges", 1, &stat_edges(), &change_edges(), tdE3, ("edges"))
M3.addterm("op:prod", 3, &stat_op(), &change_op(), tdOpP, ("Prod~a", "Prod~b", "Prod~c"))
d = ot_check_mple(M3, GU)
printf("  Prod: MPLE design max difference %g\n", d)
assert(d < 1e-6)
d = ot_check_mcmc(M3, GU, 40)
printf("  Prod: MCMC max difference %g\n", d)
assert(d < 1e-6)
end

di "operator engine: F (filter nodematch)"
mata:
tdOpF = ErgmTermData()
tdOpF.opsub = (&MA)
tdOpF.opfilter = &MF
tdOpF.opnum = (0, 0)
tdOpF.opkind = "filter"
M4 = ErgmModel()
M4.init()
tdE4 = ErgmTermData()
M4.addterm("edges", 1, &stat_edges(), &change_edges(), tdE4, ("edges"))
M4.addterm("op:filter", 3, &stat_op(), &change_op(), tdOpF, ("F~edges", "F~triangle", "F~nodematch"))
d = ot_check_mple(M4, GU)
printf("  F: MPLE design max difference %g\n", d)
assert(d < 1e-9)
d = ot_check_mcmc(M4, GU, 40)
printf("  F: MCMC max difference %g\n", d)
assert(d < 1e-9)
end

di "operator engine: Symmetrize (four rules)"
mata:
tdOpY = ErgmTermData()
tdOpY.opsub = (&MU)
tdOpY.opnum = (1)
tdOpY.opkind = "sym"
M5 = ErgmModel()
M5.init()
tdE5 = ErgmTermData()
M5.addterm("edges", 1, &stat_edges(), &change_edges(), tdE5, ("edges"))
M5.addterm("op:sym", 2, &stat_op(), &change_op(), tdOpY, ("Sym~edges", "Sym~triangle"))
d = ot_check_mple(M5, GD)
printf("  Symmetrize rule 1: MPLE design max difference %g\n", d)
assert(d < 1e-9)
d = ot_check_mcmc(M5, GD, 40)
printf("  Symmetrize rule 1: MCMC max difference %g\n", d)
assert(d < 1e-9)
end
mata:
tdOpY = ErgmTermData()
tdOpY.opsub = (&MU)
tdOpY.opnum = (2)
tdOpY.opkind = "sym"
M5 = ErgmModel()
M5.init()
tdE5 = ErgmTermData()
M5.addterm("edges", 1, &stat_edges(), &change_edges(), tdE5, ("edges"))
M5.addterm("op:sym", 2, &stat_op(), &change_op(), tdOpY, ("Sym~edges", "Sym~triangle"))
d = ot_check_mple(M5, GD)
printf("  Symmetrize rule 2: MPLE design max difference %g\n", d)
assert(d < 1e-9)
d = ot_check_mcmc(M5, GD, 40)
printf("  Symmetrize rule 2: MCMC max difference %g\n", d)
assert(d < 1e-9)
end
mata:
tdOpY = ErgmTermData()
tdOpY.opsub = (&MU)
tdOpY.opnum = (3)
tdOpY.opkind = "sym"
M5 = ErgmModel()
M5.init()
tdE5 = ErgmTermData()
M5.addterm("edges", 1, &stat_edges(), &change_edges(), tdE5, ("edges"))
M5.addterm("op:sym", 2, &stat_op(), &change_op(), tdOpY, ("Sym~edges", "Sym~triangle"))
d = ot_check_mple(M5, GD)
printf("  Symmetrize rule 3: MPLE design max difference %g\n", d)
assert(d < 1e-9)
d = ot_check_mcmc(M5, GD, 40)
printf("  Symmetrize rule 3: MCMC max difference %g\n", d)
assert(d < 1e-9)
end
mata:
tdOpY = ErgmTermData()
tdOpY.opsub = (&MU)
tdOpY.opnum = (4)
tdOpY.opkind = "sym"
M5 = ErgmModel()
M5.init()
tdE5 = ErgmTermData()
M5.addterm("edges", 1, &stat_edges(), &change_edges(), tdE5, ("edges"))
M5.addterm("op:sym", 2, &stat_op(), &change_op(), tdOpY, ("Sym~edges", "Sym~triangle"))
d = ot_check_mple(M5, GD)
printf("  Symmetrize rule 4: MPLE design max difference %g\n", d)
assert(d < 1e-9)
d = ot_check_mcmc(M5, GD, 40)
printf("  Symmetrize rule 4: MCMC max difference %g\n", d)
assert(d < 1e-9)
end

di "operator engine: S (induced subgraph)"
mata:
tdOpI = ErgmTermData()
tdOpI.opsub = (&MU)
tdOpI.opnodes = select((1::24), xU :== 1)
tdOpI.opnum = (0, 24)
tdOpI.opkind = "sub"
M6 = ErgmModel()
M6.init()
tdE6 = ErgmTermData()
M6.addterm("edges", 1, &stat_edges(), &change_edges(), tdE6, ("edges"))
M6.addterm("op:sub", 2, &stat_op(), &change_op(), tdOpI, ("S~edges", "S~triangle"))
d = ot_check_mple(M6, GU)
printf("  S: MPLE design max difference %g\n", d)
assert(d < 1e-9)
d = ot_check_mcmc(M6, GU, 40)
printf("  S: MCMC max difference %g\n", d)
assert(d < 1e-9)
end

di "operator engine: Project"
mata:
tdOpJ = ErgmTermData()
tdOpJ.opsub = (&MP)
tdOpJ.opnum = (1)
tdOpJ.opkind = "proj"
M7 = ErgmModel()
M7.init()
tdE7 = ErgmTermData()
M7.addterm("edges", 1, &stat_edges(), &change_edges(), tdE7, ("edges"))
M7.addterm("op:proj", 2, &stat_op(), &change_op(), tdOpJ, ("Proj~edges", "Proj~triangle"))
d = ot_check_mple(M7, GB)
printf("  Project mode 1: MPLE design max difference %g\n", d)
assert(d < 1e-9)
d = ot_check_mcmc(M7, GB, 40)
printf("  Project mode 1: MCMC max difference %g\n", d)
assert(d < 1e-9)
end
mata:
tdOpJ = ErgmTermData()
tdOpJ.opsub = (&MP)
tdOpJ.opnum = (2)
tdOpJ.opkind = "proj"
M7 = ErgmModel()
M7.init()
tdE7 = ErgmTermData()
M7.addterm("edges", 1, &stat_edges(), &change_edges(), tdE7, ("edges"))
M7.addterm("op:proj", 2, &stat_op(), &change_op(), tdOpJ, ("Proj~edges", "Proj~triangle"))
d = ot_check_mple(M7, GB)
printf("  Project mode 2: MPLE design max difference %g\n", d)
assert(d < 1e-9)
d = ot_check_mcmc(M7, GB, 40)
printf("  Project mode 2: MCMC max difference %g\n", d)
assert(d < 1e-9)
end

di "operator engine: nested (S of Symmetrize, F inside Sum)"
mata:
tdOpY2 = ErgmTermData()
tdOpY2.opsub = (&MU)
tdOpY2.opnum = (1)
tdOpY2.opkind = "sym"
MS = ErgmModel()
MS.init()
MS.addterm("op:sym", 2, &stat_op(), &change_op(), tdOpY2, ("Sym~edges", "Sym~triangle"))
tdOpS3 = ErgmTermData()
tdOpS3.opsub = (&MS)
tdOpS3.opnodes = select((1::20), xD :== 1)
tdOpS3.opnum = (0, 20)
tdOpS3.opkind = "sub"
M8 = ErgmModel()
M8.init()
tdE8 = ErgmTermData()
M8.addterm("edges", 1, &stat_edges(), &change_edges(), tdE8, ("edges"))
M8.addterm("op:sub", 2, &stat_op(), &change_op(), tdOpS3, ("S~Sym~edges", "S~Sym~triangle"))
d = ot_check_mple(M8, GD)
printf("  S(Symmetrize): MPLE design max difference %g\n", d)
assert(d < 1e-9)
d = ot_check_mcmc(M8, GD, 40)
printf("  S(Symmetrize): MCMC max difference %g\n", d)
assert(d < 1e-9)
// Sum over a formula containing F
tdOpF3 = ErgmTermData()
tdOpF3.opsub = (&MA)
tdOpF3.opfilter = &MF
tdOpF3.opnum = (0, 0)
tdOpF3.opkind = "filter"
MF3 = ErgmModel()
MF3.init()
MF3.addterm("op:filter", 3, &stat_op(), &change_op(), tdOpF3, ("F~edges", "F~triangle", "F~nodematch"))
tdOpSF = ErgmTermData()
tdOpSF.opsub = (&MF3, &MA)
tdOpSF.opW = (I(3), 3 * I(3))
tdOpSF.opdims = (3, 3)
tdOpSF.opkind = "sum"
M9 = ErgmModel()
M9.init()
tdE9 = ErgmTermData()
M9.addterm("edges", 1, &stat_edges(), &change_edges(), tdE9, ("edges"))
M9.addterm("op:sum", 3, &stat_op(), &change_op(), tdOpSF, ("Sum~a", "Sum~b", "Sum~c"))
d = ot_check_mple(M9, GU)
printf("  Sum(F, plain): MPLE design max difference %g\n", d)
assert(d < 1e-9)
d = ot_check_mcmc(M9, GU, 40)
printf("  Sum(F, plain): MCMC max difference %g\n", d)
assert(d < 1e-9)
end
di "test_nwergm_ops_native: ALL OK"

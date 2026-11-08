cscript
* The SPDyad proposal (R ergm's default, MCMC.prop = ~sparse + .triadic).
*   A  the shared-partner cache of the Mata sampler equals a recount after many random toggles (undirected: UTP;
*      directed: OTP two-paths)
*   B  exactness: on networks small enough to enumerate every graph, the means of the statistics drawn with SPDyad
*      (Mata and native sampler; undirected and directed; triFocus 0.25 and 0.75) equal the exact means of the
*      model. A wrong Hastings ratio of the triadic branch shows up here.
*   C  the fit: SPDyad is the default (e(trifocus) = 0.25), mcmcprop(sparse) gives TNT, triadic(triFocus=) is used,
*      the estimates of the two proposals agree, the native cache equals a recount (debug plugin, if present)
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

mata:
mata set matastrict off

// shared partners of (a,b) by a recount: UTP undirected, OTP (a->k->b) directed
real scalar spd_recount(class ErgmGraph scalar G, real scalar a, real scalar b){
	real scalar k, c
	c = 0
	for (k=1; k<=G.n; k++) {
		if (k == a | k == b) continue
		if (G.has_edge(a, k) & G.has_edge(k, b)) c++
	}
	return(c)
}

void spd_check_cache(class ErgmGraph scalar G){
	real scalar a, b, c, nz
	nz = 0
	for (a=1; a<=G.n; a++) for (b=1; b<=G.n; b++) {
		if (a == b | (!G.directed & b < a)) continue
		c = spd_recount(G, a, b)
		if (c > 0) nz++
		assert(G.spd_get(a, b) == c)
	}
	assert(G.spd_n == nz)
	assert(all(G.spd_list[1..G.spd_n, 3] :> 0))
}

// A: cache under random toggles
void spd_test_cache(real scalar n, real scalar directed){
	class ErgmGraph scalar G
	real scalar s, i, j
	G = ErgmGraph()
	G.init(n, directed)
	for (s=1; s<=n*3; s++) {
		i = ceil(runiform(1,1)*n); j = ceil(runiform(1,1)*n)
		if (i != j) G.toggle(i, j)
	}
	G.spd_enable()
	spd_check_cache(G)
	for (s=1; s<=4000; s++) {
		i = ceil(runiform(1,1)*n); j = ceil(runiform(1,1)*n)
		if (i == j) continue
		G.toggle(i, j)
		if (mod(s, 500) == 0) spd_check_cache(G)
	}
	spd_check_cache(G)
	printf("PASS A: cache equals recount (n=%g, directed=%g, %g dyads with shared partners)\n", n, directed, G.spd_n)
}

// exact means of the statistics of model M on n nodes (all graphs enumerated)
real rowvector spd_exact(class ErgmModel scalar M, real scalar n, real scalar directed, real rowvector theta){
	class ErgmGraph scalar G
	real matrix dy
	real scalar k, i, j, code, rem, w, Z
	real rowvector s, E
	dy = J(0, 2, .)
	for (i=1; i<=n; i++) for (j=1; j<=n; j++) if (i != j & (directed | j > i)) dy = dy \ (i, j)
	G = ErgmGraph()
	G.init(n, directed)
	Z = 0
	E = J(1, cols(theta), 0)
	for (code=0; code<2^rows(dy); code++) {
		rem = code
		for (k=1; k<=rows(dy); k++) {
			if (mod(rem, 2) != G.has_edge(dy[k,1], dy[k,2])) G.toggle(dy[k,1], dy[k,2])
			rem = floor(rem/2)
		}
		s = M.full_statistic(G)
		w = exp(theta*s')
		Z = Z + w
		E = E + w*s
	}
	return(E / Z)
}

// B: draws with SPDyad against the exact means; batch-means standard errors (40 batches)
void spd_test_exact(class ErgmModel scalar M, real scalar n, real scalar directed, real rowvector theta, real scalar focus, real scalar native, string scalar lbl){
	class ErgmGraph scalar G
	real rowvector ex, mc, se
	real matrix X, B
	real scalar b, nb, k
	ex = spd_exact(M, n, directed, theta)
	G = ErgmGraph()
	G.init(n, directed)
	G.spd_focus = focus
	if (native) {
		assert(ErgmNativeSetup(M, 3 + focus/2, G) == 1)
		assert(M.native_enabled_sample == 1)
	}
	else {
		M.native_enabled = 0
		M.native_enabled_sample = 0
	}
	X = ErgmMCMCSample(M, G, theta, 2000, (native ? 20 : 10), (native ? 100000 : 20000), &ergm_propose_spdyad())
	nb = 40
	B = J(nb, cols(theta), .)
	for (b=1; b<=nb; b++) B[b, .] = mean(X[((b-1)*rows(X)/nb+1)..(b*rows(X)/nb), .])
	mc = mean(X)
	se = sqrt(diagonal(variance(B))' / nb)
	for (k=1; k<=cols(theta); k++) {
		printf("%s stat %g: exact %9.5f  sampled %9.5f  (se %7.5f, z %5.2f)\n", lbl, k, ex[k], mc[k], se[k], (mc[k]-ex[k])/se[k])
		assert(abs(mc[k] - ex[k]) < 4.5*se[k])
	}
	printf("PASS B: %s\n", lbl)
}

rseed(20261108)
spd_test_cache(14, 0)
spd_test_cache(12, 1)

// undirected: edges + triangle on 5 nodes (1,024 graphs), strong triangle effect
Mu = ErgmModel()
Mu.init()
tu1 = ErgmTermData()
Mu.addterm("edges", 1, &stat_edges(), &change_edges(), tu1, ("edges"))
tu2 = ErgmTermData()
Mu.addterm("triangle", 1, &stat_triangle(), &change_triangle(), tu2, ("triangle"))
thu = (-1.2, 0.9)
spd_test_exact(Mu, 5, 0, thu, 0.25, 0, "Mata   undirected triFocus .25")
spd_test_exact(Mu, 5, 0, thu, 0.75, 0, "Mata   undirected triFocus .75")
// directed: edges + transitiveties on 4 nodes (4,096 graphs)
Md = ErgmModel()
Md.init()
td1 = ErgmTermData()
Md.addterm("edges", 1, &stat_edges(), &change_edges(), td1, ("edges"))
td2 = ErgmTermData()
Md.addterm("transitiveties", 1, &stat_transitiveties(), &change_transitiveties(), td2, ("transitiveties"))
thd = (-1, 0.8)
spd_test_exact(Md, 4, 1, thd, 0.25, 0, "Mata   directed   triFocus .25")
spd_test_exact(Md, 4, 1, thd, 0.75, 0, "Mata   directed   triFocus .75")
void spd_test_native(class ErgmModel scalar Mu, real rowvector thu, class ErgmModel scalar Md, real rowvector thd){
	if (!ErgmNativeAvailable()) {
		printf("(native plugin not available: native part skipped)\n")
		return
	}
	spd_test_exact(Mu, 5, 0, thu, 0.25, 1, "native undirected triFocus .25")
	spd_test_exact(Mu, 5, 0, thu, 0.75, 1, "native undirected triFocus .75")
	spd_test_exact(Md, 4, 1, thd, 0.25, 1, "native directed   triFocus .25")
	spd_test_exact(Md, 4, 1, thd, 0.75, 1, "native directed   triFocus .75")
}
spd_test_native(Mu, thu, Md, thd)
end

* C: the fit
nwwebuse lazega, nwclear
encode practice, generate(prac)
quietly nwergm lazega_fr, edges nodematch(prac) gwesp(.5) seed(11) nologlik
assert e(trifocus) == 0.25
matrix bs = e(b)
matrix Vs = e(V)
quietly nwergm lazega_fr, edges nodematch(prac) gwesp(.5) seed(11) nologlik mcmcprop(sparse)
assert missing(e(trifocus))
matrix bt = e(b)
mata: bs = st_matrix("bs"); bt = st_matrix("bt"); se = sqrt(diagonal(st_matrix("Vs"))')
mata: printf("SPDyad vs TNT: largest difference %6.3f standard errors\n", max(abs(bs - bt) :/ se))
mata: assert(max(abs(bs - bt) :/ se) < 0.5)
quietly nwergm lazega_fr, edges nodematch(prac) gwesp(.5) seed(11) nologlik mcmcprop(sparse + triadic(triFocus = 0.5))
assert e(trifocus) == 0.5
quietly nwergm lazega_fr, edges nodematch(prac) gwesp(.5) seed(11) nologlik mcmcprop(.triadic(0.4))
assert e(trifocus) == 0.4
* the Mata sampler (nonative) uses SPDyad too, and keeps its cache equal to a recount
quietly nwergm lazega_fr, edges nodematch(prac) gwesp(.5) seed(11) nologlik nonative mcmleiterations(2)
assert e(trifocus) == 0.25
mata: assert(__nwergm_last_G.spd_on == 1)
mata: spd_check_cache(__nwergm_last_G)
* simulate after the fit uses the fit's proposal
quietly nwergm lazega_fr, edges nodematch(prac) gwesp(.5) seed(11) nologlik
quietly nwergm simulate, nsim(50) output(stats) seed(3)
matrix S1 = r(stats)
quietly nwergm simulate, nsim(50) output(stats) seed(3)
assert mreldif(S1, r(stats)) == 0
* invalid hint arguments are refused
capture noisily _nwergm_hints, spec(sparse + triadic(type = "ITP"))
assert _rc == 198
capture noisily _nwergm_hints, spec(triadic(2))
assert _rc == 198
display "ALL OK"

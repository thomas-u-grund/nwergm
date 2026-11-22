cscript

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

* nwergm simulate draws with the native plugin whenever it supports the model (nonative: the Mata sampler). Both samplers must
* draw from the exact distribution: 5 nodes, edges + triangle (all 1024 graphs enumerated), chi-square of the joint
* (edges, triangles) distribution of 600 independent draws against the exact probabilities (cells with expectation < 5 pooled).
* A model the plugin does not support (more than 64 attribute columns) stays on the Mata sampler and runs.

mata:
real matrix sn_exact(real rowvector theta)
{
	real scalar g, b, i, j, k, nd, e, t
	real matrix A, ST, I, U
	real colvector w, p
	I = J(0, 2, .)
	for (i=1; i<=5; i++) {
		for (j=i+1; j<=5; j++) I = I \ (i, j)
	}
	nd = rows(I)
	ST = J(2^nd, 2, .)
	for (g=0; g<2^nd; g++) {
		A = J(5, 5, 0)
		for (b=1; b<=nd; b++) {
			if (floor(g/2^(b-1)) - 2*floor(g/2^b)) {
				A[I[b,1], I[b,2]] = 1
				A[I[b,2], I[b,1]] = 1
			}
		}
		ST[g+1, .] = (sum(A)/2, trace(A*A*A)/6)
	}
	w = exp(ST*theta')
	w = w / sum(w)
	U = uniqrows(ST)
	p = J(rows(U), 1, 0)
	for (k=1; k<=rows(U); k++) p[k] = sum(select(w, (ST[,1]:==U[k,1]) :& (ST[,2]:==U[k,2])))
	return((U, p))
}
real scalar sn_chi2p(real matrix R, real matrix D)
{
	real scalar N, t, ex, ob, cx, co, chi, df
	N = rows(R); chi = 0; df = 0; cx = 0; co = 0
	for (t=1; t<=rows(D); t++) {
		ex = N*D[t,3]
		ob = sum((R[,1]:==D[t,1]) :& (R[,2]:==D[t,2]))
		if (ex < 5) {
			cx = cx + ex
			co = co + ob
		}
		else {
			chi = chi + (ob-ex)^2/ex
			df = df + 1
		}
	}
	if (cx >= 1) {
		chi = chi + (co-cx)^2/cx
		df = df + 1
	}
	return(chi2tail(df-1, chi))
}
end

mata: SN_D = sn_exact((-0.5, 0.4))
foreach opt in "" "nonative" {
	mata: SN_R = J(0, 2, .)
	forvalues b = 1/12 {
		quietly nwergm simulate 5, edges triangle theta(-0.5 0.4) nsim(50) mcmcburnin(2000) mcmcinterval(100) seed(`=700+`b'') generate(sx) `opt'
		forvalues i = 1/50 {
			quietly nwtomata sx_`i', mat(SN_A)
			mata: SN_A = editmissing(SN_A, 0); SN_R = SN_R \ (sum(SN_A)/2, trace(SN_A*SN_A*SN_A)/6)
		}
		quietly nwdrop sx_*
	}
	mata: st_numscalar("sn_p", sn_chi2p(SN_R, SN_D))
	di "chi-square p-value (`opt') = " scalar(sn_p)
	assert scalar(sn_p) > 0.001
	di "PASS simulate draws from the exact distribution (edges triangle, 5 nodes) `opt'"
}

* the same seed gives the same networks, with either sampler
foreach opt in "" "nonative" {
	quietly nwergm simulate 12, edges gwesp(.5) theta(-2 0.3) nsim(2) mcmcburnin(500) mcmcinterval(50) seed(9) generate(ra) `opt'
	quietly nwergm simulate 12, edges gwesp(.5) theta(-2 0.3) nsim(2) mcmcburnin(500) mcmcinterval(50) seed(9) generate(rb) `opt'
	forvalues i = 1/2 {
		quietly nwtomata ra_`i', mat(SN_A)
		quietly nwtomata rb_`i', mat(SN_B)
		mata: assert(all(editmissing(SN_A, 0) :== editmissing(SN_B, 0)))
	}
	quietly nwdrop ra_* rb_*
	di "PASS simulate reproduces a seed `opt'"
}

* a model the plugin does not support (66 attribute columns, the plugin takes 64) stays on the Mata sampler
clear
quietly set obs 12
local vl
local th "-1"
forvalues k=1/66 {
	quietly gen double v`k' = mod(_n*`k', 7)
	local vl "`vl' v`k'"
	local th "`th' 0.001"
}
quietly nwergm simulate 12, edges nodecov(`vl') theta(`th') nsim(2) mcmcburnin(500) mcmcinterval(50) seed(3) generate(sh)
quietly nwsummarize sh_2
assert r(nodes) == 12
di "PASS simulate of a model the plugin does not support runs on the Mata sampler"
di "ALL OK test_nwergm_simnative"

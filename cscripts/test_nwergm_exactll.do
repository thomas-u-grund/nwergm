cscript

* Option exactll: the exact log-likelihood of a model without dyad-dependent terms (and of a directed model with mutual), at the estimate.
* Gold standard: the model's own definition, ll = theta'g(y) - log sum over ALL graphs y of exp(theta'g(y)), by full enumeration on 4 nodes.

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

capture program drop _rcof
program _rcof
	args cmd rc
	capture `cmd'
	if _rc != `rc' {
		di as err "FAIL: `cmd' gave r(" _rc ") not r(`rc')"
		exit 9
	}
end

* full enumeration: log-likelihood of edges (+ mutual) (+ nodematch) at theta for the 4-node network A with attribute g
mata:
real scalar enum_ll(real matrix A, real colvector g, real rowvector th, real scalar directed, real scalar usemut)
{
	real scalar n, nd, k, s, lz, obs, m, i, j, e, mu, nm, c
	real matrix pairs, Y
	real colvector w
	n = rows(A)
	pairs = J(0, 2, .)
	for (i=1; i<=n; i++) for (j=1; j<=n; j++) if (i != j & (directed | i < j)) pairs = pairs \ (i, j)
	nd = rows(pairs)
	w = J(2^nd, 1, 0)
	for (k=0; k<2^nd; k++) {
		Y = J(n, n, 0)
		for (m=1; m<=nd; m++) {
			if (floor(k / 2^(m-1)) - 2*floor(k / 2^m) == 1) {
				Y[pairs[m,1], pairs[m,2]] = 1
				if (!directed) Y[pairs[m,2], pairs[m,1]] = 1
			}
		}
		e = 0; mu = 0; nm = 0
		for (m=1; m<=nd; m++) {
			i = pairs[m,1]; j = pairs[m,2]
			e = e + Y[i,j]
			nm = nm + Y[i,j] * (g[i] == g[j])
			if (directed & i < j) mu = mu + Y[i,j] * Y[j,i]
		}
		if (usemut) s = th[1]*e + th[2]*mu + th[3]*nm
		else s = th[1]*e + th[2]*nm
		w[k+1] = s
		if (k == 0) obs = 0
		if (A == Y) obs = s
	}
	lz = max(w) + ln(sum(exp(w :- max(w))))
	return(obs - lz)
}
end

* 1. directed, 4 nodes: dyad-independent (edges nodematch) and with mutual (pseudolikelihood estimate, exact value at it)
clear
set obs 4
gen g = (_n <= 2)
matrix A = (0,1,1,0 \ 1,0,0,1 \ 0,1,0,1 \ 0,0,1,0)
nwclear
nwset, mat(A) name(d4)
clear
set obs 4
gen g = (_n <= 2)
qui nwergm d4, edges nodematch(g)
mata: st_numscalar("ll_enum", enum_ll(st_matrix("A"), st_data(., "g"), st_matrix("e(b)"), 1, 0))
assert reldif(e(ll), scalar(ll_enum)) < 1e-10
local ll_default = e(ll)
qui nwergm d4, edges nodematch(g) exactll
assert reldif(e(ll), scalar(ll_enum)) < 1e-10
assert e(ll_method) == "exact" & e(exactll) == 1 & e(ll_se) == 0
assert reldif(e(aic), -2*e(ll) + 2*2) < 1e-12
assert reldif(e(bic), -2*e(ll) + ln(12)*2) < 1e-12
qui nwergm d4, edges mutual nodematch(g) method(mple)
mata: st_numscalar("ll_enum", enum_ll(st_matrix("A"), st_data(., "g"), st_matrix("e(b)"), 1, 1))
assert e(ll_method) == "pseudolikelihood"
qui nwergm d4, edges mutual nodematch(g) method(mple) exactll
assert reldif(e(ll), scalar(ll_enum)) < 1e-10
assert e(ll_method) == "exact" & e(exactll) == 1 & e(ll_se) == 0
assert e(df_m) == 3 & reldif(e(aic), -2*e(ll) + 6) < 1e-12
* replay prints the note
tempfile lg
log using `lg', text replace name(tl)
nwergm
log close tl
qui filefilter `lg' `lg'.txt, from("Exact log-likelihood") to("Exact log-likelihood") replace
assert r(occurrences) == 1

* 2. undirected, 4 nodes
matrix B = (0,1,1,0 \ 1,0,0,1 \ 1,0,0,1 \ 0,1,1,0)
nwclear
nwset, mat(B) undirected name(u4)
clear
set obs 4
gen g = (_n <= 2)
qui nwergm u4, edges nodematch(g)
qui nwergm u4, edges nodematch(g) exactll
mata: st_numscalar("ll_enum", enum_ll(st_matrix("B"), st_data(., "g"), st_matrix("e(b)"), 0, 0))
assert reldif(e(ll), scalar(ll_enum)) < 1e-10

* 3. Lazega, 71 nodes: the exact value against the pair-by-pair sum written out term by term
nwuse `"`nwcore'/data/lazega"', nwclear
qui nwergm lazega_adv, edges mutual nodematch(office) seed(11) mcll
local ll_mc = e(ll)
local se_mc = e(ll_se)
assert e(ll_method) == "bridge sampling"
assert `se_mc' > 0.1 & `se_mc' < 1.5
* default: exact; option exactll: the same
qui nwergm lazega_adv, edges mutual nodematch(office) seed(11)
assert e(ll_method) == "exact" & e(ll_se) == 0 & e(exactll) == 1
scalar ll_def = e(ll)
qui nwergm lazega_adv, edges mutual nodematch(office) seed(11) exactll
assert e(ll_method) == "exact" & e(ll_se) == 0
assert e(ll) == scalar(ll_def)
assert abs(e(ll) - `ll_mc') < 6 * `se_mc' + 2
qui nwtomata lazega_adv, mat(Y)
mata:
o = st_sdata(., "office")
th = st_matrix("e(b)")
n = rows(Y)
ll = 0
for (i=1; i<n; i++) for (j=i+1; j<=n; j++) {
	m = (o[i] == o[j])
	a1 = th[1] + th[3]*m
	a2 = a1
	a12 = a1 + a2 + th[2]
	ll = ll + Y[i,j]*a1 + Y[j,i]*a2 + Y[i,j]*Y[j,i]*th[2] - ln(1 + exp(a1) + exp(a2) + exp(a12))
}
st_numscalar("ll_pairs", ll)
end
assert reldif(e(ll), scalar(ll_pairs)) < 1e-9

* 4. errors
_rcof "nwergm lazega_adv, edges mutual gwesp(0.5) exactll" 198
_rcof "nwergm lazega_adv, edges triangle exactll" 198
_rcof "nwergm lazega_adv, edges nodematch(office) exactll nologlik" 198

_rcof "nwergm lazega_adv, edges mutual nodematch(office) exactll mcll" 198
_rcof "nwergm lazega_adv, edges nodematch(office) method(mple) mcll" 198

* 5. a dyad-independent model: exact by default, the Monte Carlo value with mcll (method(mcmle) forced)
qui nwergm lazega_adv, edges nodematch(office) method(mcmle) seed(3)
assert e(ll_method) == "exact" & e(ll_se) == 0
local lx = e(ll)
qui nwergm lazega_adv, edges nodematch(office) method(mcmle) seed(3) mcll
assert e(ll_method) == "bridge sampling"
assert abs(e(ll) - `lx') < 8 * e(ll_se) + 1
* a dyad-dependent model keeps the bridge sampling value
set seed 7
mata: R = rdiscrete(14, 14, (0.7, 0.3)) :- 1; R = (R + R') :> 0; _diag(R, 0); st_matrix("R", R)
nwclear
nwset, mat(R) undirected name(r14)
qui nwergm r14, edges triangle seed(3) mcmcsamplesize(1000)
assert e(ll_method) == "bridge sampling" & e(ll_se) > 0
nwuse `"`nwcore'/data/lazega"', nwclear
* method(mple) of a dyad-independent model is unchanged
qui nwergm lazega_adv, edges nodematch(office)
assert e(ll_method) == "exact" & "`e(exactll)'" == ""
di "ALL OK test_nwergm_exactll"

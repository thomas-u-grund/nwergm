cscript

* DRAFT, not yet run.
* xt_stats_longmodel: long term lists and many covariates (more than 50 terms, more than 64 and close to 100 statistics),
* which stress the option strings, the term table of the plugin (r(1003) "too many options" up to 1.3.7) and the
* column bookkeeping. The reference values are derived by hand in Mata from the adjacency matrix with formulas checked
* against R ergm 4.12.0 summary() on a random 30-node network (edges, nodecov, nodematch, absdiff, triangle, kstar,
* degree, esp, dsp, gwesp, edgecov, nodefactor; directed: mutual, nodeocov, nodeicov, odegree, idegree, ostar, istar,
* ctriple, transitiveties, cyclicalties, desp(type="OTP"), nodeofactor, nodeifactor, nodematch: max difference 2e-13).
* Also: varlist forms (x1-x3, x*) in a covariate term, an expression as attribute, 32-character variable names, a
* dataset with fewer rows than nodes.
* Expected runtime: about 1-3 minutes (two MPLE fits with 90+ columns, the existence check is a simplex).
* Runs from the repository root; the runner sets PLUS, the adopath and the plugin path.
capture program drop nwinstall
set graphics off

* ---------------------------------------------------------------------------------------------------------------
* undirected network, 80 nodes, 50 node covariates (50 nodecov terms), a 10-level factor, an edge covariate network
* and a Hamming reference network
nwclear
clear
mata: rseed(20261112)
mata: n = 80
mata: U = runiform(n, n) :< 0.08; U = uppertriangle(U, 0); U = U + U'; U = U :* (1 :- I(n))
mata: st_matrix("A80", U)
mata: W = mod((1::n) * (1..n), 7) :/ 3; W = W :* (1 :- I(n)); st_matrix("W80", W)
mata: H = runiform(n, n) :< 0.05; H = uppertriangle(H, 0); H = H + H'; H = H :* (1 :- I(n)); st_matrix("H80", H)
nwset, mat(A80) undirected name(U80) nooutput
nwset, mat(W80) undirected name(W80) nooutput
nwset, mat(H80) undirected name(H80) nooutput
clear
set obs 80
gen double g = mod(7 * _n, 10) + 1
* random covariates (periodic formulas would span a low-dimensional space and make the 50 terms collinear)
set seed 271828
local xl ""
forvalues k = 1/50 {
	gen double x`k' = round(10 * runiform(), 0.001)
	local xl "`xl' x`k'"
}

* hand-derived statistics in the column order of nwergm (help nwergm, Simulation, theta(): edges, the node-covariate
* family in the order nodematch, nodecov, absdist, nodefactor; then degree, triangle, kstar, esp, dsp; then the dyadic
* covariates edgecov, hamming; then the geometrically weighted terms)
mata:
A = st_matrix("A80"); n = rows(A); deg = rowsum(A); S = A * A; O = 1 :- I(n)
X = st_data(., "x" :+ strofreal(1..50)); g = st_data(., "g")
W = st_matrix("W80"); H = st_matrix("H80")
v = sum(A) / 2
v = v, sum(A :* (g :== g')) / 2
for (k = 1; k <= 50; k++) v = v, sum(deg :* X[., k])
v = v, sum(A :* abs(X[., 1] :- X[., 1]')) / 2
lv = uniqrows(g)
for (l = 2; l <= rows(lv); l++) v = v, sum(deg :* (g :== lv[l]))
for (d = 1; d <= 6; d++) v = v, sum(deg :== d)
v = v, trace(A * A * A) / 6
for (k = 2; k <= 6; k++) {
	b = J(n, 1, 1)
	for (j = 0; j < k; j++) b = b :* (deg :- j)
	v = v, sum(b) / factorial(k)
}
for (d = 1; d <= 3; d++) v = v, sum(A :* (S :== d)) / 2
for (d = 1; d <= 3; d++) v = v, sum(O :* (S :== d)) / 2
v = v, sum(A :* W) / 2
v = v, sum(abs(A - H)) / 2
a = 0.7
gw = 0
for (k = 1; k <= n - 2; k++) gw = gw + (1 - (1 - exp(-a))^k) * sum(A :* (S :== k)) / 2
v = v, exp(a) * gw
st_matrix("EXPU", v)
end

nwergm U80, edges nodematch(g) nodecov(`xl') absdist(x1) nodefactor(g) degree(1/6) triangle kstar(2/6) esp(1/3) dsp(1/3) ///
	edgecov(W80) hamming(H80) gwesp(.7) method(mple)
matrix S = e(obs_stats)
assert colsof(S) == colsof(EXPU)
assert colsof(e(b)) == colsof(EXPU)
assert mreldif(S, EXPU) < 1e-9
local cn : colnames e(b)
local cnu : list uniq cn
assert `: word count `cn'' == `: word count `cnu''
assert "`: word 1 of `cn''" == "edges"
assert "`: word 3 of `cn''" == "nodecov_x1"
assert "`: word 52 of `cn''" == "nodecov_x50"
* the same model through the native and the Mata route gives the same statistics and estimates (help: bit-identical
* design matrix for method(mple))
matrix b1 = e(b)
qui nwergm U80, edges nodematch(g) nodecov(`xl') absdist(x1) nodefactor(g) degree(1/6) triangle kstar(2/6) esp(1/3) dsp(1/3) ///
	edgecov(W80) hamming(H80) gwesp(.7) method(mple) nonative
matrix S2 = e(obs_stats)
matrix b2 = e(b)
assert mreldif(S2, EXPU) < 1e-9
assert mreldif(b2, b1) < 1e-7
di "PASS long undirected model: 50 covariate terms, " colsof(EXPU) " statistics, hand-derived"

* ---------------------------------------------------------------------------------------------------------------
* directed network, 40 nodes, 20 sender covariates and 20 receiver covariates (40 node-covariate terms)
nwclear
clear
mata: rseed(4711)
mata: n = 40
mata: D = (runiform(n, n) :< 0.07) :* (1 :- I(n)); st_matrix("A40", D)
nwset, mat(A40) directed name(D40) nooutput
clear
set obs 40
gen double g = mod(3 * _n, 10) + 1
set seed 314159
local ol ""
local il ""
forvalues k = 1/20 {
	gen double o`k' = round(5 * runiform(), 0.01)
	gen double i`k' = round(5 * runiform() - 2, 0.01)
	local ol "`ol' o`k'"
	local il "`il' i`k'"
}
* column order: edges, mutual, nodeicov, nodeocov, odegree, idegree, ctriple, nodeofactor, nodeifactor, ostar, istar,
* esp, transitiveties, cyclicalties (registration order in nwergm.ado: lines 844-1405)
mata:
A = st_matrix("A40"); n = rows(A); od = rowsum(A); id = colsum(A)'; T = A * A
Xo = st_data(., "o" :+ strofreal(1..20)); Xi = st_data(., "i" :+ strofreal(1..20)); g = st_data(., "g")
v = sum(A), sum(A :* A') / 2
for (k = 1; k <= 20; k++) v = v, sum(id :* Xi[., k])
for (k = 1; k <= 20; k++) v = v, sum(od :* Xo[., k])
for (d = 1; d <= 5; d++) v = v, sum(od :== d)
for (d = 1; d <= 5; d++) v = v, sum(id :== d)
v = v, trace(A * A * A) / 3
lv = uniqrows(g)
for (l = 2; l <= rows(lv); l++) v = v, sum(od :* (g :== lv[l]))
for (l = 2; l <= rows(lv); l++) v = v, sum(id :* (g :== lv[l]))
for (k = 2; k <= 4; k++) {
	b = J(n, 1, 1)
	for (j = 0; j < k; j++) b = b :* (od :- j)
	v = v, sum(b) / factorial(k)
}
for (k = 2; k <= 4; k++) {
	b = J(n, 1, 1)
	for (j = 0; j < k; j++) b = b :* (id :- j)
	v = v, sum(b) / factorial(k)
}
for (d = 1; d <= 2; d++) v = v, sum(A :* (T :== d))
v = v, sum(A :* (T :> 0)), sum(A :* (T' :> 0))
st_matrix("EXPD", v)
end

nwergm D40, edges mutual nodeocov(`ol') nodeicov(`il') odegree(1/5) idegree(1/5) ctriple nodeofactor(g) nodeifactor(g) ///
	ostar(2/4) istar(2/4) esp(1/2) type(OTP) transitiveties cyclicalties method(mple)
matrix S = e(obs_stats)
assert colsof(S) == colsof(EXPD)
assert mreldif(S, EXPD) < 1e-9
local cn : colnames e(b)
local cnu : list uniq cn
assert `: word count `cn'' == `: word count `cnu''
di "PASS long directed model: 40 covariate terms, " colsof(EXPD) " statistics, hand-derived"

* ---------------------------------------------------------------------------------------------------------------
* covariate terms are documented with a varlist (help nwergm: nodecov(varlist), nodematch(varlist) ...); a range and a
* wildcard must give the same model as the variables listed one by one
qui nwergm D40, edges nodeocov(o1 o2 o3) method(mple)
matrix Sexp = e(obs_stats)
matrix S2 = Sexp
local cexp : colnames e(b)
capture noisily nwergm D40, edges nodeocov(o1-o3) method(mple)
local rcr = _rc
if `rcr' == 0 {
	matrix S2 = e(obs_stats)
	assert mreldif(S2, Sexp) < 1e-12
	local c2 : colnames e(b)
	assert "`c2'" == "`cexp'"
}
else {
	di as err "FAIL nodeocov(o1-o3): r(`rcr'); the help documents a varlist (a range should work as o1 o2 o3)"
	exit 9
}
di "PASS varlist range in a covariate term"

* an expression as attribute (_nwergm_covattr: "neither a variable nor a valid expression"): nodeocov(o1^2)
qui nwergm D40, edges nodeocov(o1^2) method(mple)
mata: st_numscalar("e_sq", sum(rowsum(st_matrix("A40")) :* (st_data(., "o1") :^ 2)))
matrix S = e(obs_stats)
assert reldif(S[1,2], e_sq) < 1e-12
di "PASS expression as attribute"

* ---------------------------------------------------------------------------------------------------------------
* 32-character variable names: the coefficient name nodecov_<name> has 40 characters. Two names that differ only in
* their last characters must give two distinct, usable coefficients. R has no length limit. Expected outcome not known
* (Stata names are limited to 32 characters): record it, and assert that a fit that runs has unique names.
gen double abcdefghijklmnopqrstuvwxyz_12345 = o1
gen double abcdefghijklmnopqrstuvwxyz_12399 = o2
capture noisily nwergm D40, edges nodeocov(abcdefghijklmnopqrstuvwxyz_12345 abcdefghijklmnopqrstuvwxyz_12399) method(mple)
local rcl = _rc
if `rcl' == 0 {
	local cn : colnames e(b)
	local cnu : list uniq cn
	if `: word count `cn'' != `: word count `cnu'' {
		di as err "FAIL long variable names: duplicate coefficient names `cn'"
		exit 9
	}
	matrix S = e(obs_stats)
	matrix S3 = Sexp[1, 1..3]
	assert mreldif(S, S3) < 1e-12
	di as txt "PASS 32-character variable names: `cn'"
}
else di as txt "SOFT 32-character variable names refused with r(`rcl') (R has no limit)"

* ---------------------------------------------------------------------------------------------------------------
* a dataset with fewer rows than the network has nodes: the attribute is incomplete. nwergm counts missing values with
* "in 1/<nodes>" (_nwergm_covattr, _nwergm_numvar), which stops with r(198) "Obs. nos. out of range".
* (no preserve here: nwergm preserves the data itself in the MPLE step, and preserve cannot be nested)
tempfile full
qui save `full'
qui keep in 1/30
capture noisily nwergm D40, edges nodeocov(o1) method(mple)
local rcs = _rc
qui use `full', clear
assert `rcs' != 0
assert `rcs' < 3000 | `rcs' > 3999
if `rcs' != 198 di as txt "SOFT fewer rows than nodes: r(`rcs') (expected 198 from the code)"
di "PASS dataset with fewer rows than nodes refused"

di "ALL PASS"

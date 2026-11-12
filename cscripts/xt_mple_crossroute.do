cscript

* DRAFT, not yet run.
* xt_mple_crossroute: the maximum pseudolikelihood estimate by three independent routes:
*   (a) nwergm ..., method(mple);
*   (b) Stata's logit on change statistics built by hand in Mata (formulas in the comments; no nwergm code involved);
*   (c) R ergm 4.12.0 ergm(..., estimate = "MPLE") on the same networks.
* Plus: exact MLE of the edges-only model (closed form), estat ic arithmetic, offset() with method(mple) against R and
* against logit with an offset, a missing dyad, and the dyad-independent default (MPLE = MLE).
* Expected runtime: about 30 seconds.
* Runs from the repository root; the runner sets PLUS, the adopath and the plugin path.
capture program drop nwinstall
set graphics off

* ---------------------------------------------------------------------------------------------------------------
* U14: 14 nodes, 27 ties, g = 1 2 1 2 ... (R: set.seed(4242); A[upper.tri(A)] <- rbinom(91, 1, 0.3); g <- rep(1:2, 7))
* D12: 12 nodes, 28 arcs, x = (1:12) %% 4 (R: set.seed(777); Ad <- matrix(rbinom(144, 1, 0.2), 12, 12); diag(Ad) <- 0)
nwclear
clear
mata: ui = (1,2,3,1,4,4,5,1,6,1,5,1,6,7,9,10,4,7,10,2,5,6,10,11,2,7,10)
mata: uj = (2,4,4,5,5,6,6,7,8,9,9,10,11,11,11,11,12,12,12,13,13,13,13,13,14,14,14)
mata: A = J(14, 14, 0)
mata: for (k = 1; k <= 27; k++) A[ui[k], uj[k]] = 1
mata: A = A + A'
mata: st_matrix("AU14", A)
mata: Am = A; Am[1,3] = .; Am[3,1] = .; st_matrix("AU14m", Am)
mata: dt = (4,9,3,6,5,7,9,10,11,12,1,10,3,5,9,1,4,6,10,12,3,4,5,10,4,12,9,9)
mata: dh = (1,1,2,2,3,3,3,4,4,4,5,5,6,6,6,7,7,8,8,8,9,9,9,9,10,10,11,12)
mata: B = J(12, 12, 0)
mata: for (k = 1; k <= 28; k++) B[dt[k], dh[k]] = 1
mata: st_matrix("AD12", B)
nwset, mat(AU14) undirected name(U14) nooutput
nwset, mat(AU14m) undirected name(U14m) nooutput
nwset, mat(AD12) directed name(D12) nooutput
clear
set obs 14
gen double g = mod(_n - 1, 2) + 1
gen double x = mod(_n, 4)
gen double z = _n / 3

* ---------------------------------------------------------------------------------------------------------------
* (a) and (c): undirected dyad-dependent model
* R: fit <- ergm(nw ~ edges + triangle + nodematch("g") + kstar(2), estimate = "MPLE")
*    coef: -1.348242488325 -1.014497785416 0.408268883587 0.162400647576
*    se:    1.125369743914  0.403228298648 0.487556507979 0.177886332350;  summary(): 27 5 15 91
* nwergm column order: edges nodematch_g triangle kstar_2
nwergm U14, edges triangle nodematch(g) kstar(2) method(mple)
assert "`e(method)'" == "mple"
assert e(N) == 91 & e(ties) == 27 & e(nodes) == 14
matrix bU = e(b)
matrix VU = e(V)
matrix SU = e(obs_stats)
matrix R_b = (-1.348242488325, 0.408268883587, -1.014497785416, 0.162400647576)
matrix R_se = (1.125369743914, 0.487556507979, 0.403228298648, 0.177886332350)
matrix R_s = (27, 15, 5, 91)
assert mreldif(SU, R_s) < 1e-12
forvalues j = 1/4 {
	assert abs(bU[1,`j'] - R_b[1,`j']) < 1e-6
	assert abs(sqrt(VU[`j',`j']) - R_se[1,`j']) < 1e-5
}
local llU = e(ll)
di "PASS U14 MPLE = R ergm(estimate = MPLE)"

* (b): logit on hand-built change statistics. For dyad i<j: d_edges = 1, d_nodematch = (g_i == g_j),
* d_triangle = number of common neighbours, d_kstar2 = (deg_i - A_ij) + (deg_j - A_ij).
preserve
mata: g = st_data(., "g"); A = st_matrix("AU14"); n = 14; deg = rowsum(A); S = A * A
mata: R = J(0, 5, .)
mata: for (i = 1; i < n; i++) for (j = i + 1; j <= n; j++) R = R \ (A[i,j], 1, g[i] == g[j], S[i,j], deg[i] + deg[j] - 2 * A[i,j])
clear
mata: st_addobs(rows(R)); (void) st_addvar("double", ("y", "c1", "c2", "c3", "c4")); st_store(., ("y", "c1", "c2", "c3", "c4"), R)
logit y c1 c2 c3 c4, noconstant tolerance(1e-9) ltolerance(1e-11)
matrix bL = e(b)
matrix VL = e(V)
local llL = e(ll)
restore
forvalues j = 1/4 {
	assert abs(bU[1,`j'] - bL[1,`j']) < 1e-7
	assert abs(sqrt(VU[`j',`j']) - sqrt(VL[`j',`j'])) < 1e-6
}
assert reldif(`llU', `llL') < 1e-9
di "PASS U14 MPLE = logit on hand-built change statistics (coefficients, SE, pseudolikelihood)"

* estat ic: r(S) = N, ll(null), ll(model), df, AIC, BIC (help nwergm_fit); null model = all coefficients 0 = N ln(1/2)
qui nwergm U14, edges triangle nodematch(g) kstar(2) method(mple)
estat ic
matrix IC = r(S)
assert IC[1,1] == 91
assert reldif(IC[1,2], 91 * ln(0.5)) < 1e-12
assert reldif(IC[1,3], `llL') < 1e-9
assert IC[1,4] == 4
assert reldif(IC[1,5], -2 * `llL' + 2 * 4) < 1e-9
assert reldif(IC[1,6], -2 * `llL' + ln(91) * 4) < 1e-9
assert e(df_m) == 4
assert reldif(e(aic), IC[1,5]) < 1e-12
di "PASS estat ic arithmetic"

* ---------------------------------------------------------------------------------------------------------------
* geometrically weighted terms. R: ergm(nw ~ edges + gwesp(0.5, fixed=TRUE) + gwdegree(0.7, fixed=TRUE), estimate="MPLE")
*    coef 0.856384509516 -0.509091510377 -2.587834299543; se 0.625182570126 0.166368831987 1.325454724180
*    summary(): 27 13.1804080208621 24.6798740272680
nwergm U14, edges gwesp(.5) gwdegree(.7) method(mple)
matrix b = e(b)
matrix V = e(V)
matrix S = e(obs_stats)
matrix R_b = (0.856384509516, -0.509091510377, -2.587834299543)
matrix R_se = (0.625182570126, 0.166368831987, 1.325454724180)
matrix R_s = (27, 13.1804080208621, 24.6798740272680)
assert mreldif(S, R_s) < 1e-10
forvalues j = 1/3 {
	assert abs(b[1,`j'] - R_b[1,`j']) < 1e-5
	assert abs(sqrt(V[`j',`j']) - R_se[1,`j']) < 1e-5
}
di "PASS U14 gw MPLE = R"

* ---------------------------------------------------------------------------------------------------------------
* directed. R: ergm(nd ~ edges + mutual + nodeicov("x") + ctriple, estimate = "MPLE")
*    coef -0.916184337035 -0.603072131085 -0.110585521275 -0.254662903113
*    se    0.414288633995  0.590660128232  0.193354094184  0.337735142312;  summary(): 28 2 40 4
nwergm D12, edges mutual nodeicov(x) ctriple method(mple)
assert e(N) == 132 & e(ties) == 28
matrix bD = e(b)
matrix VD = e(V)
matrix SD = e(obs_stats)
matrix R_b = (-0.916184337035, -0.603072131085, -0.110585521275, -0.254662903113)
matrix R_se = (0.414288633995, 0.590660128232, 0.193354094184, 0.337735142312)
matrix R_s = (28, 2, 40, 4)
assert mreldif(SD, R_s) < 1e-12
forvalues j = 1/4 {
	assert abs(bD[1,`j'] - R_b[1,`j']) < 1e-6
	assert abs(sqrt(VD[`j',`j']) - R_se[1,`j']) < 1e-5
}
* logit by hand: ordered pair i->j: d_edges = 1, d_mutual = A_ji, d_nodeicov = x_j, d_ctriple = sum_k A_jk A_ki = (A*A)_ji
preserve
mata: x = st_data(1::12, "x"); A = st_matrix("AD12"); n = 12; T = A * A
mata: R = J(0, 5, .)
mata: for (i = 1; i <= n; i++) for (j = 1; j <= n; j++) if (i != j) R = R \ (A[i,j], 1, A[j,i], x[j], T[j,i])
clear
mata: st_addobs(rows(R)); (void) st_addvar("double", ("y", "c1", "c2", "c3", "c4")); st_store(., ("y", "c1", "c2", "c3", "c4"), R)
logit y c1 c2 c3 c4, noconstant tolerance(1e-9) ltolerance(1e-11)
matrix bL = e(b)
restore
forvalues j = 1/4 {
	assert abs(bD[1,`j'] - bL[1,`j']) < 1e-7
}
di "PASS D12 MPLE = R = logit on hand-built change statistics"

* ---------------------------------------------------------------------------------------------------------------
* offset() with method(mple). R: ergm(nw ~ edges + offset(triangle) + nodematch("g"), estimate = "MPLE", offset.coef = 0.3)
*    edges -1.47770949178 (se 0.335069205556), nodematch.g 0.61477336546 (se 0.467063010434), triangle 0.3 (se 0)
nwergm U14, edges triangle nodematch(g) offset(triangle 0.3) method(mple)
matrix b = e(b)
matrix V = e(V)
local jt = colnumb(b, "triangle")
local jn = colnumb(b, "nodematch_g")
local je = colnumb(b, "edges")
assert b[1,`jt'] == 0.3
forvalues j = 1/3 {
	assert V[`jt',`j'] == 0 & V[`j',`jt'] == 0
}
assert abs(b[1,`je'] - (-1.47770949178)) < 1e-6
assert abs(b[1,`jn'] - 0.61477336546) < 1e-6
assert abs(sqrt(V[`je',`je']) - 0.335069205556) < 1e-5
assert abs(sqrt(V[`jn',`jn']) - 0.467063010434) < 1e-5
assert e(df_m) == 2
* the same by logit with an offset 0.3 * d_triangle
preserve
mata: g = st_data(., "g"); A = st_matrix("AU14"); n = 14; S = A * A
mata: R = J(0, 4, .)
mata: for (i = 1; i < n; i++) for (j = i + 1; j <= n; j++) R = R \ (A[i,j], 1, g[i] == g[j], 0.3 * S[i,j])
clear
mata: st_addobs(rows(R)); (void) st_addvar("double", ("y", "c1", "c2", "off")); st_store(., ("y", "c1", "c2", "off"), R)
logit y c1 c2, noconstant offset(off) tolerance(1e-9) ltolerance(1e-11)
matrix bL = e(b)
restore
assert abs(b[1,`je'] - bL[1,1]) < 1e-7
assert abs(b[1,`jn'] - bL[1,2]) < 1e-7
di "PASS offset() with MPLE = R = logit with offset"

* ---------------------------------------------------------------------------------------------------------------
* dyad-independent models: the default is MPLE, which is the MLE; edges alone has a closed form:
* b = ln(27/64) = -0.8630462173553427, se = 1/sqrt(91 p (1-p)) = 0.2294821061369209, ll = 27 ln p + 64 ln(1-p) = -55.33210237589748
nwergm U14, edges
assert "`e(method)'" == "mple"
assert abs(_b[edges] - ln(27/64)) < 1e-8
assert abs(_se[edges] - 0.2294821061369209) < 1e-7
assert abs(e(ll) - (-55.33210237589748)) < 1e-7
assert "`e(ll_method)'" == "exact"
* a dyad-independent model with covariates: MPLE = logit on the dyads = MLE (same numbers with method(mple))
qui nwergm U14, edges nodematch(g) nodecov(z)
matrix b1 = e(b)
qui nwergm U14, edges nodematch(g) nodecov(z) method(mple)
matrix b2 = e(b)
assert mreldif(b1, b2) < 1e-12
di "PASS dyad-independent default: MPLE = exact MLE"

* ---------------------------------------------------------------------------------------------------------------
* a missing dyad (1,3), a non-tie in U14: it is dropped from the likelihood (help nwergm_fit, Missing data)
* edges alone: b = ln(27/63)
nwergm U14m, edges
assert e(N) == 90
assert e(nmissing) == 1
assert e(ties) == 27
assert abs(_b[edges] - ln(27/63)) < 1e-8
di "PASS missing dyad dropped from the likelihood"

di "ALL PASS"

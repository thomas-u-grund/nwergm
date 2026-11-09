cscript
* ergm_spec0_mvar() (R's spectrum0.mvar(): the effective sample size, the burn-in test and the convergence test of MCMLE)
* computes its whole order search from one Whittle recursion (ergm_ar_yw_path()) and skips the pair counts of the
* autocovariances when there are no missing values. The result must be exactly that of the direct algorithm (one
* ar.yw() fit per order tried, as in R), kept below as reference code: same matrix, inflation, rank and return code,
* on series with collinear and constant columns, trends, ties, the NA padding of the burn-in test and short series.
local nwcore : env NWCORE
if `"`nwcore'"' == "" {
	di as error "set the environment variable NWCORE to the directory of the nwcommands (core) package"
	exit 198
}
adopath ++ `"`nwcore'"'
adopath ++ `"`c(pwd)'"'
quietly do `"`nwcore'/unw_core.do"'
do unw_ergm.do
mata:
mata set matastrict off
real matrix ref_acf_cov(real matrix X, real scalar lagmax){
	real scalar n, p, k, lag, m2, k2
	real matrix Z, Mk, S, N, out
	n = rows(X)
	p = cols(X)
	Z = X
	for (k=1; k<=p; k++) {
		m2 = mean(select(X[., k], X[., k] :< .))
		Z[., k] = X[., k] :- m2
	}
	Mk = (Z :< .)
	Z = editmissing(Z, 0)
	out = J((lagmax+1)*p, p, .)
	for (lag=0; lag<=lagmax; lag++) {
		S = Z[(lag+1)::n, .]' * Z[1::(n-lag), .]
		N = Mk[(lag+1)::n, .]' * Mk[1::(n-lag), .]
		out[(lag*p+1)::((lag+1)*p), .] = S :/ (N :+ lag)
		for (k=1; k<=p; k++) for (k2=1; k2<=p; k2++) if (N[k,k2] == 0) out[lag*p+k, k2] = .
	}
	return(out)
}

void ref_ar_yw(real matrix X, real scalar ordmax, real scalar useaic, real scalar ord, real matrix arsum,
	real matrix varpred, real rowvector xaic){
	real scalar n, nser, nobs, m, i, ld
	real matrix xacf, A, B, Aold, Bold, EA, EB, KA, KB, betaA, betaB, Im
	n = rows(X)
	nser = cols(X)
	nobs = sum(X[., 1] :< .)
	xacf = ref_acf_cov(X, ordmax)
	Im = I(nser)
	A = J((ordmax+1)*nser, nser, 0)
	B = A
	A[1::nser, .] = Im
	B[1::nser, .] = Im
	EA = xacf[1::nser, .]
	EB = EA
	xaic = J(1, ordmax+1, .)
	ord = 0
	arsum = J(nser, nser, 0)
	varpred = EA * nobs / (nobs - nser)
	for (m=0; m<=ordmax; m++) {
		ld = ln(abs(det(EA)))
		xaic[m+1] = nobs * ld + 2 * m * nser * nser
		if (!useaic | xaic[m+1] <= min(xaic[1..(m+1)])) {
			ord = m
			varpred = EA * nobs / (nobs - nser * (m + 1))
			arsum = J(nser, nser, 0)
			for (i=1; i<=m; i++) arsum = arsum - A[(i*nser+1)::((i+1)*nser), .]
		}
		if (m < ordmax) {
			betaA = J(nser, nser, 0)
			betaB = J(nser, nser, 0)
			for (i=0; i<=m; i++) {
				betaA = betaA + A[(i*nser+1)::((i+1)*nser), .] * xacf[((m+1-i)*nser+1)::((m+2-i)*nser), .]
				betaB = betaB + B[(i*nser+1)::((i+1)*nser), .] * xacf[((m+1-i)*nser+1)::((m+2-i)*nser), .]'
			}
			KA = -betaA * luinv(EB)
			KB = -betaB * luinv(EA)
			EB = (Im - KB * KA) * EB
			EA = (Im - KA * KB) * EA
			Aold = A
			Bold = B
			for (i=1; i<=m+1; i++) {
				A[(i*nser+1)::((i+1)*nser), .] = Aold[(i*nser+1)::((i+1)*nser), .] + KA * Bold[((m+1-i)*nser+1)::((m+2-i)*nser), .]
				B[(i*nser+1)::((i+1)*nser), .] = Bold[(i*nser+1)::((i+1)*nser), .] + KB * Aold[((m+1-i)*nser+1)::((m+2-i)*nser), .]
			}
		}
	}
	xaic = xaic :- min(xaic)
}

real matrix ref_spec0_mvar(real matrix Xfull, real scalar infl, real scalar rnk, | real scalar rc){
	real scalar p, pv, k, ord, tol, ordsel, i, j, ok, userc
	real matrix x, xf, evec, xr, unmapper, indvar, v, vvar, adj, arsum, varpred
	real rowvector xscl, ev, xrsd, xaic, d, keep, ind
	real colvector rows_ok
	real scalar ord_ar

	userc = (args() == 4)
	if (userc) rc = 0
	infl = .
	tol = sqrt(2.220446049250313e-16)
	p = cols(Xfull)
	rows_ok = (rowmissing(Xfull) :== 0)
	x = select(Xfull, rows_ok)
	v = J(p, p, 0)
	xscl = sqrt(diagonal(variance(x)))'
	keep = selectindex(xscl :>= tol)
	pv = cols(keep)
	if (pv == 0) {
		if (userc) {
			rc = 1
			return(J(p, p, .))
		}
		_error(3498, "All variables are constant.")
	}
	x = x[., keep]
	xf = Xfull[., keep]
	xscl = xscl[keep]
	x = x :/ xscl
	xf = xf :/ xscl
	symeigensystem(variance(x), evec, ev)
	xr = J(rows(xf), pv, .)
	for (k=1; k<=pv; k++) xr[., k] = (xf * evec[., k]) / sqrt(max((ev[k], 0)))
	xrsd = J(1, pv, .)
	for (k=1; k<=pv; k++) {
		d = select(xr[., k], xr[., k] :< .)
		xrsd[k] = (rows(d) > 1 ? sqrt(variance(d)) : .)
	}
	ind = selectindex((xrsd :< .) :& (abs(xrsd :- 1) :< tol))
	unmapper = diag(xscl) * evec[., ind] * diag(sqrt(ev[ind]))
	xr = xr[., ind]
	rnk = cols(ind)
	indvar = variance(select(xr, rowmissing(xr) :== 0))
	ord = ceil(10 * log10(rows(xr)))
	ok = 0
	ord = ord + 1
	while (!ok & ord > 0) {
		ord = ord - 1
		if (ord <= 0) {
			if (userc) {
				rc = 2
				return(J(p, p, .))
			}
			_error(3498, "Unable to fit ar() even with order 1; this is likely to be due to insufficient sample size or a trend in the data.")
		}
		ref_ar_yw(xr, ord, 1, ord_ar, arsum, varpred, xaic)
		ok = !hasmissing(varpred)
		if (ok) {
			symeigensystem(0.5 * (varpred + varpred'), evec, ev)
			if (min(ev) < 0) ok = 0
		}
	}
	// the AIC curve's first local minimum bounds the order
	d = (. , xaic, .)
	ordsel = -1
	for (i=2; i<=cols(d); i++) {
		if (d[i] >= d[i-1]) {
			ordsel = i - 2 - 1
			break
		}
	}
	if (ord_ar > ordsel) {
		ref_ar_yw(xr, max((ordsel, 1)), (ordsel == 0), ord_ar, arsum, varpred, xaic)
	}
	adj = I(cols(xr)) - arsum
	vvar = luinv(adj) * varpred * luinv(adj)'
	infl = exp((ln(det(vvar)) - ln(det(indvar))) / cols(indvar))
	if (userc & infl >= .) {
		rc = 3
		return(J(p, p, .))
	}
	vvar = unmapper * vvar * unmapper'
	for (i=1; i<=pv; i++) for (j=1; j<=pv; j++) v[keep[i], keep[j]] = vvar[i, j]
	return(v)
}


real scalar spc_same(real matrix a, real matrix b) {
	if (rows(a)!=rows(b) | cols(a)!=cols(b)) return(0)
	return(all((a:==b) :| ((a:>=.) :& (b:>=.))))
}
void spc_cmp(real matrix X, string scalar lbl, real scalar nbad, real scalar ncase) {
	real matrix v1, v2
	real scalar i1, i2, r1, r2, k1, k2
	r1 = .; r2 = .; i1 = .; i2 = .; k1 = .; k2 = .
	v1 = ref_spec0_mvar(X, i1, k1, r1)
	v2 = ergm_spec0_mvar(X, i2, k2, r2)
	ncase++
	if (r1 != r2 | !spc_same(v1, v2) | !spc_same(i1, i2) | k1 != k2) {
		nbad++
		printf("MISMATCH %s\n", lbl)
	}
}
rseed(20261109)
nbad = 0
ncase = 0
for (rep=1; rep<=240; rep++) {
	p = ceil(runiform(1,1)*10)
	n = 20 + ceil(runiform(1,1)*400)
	rho = runiform(1,1)*0.98
	E = rnormal(n, p, 0, 1)
	X = J(n, p, 0)
	X[1,.] = E[1,.]
	for (t=2; t<=n; t++) X[t,.] = rho*X[t-1,.] + E[t,.] :+ 0.5*E[t,1]
	kind = mod(rep, 6)
	if (kind==1) X[.,p] = X[.,1]*2 :+ 3
	if (kind==2) X[.,1] = J(n,1,5)
	if (kind==3) X = X :+ (1::n)*0.05
	if (kind==4) {
		a = floor(0.1*n)
		b = floor(0.5*n)
		X = (X[1::a,.] :- mean(X[1::a,.])) \ J(ceil(10*log10(a+b)), p, .) \ (X[(n-b+1)::n,.] :- mean(X[(n-b+1)::n,.]))
	}
	if (kind==5) X = round(X*2)
	spc_cmp(X, "rep " + strofreal(rep), nbad, ncase)
}
for (rep=1; rep<=40; rep++) {
	p = ceil(runiform(1,1)*6)
	n = 15 + p + ceil(runiform(1,1)*15)
	spc_cmp(rnormal(n, p, 0, 1), "short " + strofreal(rep), nbad, ncase)
}
printf("%g series, %g mismatches\n", ncase, nbad)
assert(nbad == 0)
end
display "ALL OK"

# Writes cscripts/test_nwergm_balance.do: the term balance (balanced triads) of nwergm, structural(balance), against R ergm 4.12.0
#   (a) summary() on random and real, undirected and directed networks
#   (b) MPLE coefficients and standard errors, ergm(estimate = "MPLE")
#   (c) MCMLE within Monte Carlo noise of R for two seeds (one model per type)
# usage (from the repository root): Rscript dev/gen_test_balance.R
suppressMessages({library(ergm); library(network)})
set.seed(20261102)
data(florentine); data(sampson); data(faux.mesa.high)
mk_und <- function(n, p) { U <- matrix(0, n, n); U[upper.tri(U)] <- rbinom(n*(n-1)/2, 1, p); U + t(U) }
mk_dir <- function(n, p) { D <- matrix(rbinom(n*n, 1, p), n, n); diag(D) <- 0; D }
nets <- list(
  ru = list(kind="und", A=mk_und(35, .15)),
  flo = list(kind="und", A=as.matrix(flomarriage, matrix.type="adjacency")),
  mesa = list(kind="und", A=as.matrix(faux.mesa.high, matrix.type="adjacency")),
  rd = list(kind="dir", A=mk_dir(25, .12)),
  samp = list(kind="dir", A=as.matrix(samplike, matrix.type="adjacency")))
to_nw <- function(z) network(z$A, directed = z$kind == "dir")
fmt <- function(v) paste(formatC(v, digits=15, format="g"), collapse=" ")
out <- character(); w <- function(...) out <<- c(out, sprintf(...))
w("cscript"); w("")
w("capture adopath ++ \".\""); w("capture adopath ++ \"lib\"")
w("* The core package nwcommands is found through the environment variable NWCORE (path of the core checkout).")
w("local nwcore : env NWCORE")
w("if `\"`nwcore'\"' == \"\" {"); w("	di as error \"set the environment variable NWCORE to the directory of the nwcommands (core) package\""); w("	exit 198"); w("}")
w("adopath ++ `\"`nwcore'\"'"); w("adopath ++ `\"`c(pwd)'\"'")
w("quietly do `\"`nwcore'/unw_core.do\"'"); w("do unw_ergm.do")
w("capture adopath ++ \"lib/plugins/macos\""); w("capture adopath ++ \"lib/plugins/unix\""); w("capture adopath ++ \"lib/plugins/windows\"")
w("")
w("* Certifies the term balance (structural(balance)) against R ergm 4.12.0: statistic, MPLE and MCMLE; reference values from dev/gen_test_balance.R")
w("")
w("capture program drop bl_net"); w("program bl_net")
w("	args name kind n edges"); w("	nwclear"); w("	matrix __A = J(`n', `n', 0)")
w("	local k : word count `edges'"); w("	forvalues t = 1(2)`k' {"); w("		local i : word `t' of `edges'"); w("		local j : word `=`t'+1' of `edges'")
w("		matrix __A[`i', `j'] = 1"); w("	}")
w("	nwset, mat(__A) `=cond(\"`kind'\"==\"und\",\"undirected\",\"directed\")' name(`name') nooutput"); w("end"); w("")
w("capture program drop bl_check"); w("program bl_check")
w("	args net stat coefs ses")
w("	qui nwergm `net', edges structural(balance) method(mple)")
w("	mata: st_matrix(\"__bl_S\", __nwergm_last_M.full_statistic(__nwergm_last_G))")
w("	local p : word count `stat'")
w("	forvalues j = 1/`p' {"); w("		local e : word `j' of `stat'"); w("		assert abs(__bl_S[1,`j'] - `e') < 1e-9")
w("	}")
w("	tempname b V"); w("	matrix `b' = e(b)"); w("	matrix `V' = e(V)"); w("	local dmax 0")
w("	forvalues j = 1/`p' {"); w("		local e : word `j' of `coefs'"); w("		local s : word `j' of `ses'")
w("		local d1 = abs(`b'[1,`j'] - `e')"); w("		local d2 = abs(sqrt(`V'[`j',`j']) - `s')")
w("		if `d1' > 1e-4 * max(1, abs(`e')) | `d2' > 1e-4 * max(1, `s') {")
w("			di as err \"FAIL balance `net': coefficient `j' is \" `b'[1,`j'] \" (R `e'), se \" sqrt(`V'[`j',`j']) \" (R `s')\""); w("			exit 9"); w("		}")
w("		local dmax = max(`dmax', `d1', `d2')"); w("	}")
w("	di \"PASS balance `net': statistic exact, MPLE max difference to R \" %%9.2e `dmax'"); w("end"); w("")
w("capture program drop bl_mcmle"); w("program bl_mcmle")
w("	args net coefs ses")
w("	foreach sd in 101 202 {"); w("		set seed `sd'")
w("		qui nwergm `net', edges structural(balance) method(mcmle) mcmcsamplesize(4000) mcmcinterval(500) mcmcburnin(20000) mcmleiterations(40) nologlik")
w("		tempname b"); w("		matrix `b' = e(b)")
w("		forvalues j = 1/2 {"); w("			local e : word `j' of `coefs'"); w("			local s : word `j' of `ses'")
w("			if abs(`b'[1,`j'] - `e') > 3.5 * `s' {"); w("				di as err \"FAIL balance MCMLE `net' seed `sd': coefficient `j' is \" `b'[1,`j'] \" but R gives `e' (se `s')\""); w("				exit 9"); w("			}")
w("		}"); w("	}")
w("	di \"PASS balance MCMLE `net': within Monte Carlo noise of R for two seeds\""); w("end"); w("")
for (nm in names(nets)) {
  z <- nets[[nm]]; nw <- to_nw(z)
  s <- summary(nw ~ edges + balance)
  fit <- suppressWarnings(suppressMessages(ergm(nw ~ edges + balance, estimate="MPLE")))
  co <- coef(fit); se <- sqrt(diag(vcov(fit)))
  cat(nm, s, "MPLE", round(co, 4), "\n")
  if (any(!is.finite(se)) || any(se > 50)) { cat("  degenerate, skipped\n"); next }
  A <- z$A; e <- if (z$kind == "und") which(A == 1 & upper.tri(A), arr.ind=TRUE) else which(A == 1, arr.ind=TRUE)
  w("bl_net %s %s %d `\"%s\"'", nm, z$kind, nrow(A), paste(as.vector(t(e)), collapse=" "))
  w("bl_check %s `\"%s\"' `\"%s\"' `\"%s\"'", nm, fmt(as.numeric(s)), fmt(co), fmt(se))
  if (nm %in% c("ru", "rd")) {
    m <- suppressWarnings(suppressMessages(ergm(nw ~ edges + balance, control=control.ergm(seed=5, MCMC.samplesize=20000, MCMC.interval=1000, MCMC.burnin=50000))))
    cat("  MCMLE", round(coef(m), 4), "se", round(sqrt(diag(vcov(m))), 4), "\n")
    w("bl_mcmle %s `\"%s\"' `\"%s\"'", nm, fmt(coef(m)), fmt(sqrt(diag(vcov(m)))))
  }
  w("")
}
w("di \"test_nwergm_balance: ALL OK\"")
writeLines(out, "cscripts/test_nwergm_balance.do")

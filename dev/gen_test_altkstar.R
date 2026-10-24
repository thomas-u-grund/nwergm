# Writes cscripts/test_nwergm_altkstar.do: altkstar with an estimated lambda (R: altkstar, fixed = FALSE) of nwergm,
# structural(altkstar), against R ergm 4.12.0:
#   (a) the curved map and its gradient at three parameter points,
#   (b) the MPLE, ergm(estimate = "MPLE", control = control.ergm(init = )), for several starting values (R's pseudolikelihood fit
#       of this curved term stops early and depends on init; with its default start it fails)
# usage (from the repository root): Rscript dev/gen_test_altkstar.R
suppressMessages({library(ergm); library(network)})
set.seed(20261103)
data(florentine); data(faux.mesa.high); data(kapferer)
n <- 30; a <- rgamma(n, 1.5)/1.5
U <- matrix(0, n, n)
for (i in 1:(n-1)) for (j in (i+1):n) U[i,j] <- U[j,i] <- rbinom(1, 1, min(.9, .08*a[i]*a[j]*3))
nets <- list(ru = U, flo = as.matrix(flomarriage, matrix.type="adjacency"), kap = as.matrix(kapferer, matrix.type="adjacency"),
             mesa = as.matrix(faux.mesa.high, matrix.type="adjacency"))
inits <- list(c(-2.5, .3, 1.5), c(-2, .1, 3), c(-3, .5, 1), c(-4, .2, 2.5))
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
w("* Certifies altkstar with an estimated lambda (structural(altkstar), R: fixed = FALSE) against R ergm 4.12.0: the curved map and gradient, and the")
w("* pseudolikelihood fit from given starting values (init()). R cannot fit this term with its default starting values, and its maximum likelihood")
w("* estimate does not converge on the test networks, so those are not compared. Reference values: dev/gen_test_altkstar.R.")
w("")
# (a) map and gradient from R's own closures
nw0 <- network.initialize(10, directed = FALSE)
trm <- ergm:::InitErgmTerm.altkstar(nw0, list())
w("mata:")
for (x in list(c(0.7, 1.9), c(-0.4, 0.6), c(1.3, 4.2))) {
  mp <- trm$map(x, 9); gr <- trm$gradient(x, 9)
  w("assert(max(abs(ergm_altk_map(%s, %s, 9) - (%s))) < 1e-9 * max((1, max(abs((%s))))))", formatC(x[1], digits=15, format="g"), formatC(x[2], digits=15, format="g"), paste(formatC(mp, digits=15, format="g"), collapse=","), paste(formatC(mp, digits=15, format="g"), collapse=","))
  g <- paste(sapply(1:2, function(r) paste(formatC(gr[r,], digits=15, format="g"), collapse=",")), collapse=" \\ ")
  w("assert(max(abs(ergm_altk_gradient(%s, %s, 9) - (%s))) < 1e-9 * max((1, max(abs((%s))))))", formatC(x[1], digits=15, format="g"), formatC(x[2], digits=15, format="g"), g, g)
}
w("end")
w("di \"PASS altkstar map and gradient equal R's\"")
w("")
w("capture program drop ak_net"); w("program ak_net")
w("	args name n edges"); w("	nwclear"); w("	matrix __A = J(`n', `n', 0)")
w("	local k : word count `edges'"); w("	forvalues t = 1(2)`k' {"); w("		local i : word `t' of `edges'"); w("		local j : word `=`t'+1' of `edges'")
w("		matrix __A[`i', `j'] = 1"); w("		matrix __A[`j', `i'] = 1"); w("	}")
w("	nwset, mat(__A) undirected name(`name') nooutput"); w("end"); w("")
w("capture program drop ak_mple"); w("program ak_mple")
w("	args net init coefs ses opt")
w("	if \"`opt'\" == \"\" local opt \"structural(altkstar)\"")
w("	qui nwergm `net', edges `opt' method(mple) init(`init')")
w("	tempname b V"); w("	matrix `b' = e(b)"); w("	matrix `V' = e(V)"); w("	local dmax 0")
w("	forvalues j = 1/3 {"); w("		local e : word `j' of `coefs'"); w("		local s : word `j' of `ses'")
w("		local d1 = abs(`b'[1,`j'] - `e')"); w("		local d2 = abs(sqrt(`V'[`j',`j']) - `s')")
w("		if `d1' > 1e-3 * max(1, abs(`e')) | `d2' > 1e-3 * max(1, `s') {")
w("			di as err \"FAIL altkstar `net' init(`init'): coefficient `j' is \" `b'[1,`j'] \" (R `e'), se \" sqrt(`V'[`j',`j']) \" (R `s')\""); w("			exit 9"); w("		}")
w("		local dmax = max(`dmax', `d1', `d2')"); w("	}")
w("	di \"PASS altkstar `net' init(`init'): MPLE max difference to R \" %%9.2e `dmax'"); w("end"); w("")
for (nm in names(nets)) {
  A <- nets[[nm]]; nw <- network(A, directed=FALSE)
  e <- which(A == 1 & upper.tri(A), arr.ind=TRUE)
  first <- TRUE
  for (ini in inits) {
    r <- try(suppressWarnings(suppressMessages(ergm(nw ~ edges + altkstar, estimate="MPLE", control=control.ergm(init=ini)))), silent=TRUE)
    if (inherits(r, "try-error")) { cat(nm, "init", ini, "R failed\n"); next }
    co <- coef(r); se <- sqrt(diag(vcov(r)))
    cat(nm, "init", ini, "->", round(co, 4), "se", round(se, 3), "\n")
    if (any(!is.finite(se)) || any(se > 1e3)) next
    if (first) { w("ak_net %s %d `\"%s\"'", nm, nrow(A), paste(as.vector(t(e)), collapse=" ")); first <- FALSE }
    w("ak_mple %s `\"%s\"' `\"%s\"' `\"%s\"'", nm, paste(ini, collapse=" "), fmt(co), fmt(se))
  }
}
# init() also for the other curved terms (R: control.ergm(init = ))
for (nm in c("ru", "flo")) {
  A <- nets[[nm]]; nw <- network(A, directed=FALSE)
  e <- which(A == 1 & upper.tri(A), arr.ind=TRUE)
  w("ak_net %s %d `\"%s\"'", nm, nrow(A), paste(as.vector(t(e)), collapse=" "))
  for (tm in c("gwesp", "gwdegree")) for (ini in list(c(-2.5, .4, 1), c(-1.5, -.2, 0.5))) {
    r <- try(suppressWarnings(suppressMessages(ergm(as.formula(paste("nw ~ edges +", tm)), estimate="MPLE", control=control.ergm(init=ini)))), silent=TRUE)
    if (inherits(r, "try-error")) { cat(nm, tm, "R failed\n"); next }
    co <- coef(r); se <- sqrt(diag(vcov(r)))
    cat(nm, tm, "init", ini, "->", round(co, 4), "se", round(se, 3), "\n")
    if (any(!is.finite(se)) || any(se > 1e3)) next
    w("ak_mple %s `\"%s\"' `\"%s\"' `\"%s\"' `\"%sfree(1)\"'", nm, paste(ini, collapse=" "), fmt(co), fmt(se), tm)
  }
}
w("di \"test_nwergm_altkstar: ALL OK\"")
writeLines(out, "cscripts/test_nwergm_altkstar.do")

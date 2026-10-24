# Writes cscripts/test_nwergm_ops.do: the operator terms of nwergm's operators() option against R ergm 4.12.0.
#   (a) summary() of the model "edges + operator" on random and real networks (undirected, directed, bipartite)
#   (b) MPLE coefficients and standard errors, ergm(estimate = "MPLE")
#   (c) MCMLE coefficients (R fit with a long chain; nwergm must be within Monte Carlo noise for two seeds)
# usage (from the repository root): Rscript dev/gen_test_ops.R
suppressMessages({library(ergm); library(network); library(sna)})
set.seed(20261101)

# ---------------------------------------------------------------- networks
rows <- list()
mk_und <- function(n, g, h, x) {
  U <- matrix(0, n, n)
  for (i in 1:(n-1)) for (j in (i+1):n) {
    p <- plogis(-2.2 + 0.9*(g[i]==g[j]) + 0.5*(h[i]==h[j]) + 0.05*(x[i]+x[j]-9))
    U[i,j] <- U[j,i] <- rbinom(1, 1, p)
  }
  U
}
mk_dir <- function(n, g, h, x) {
  D <- matrix(0, n, n)
  for (i in 1:n) for (j in 1:n) if (i != j) {
    p <- plogis(-2.4 + 0.8*(g[i]==g[j]) + 0.5*(h[i]==h[j]) + 0.04*(x[j]-4.5) + 0.9*(D[j,i]==1))
    D[i,j] <- rbinom(1, 1, p)
  }
  D
}
mk_bip <- function(n1, n2, g, h, x) {
  B <- matrix(0, n1, n2)
  for (i in 1:n1) for (j in 1:n2) {
    p <- plogis(-1.4 + 0.8*(g[i]==g[n1+j]) + 0.4*(h[i]==h[n1+j]) + 0.04*(x[i]-4.5))
    B[i,j] <- rbinom(1, 1, p)
  }
  B
}

nets <- list()
# random undirected, 40 nodes
n <- 40; g <- sample(1:3, n, TRUE); h <- sample(1:2, n, TRUE); x <- sample(0:9, n, TRUE)
U <- mk_und(n, g, h, x)
nets$ru <- list(kind="und", A=U, attrs=list(g=g, h=h, x=x), c1="g", c2="h", cont="x", thr=4)
# florentine marriages
data(florentine)
fl <- flomarriage
w <- fl %v% "wealth"; pr <- fl %v% "priorates"
nets$flo <- list(kind="und", A=as.matrix(fl, matrix.type="adjacency"),
                 attrs=list(wealth=w, hi=as.numeric(w > median(w)), hi2=as.numeric(pr > median(pr))),
                 c1="hi", c2="hi2", cont="wealth", thr=30)
# faux mesa high school (205 nodes)
data(faux.mesa.high)
fm <- faux.mesa.high
nets$mesa <- list(kind="und", A=as.matrix(fm, matrix.type="adjacency"),
                  attrs=list(Sex=as.numeric(factor(fm %v% "Sex")), Race=as.numeric(factor(fm %v% "Race")), Grade=fm %v% "Grade"),
                  c1="Sex", c2="Race", cont="Grade", thr=9)
# random directed, 30 nodes
n <- 30; g <- sample(1:3, n, TRUE); h <- sample(1:2, n, TRUE); x <- sample(0:9, n, TRUE)
D <- mk_dir(n, g, h, x)
nets$rd <- list(kind="dir", A=D, attrs=list(g=g, h=h, x=x), c1="g", c2="h", cont="x", thr=4)
# random directed without reciprocated ties, 30 nodes (for Symmetrize with rule "weak", see the note in the cases)
Dm <- D; Dm[lower.tri(Dm) & t(Dm) == 1 & Dm == 1] <- 0
nets$rdm <- list(kind="dir", A=Dm, attrs=nets$rd$attrs, c1="g", c2="h", cont="x", thr=4)
# sampson monks (like)
data(sampson)
sl <- samplike
nets$samp <- list(kind="dir", A=as.matrix(sl, matrix.type="adjacency"),
                  attrs=list(group=as.numeric(factor(sl %v% "group")), cl=as.numeric(sl %v% "cloisterville"), age=1:18 %% 4),
                  c1="group", c2="cl", cont="age", thr=1)
# random bipartite 12 x 18
n1 <- 12; n2 <- 18; n <- n1 + n2
g <- sample(1:3, n, TRUE); h <- sample(1:2, n, TRUE); x <- sample(0:9, n, TRUE)
B <- mk_bip(n1, n2, g, h, x)
nets$rb <- list(kind="bip", A=B, n1=n1, attrs=list(g=g, h=h, x=x), c1="g", c2="h", cont="x", thr=4)
# Davis southern women (18 women x 14 events), with attributes drawn at random
dv <- rbind(
  c(1,1,1,1,1,1,0,1,1,0,0,0,0,0), c(1,1,1,0,1,1,1,1,0,0,0,0,0,0), c(0,1,1,1,1,1,1,1,1,0,0,0,0,0),
  c(1,0,1,1,1,1,1,1,0,0,0,0,0,0), c(0,0,1,1,1,0,1,0,0,0,0,0,0,0), c(0,0,1,0,1,1,0,1,0,0,0,0,0,0),
  c(0,0,0,0,1,1,1,1,0,0,0,0,0,0), c(0,0,0,0,0,1,0,1,1,0,0,0,0,0), c(0,0,0,0,1,0,1,1,1,0,0,0,0,0),
  c(0,0,0,0,0,0,1,1,1,0,0,1,0,0), c(0,0,0,0,0,0,0,1,1,1,0,1,0,0), c(0,0,0,0,0,0,0,1,1,1,0,1,1,1),
  c(0,0,0,0,0,0,1,1,1,1,0,1,1,1), c(0,0,0,0,0,1,1,0,1,1,1,1,1,1), c(0,0,0,0,0,0,1,1,0,1,1,1,0,0),
  c(0,0,0,0,0,0,0,1,1,0,0,0,0,0), c(0,0,0,0,0,0,0,0,1,0,1,0,0,0), c(0,0,0,0,0,0,0,0,1,0,1,0,0,0))   # Davis, Gardner and Gardner (1941)
stopifnot(sum(dv) == 89)
n1 <- nrow(dv); n2 <- ncol(dv); n <- n1 + n2
g <- sample(1:3, n, TRUE); h <- sample(1:2, n, TRUE); x <- sample(0:9, n, TRUE)
nets$dav <- list(kind="bip", A=unname(dv), n1=n1, attrs=list(g=g, h=h, x=x), c1="g", c2="h", cont="x", thr=4)

to_nw <- function(z) {
  A <- z$A
  nw <- switch(z$kind,
    und = network(A, directed=FALSE),
    dir = network(A, directed=TRUE),
    bip = { nn <- nrow(A) + ncol(A); M <- matrix(0, nn, nn); M[1:nrow(A), nrow(A) + 1:ncol(A)] <- A
            network(M, directed=FALSE, bipartite=nrow(A)) })
  for (a in names(z$attrs)) nw %v% a <- z$attrs[[a]]
  nw
}

# ---------------------------------------------------------------- cases: R formula and nwergm operators() text
cases <- list()
add <- function(net, id, r, s, mcmle=FALSE, brute=FALSE, fixed=NULL) cases[[length(cases)+1]] <<- list(net=net, id=id, r=r, s=s, mcmle=mcmle, brute=brute, fixed=fixed)
for (nm in c("ru", "flo", "mesa")) {
  z <- nets[[nm]]; c1 <- z$c1; c2 <- z$c2; ct <- z$cont; th <- z$thr
  q <- function(a) sprintf('"%s"', a)
  add(nm, "Sum two formulas",
      sprintf('Sum(list(~triangle+nodematch(%s), ~nodecov(%s)+kstar(2)), label=c("a","b"))', q(c1), q(ct)),
      sprintf('Sum(triangle nodematch(%s) | nodecov(%s) kstar(2), label(a b))', c1, ct))
  add(nm, "Sum mean preset",
      sprintf('Sum("mean"~triangle+nodecov(%s)+kstar(2), label="m")', q(ct)),
      sprintf('Sum(mean: triangle nodecov(%s) kstar(2), label(m))', ct))
  add(nm, "Sum scalar weight",
      sprintf('Sum(list(~triangle, 3~kstar(2)), label="w")'),
      sprintf('Sum(triangle | 3: kstar(2), label(w))'))
  add(nm, "Prod two formulas",
      sprintf('Prod(list(~nodecov(%s)+kstar(2), ~triangle+nodematch(%s)), label=c("a","b"))', q(ct), q(c1)),
      sprintf('Prod(nodecov(%s) kstar(2) | triangle nodematch(%s), label(a b))', ct, c1))
  add(nm, "Prod geomean preset",
      sprintf('Prod("geomean"~nodecov(%s)+kstar(2)+triangle, label="gm")', q(ct)),
      sprintf('Prod(geomean: nodecov(%s) kstar(2) triangle, label(gm))', ct))
  add(nm, "S induced subgraph",
      sprintf('S(~triangle+nodematch(%s)+degree(1), ~%s>%g)', q(c1), ct, th),
      sprintf('S(triangle nodematch(%s) degree(1), attrs(%s>%g))', c1, ct, th))
  add(nm, "F nodematch",
      sprintf('F(~triangle+nodematch(%s), ~nodematch(%s))', q(c1), q(c2)),
      sprintf('F(triangle nodematch(%s), filter(nodematch(%s)))', c1, c2))
  add(nm, "F not nodematch",
      sprintf('F(~triangle+kstar(2), ~!nodematch(%s))', q(c2)),
      sprintf('F(triangle kstar(2), filter(!nodematch(%s)))', c2))
  add(nm, "F absdiff comparison",
      sprintf('F(~triangle+kstar(2), ~absdiff(%s)>2)', q(ct)),
      sprintf('F(triangle kstar(2), filter(absdist(%s) > 2))', ct))
  add(nm, "NodematchFilter",
      sprintf('NodematchFilter(~triangle+kstar(2), %s)', q(c2)),
      sprintf('NodematchFilter(triangle kstar(2), attrname(%s))', c2))
  add(nm, "I",
      sprintf('I(~triangle+nodematch(%s))', q(c1)),
      sprintf('I(triangle nodematch(%s))', c1))
  add(nm, "For",
      sprintf('For(. = c(%s, %s), ~nodematch(.))', q(c1), q(c2)),
      sprintf('For(v = %s %s, nodematch({v}))', c1, c2))
  add(nm, "Label paren",
      'Label(~triangle+kstar(2), "z", "(")',
      'Label(triangle kstar(2), label(z), pos(paren))')
  add(nm, "Label append",
      'Label(~triangle+kstar(2), "z", "append")',
      'Label(triangle kstar(2), label(z), pos(append))')
  add(nm, "Log",
      'Log(~kstar(2)+triangle)', 'Log(kstar(2) triangle)')
  add(nm, "Exp",
      'Exp(~triangle)', 'Exp(triangle)')
  add(nm, "Offset",
      'Offset(~triangle+kstar(2), coef=0.1, which=1)', 'Offset(triangle kstar(2), coef(0.1) which(1))', fixed=list(pos=2, val=0.1))
  add(nm, "Sum of F and S",
      sprintf('Sum(list(~F(~triangle+kstar(2), ~nodematch(%s)), ~S(~triangle+kstar(2), ~%s>%g)), label=c("a","b"))', q(c2), ct, th),
      sprintf('Sum(F(triangle kstar(2), filter(nodematch(%s))) | S(triangle kstar(2), attrs(%s>%g)), label(a b))', c2, ct, th))
}
for (nm in c("rd", "samp")) {
  z <- nets[[nm]]; c1 <- z$c1; c2 <- z$c2; ct <- z$cont; th <- z$thr
  q <- function(a) sprintf('"%s"', a)
  # ergm 4.12.0 builds the symmetrized network it starts from without the reciprocated pairs when rule = "weak" (its
  # estimation therefore differs from the statistic it reports); for these cases the reference is the pseudolikelihood
  # fit to the exact change statistics (brute = TRUE)
  for (r in c("weak", "strong", "upper", "lower"))
    add(nm, paste("Symmetrize", r),
        sprintf('Symmetrize(~triangle+kstar(2), rule="%s")', r),
        sprintf('Symmetrize(triangle kstar(2), rule(%s))', r), brute = (r == "weak"))
  add(nm, "Symmetrize with edges",
      'Symmetrize(~edges+triangle, rule="weak")',
      'Symmetrize(edges triangle, rule(weak))', brute = TRUE)
  add(nm, "Sum directed",
      sprintf('Sum(list(~mutual+nodematch(%s), ~nodeicov(%s)+nodeocov(%s)), label=c("a","b"))', q(c1), q(ct), q(ct)),
      sprintf('Sum(mutual nodematch(%s) | nodeicov(%s) nodeocov(%s), label(a b))', c1, ct, ct))
  add(nm, "Prod directed",
      sprintf('Prod(list(~nodeicov(%s)+nodeocov(%s), ~mutual+nodematch(%s)), label=c("a","b"))', q(ct), q(ct), q(c1)),
      sprintf('Prod(nodeicov(%s) nodeocov(%s) | mutual nodematch(%s), label(a b))', ct, ct, c1))
  add(nm, "F directed",
      sprintf('F(~mutual+ctriple, ~nodematch(%s))', q(c2)),
      sprintf('F(mutual ctriple, filter(nodematch(%s)))', c2))
  add(nm, "S directed",
      sprintf('S(~mutual+nodematch(%s), ~%s>%g)', q(c1), ct, th),
      sprintf('S(mutual nodematch(%s), attrs(%s>%g))', c1, ct, th))
  add(nm, "NodematchFilter directed",
      sprintf('NodematchFilter(~mutual+istar(2), %s)', q(c2)),
      sprintf('NodematchFilter(mutual istar(2), attrname(%s))', c2))
}
add("rdm", "Symmetrize weak", 'Symmetrize(~triangle+kstar(2), rule="weak")', 'Symmetrize(triangle kstar(2), rule(weak))')
add("rdm", "Symmetrize with edges", 'Symmetrize(~edges+triangle, rule="weak")', 'Symmetrize(edges triangle, rule(weak))')
for (nm in c("rb", "dav")) {
  z <- nets[[nm]]; c1 <- z$c1; c2 <- z$c2; ct <- z$cont; th <- z$thr
  q <- function(a) sprintf('"%s"', a)
  add(nm, "Proj1", 'Proj1(~B(~edges+triangle, "nonzero"))', 'Proj1(edges triangle)')
  add(nm, "Proj2", 'Proj2(~B(~edges+triangle+kstar(2), "nonzero"))', 'Proj2(edges triangle kstar(2))')
  add(nm, "Project mode 1",
      'Project(~B(~triangle+kstar(2), "nonzero"), 1)', 'Project(triangle kstar(2), mode(1))')
  add(nm, "Proj1 nodematch",
      sprintf('Proj1(~B(~triangle+nodematch(%s), "nonzero"))', q(c1)),
      sprintf('Proj1(triangle nodematch(%s))', c1))
  add(nm, "F bipartite",
      sprintf('F(~b1degree(1)+b2degree(1)+kstar(2), ~nodematch(%s))', q(c1)),
      sprintf('F(bdegree1(1) bdegree2(1) kstar(2), filter(nodematch(%s)))', c1))
  add(nm, "Sum bipartite",
      'Sum(list(~b1degree(1:2)+b1star(2), ~b2degree(1:2)+b2star(2)), label=c("a","b","c"))',
      'Sum(bdegree1(1 2) bstar1(2) | bdegree2(1 2) bstar2(2), label(a b c))')
}
# models for the maximum likelihood comparison
add("flo", "MCMLE F", 'F(~triangle+kstar(2), ~nodematch("hi2"))', 'F(triangle kstar(2), filter(nodematch(hi2)))', TRUE)
add("ru", "MCMLE Sum", 'Sum(list(~triangle, ~kstar(2)), label="a")', 'Sum(triangle | kstar(2), label(a))', TRUE)
add("ru", "MCMLE S", 'S(~edges+triangle, ~x>4)', 'S(edges triangle, attrs(x>4))', TRUE)
add("rd", "MCMLE Symmetrize", 'Symmetrize(~triangle, rule="upper")', 'Symmetrize(triangle, rule(upper))', TRUE)
add("rb", "MCMLE Proj1", 'Proj1(~B(~triangle, "nonzero"))', 'Proj1(triangle)', TRUE)

# ---------------------------------------------------------------- reference values from R
fmt <- function(v) paste(ifelse(is.na(v), "NA", formatC(v, digits=15, format="g")), collapse=" ")
out <- character()
w <- function(...) out <<- c(out, sprintf(...))
res <- list()
for (cs in cases) {
  z <- nets[[cs$net]]; nw <- to_nw(z)
  f <- as.formula(paste("nw ~ edges +", cs$r))
  s <- try(summary(f), silent=TRUE)
  if (inherits(s, "try-error")) { cat("SUMMARY FAILED:", cs$net, cs$id, as.character(s), "\n"); next }
  if (cs$mcmle) {
    fit <- try(suppressWarnings(suppressMessages(ergm(f, control=control.ergm(seed=11, MCMC.samplesize=20000, MCMC.interval=1000, MCMC.burnin=50000)))), silent=TRUE)
    if (inherits(fit, "try-error")) { cat("MCMLE FAILED:", cs$net, cs$id, "\n"); next }
    co <- coef(fit); se <- sqrt(diag(vcov(fit)))
  } else if (isTRUE(cs$brute)) {
    # pseudolikelihood from the exact change statistics: statistic with the dyad set to 1 minus with the dyad set to 0
    A <- z$A; nn <- nrow(A); X <- NULL; y <- NULL
    for (i in 1:nn) for (j in 1:nn) if (i != j) {
      A1 <- A; A1[i,j] <- 1; A0 <- A; A0[i,j] <- 0
      nw1 <- to_nw(modifyList(z, list(A=A1))); nw0 <- to_nw(modifyList(z, list(A=A0)))
      X <- rbind(X, summary(as.formula(paste("nw1 ~ edges +", cs$r))) - summary(as.formula(paste("nw0 ~ edges +", cs$r))))
      y <- c(y, A[i,j])
    }
    gf <- glm(y ~ X - 1, family=binomial)
    co <- coef(gf); se <- sqrt(diag(vcov(gf)))
    fit <- NULL
  } else {
    fit <- try(suppressWarnings(suppressMessages(ergm(f, estimate="MPLE"))), silent=TRUE)
    if (inherits(fit, "try-error")) { cat("MPLE FAILED:", cs$net, cs$id, "\n"); next }
    co <- coef(fit); se <- sqrt(diag(vcov(fit)))
  }
  if (any(!is.finite(se)) || any(se > 50, na.rm = TRUE)) { cat("DEGENERATE (skipped):", cs$net, cs$id, "\n"); next }
  cat(sprintf("%-6s %-26s ok  stats: %s\n", cs$net, cs$id, paste(round(s, 3), collapse=" ")))
  res[[length(res)+1]] <- c(cs, list(stat=as.numeric(s), coef=as.numeric(co), se=as.numeric(se), names=names(s), cnames=names(co)))
}

# ---------------------------------------------------------------- the Stata test
w("cscript")
w("")
w("capture adopath ++ \".\"")
w("capture adopath ++ \"lib\"")
w("* The core package nwcommands is found through the environment variable NWCORE (path of the core checkout).")
w("local nwcore : env NWCORE")
w("if `\"`nwcore'\"' == \"\" {")
w("	di as error \"set the environment variable NWCORE to the directory of the nwcommands (core) package\"")
w("	exit 198")
w("}")
w("adopath ++ `\"`nwcore'\"'")
w("adopath ++ `\"`c(pwd)'\"'")
w("quietly do `\"`nwcore'/unw_core.do\"'")
w("do unw_ergm.do")
w("capture adopath ++ \"lib/plugins/macos\"")
w("capture adopath ++ \"lib/plugins/unix\"")
w("capture adopath ++ \"lib/plugins/windows\"")
w("")
w("* Certifies the operator terms of nwergm's operators() option against R ergm 4.12.0:")
w("*  (1) the observed statistics of `edges + operator' equal summary() of the same formula,")
w("*  (2) the MPLE coefficients and standard errors equal ergm(estimate = \"MPLE\"),")
w("*  (3) the MCMLE coefficients are within Monte Carlo noise of R's, for two seeds.")
w("* Networks: random undirected (40 nodes), Florentine marriages, Faux Mesa High; random directed (30), Sampson's monks;")
w("* random bipartite (12 x 18), Davis' southern women. Reference values: dev/gen_test_ops.R (this file is generated by it).")
w("")
w("capture program drop ops_net")
w("program ops_net")
w("	// ops_net name kind n \"edge list\" [n1]: kind is und, dir or bip; the edge list is i j i j ... (bipartite: person event)")
w("	args name kind n edges n1")
w("	nwclear")
w("	if \"`kind'\" == \"bip\" {")
w("		local n2 = `n' - `n1'")
w("		matrix __A = J(`n2', `n1', 0)")
w("		local k : word count `edges'")
w("		forvalues t = 1(2)`k' {")
w("			local i : word `t' of `edges'")
w("			local j : word `=`t'+1' of `edges'")
w("			matrix __A[`j', `i'] = 1")
w("		}")
w("		nwset, mat(__A) bipartite name(`name') nooutput")
w("		clear")
w("		set obs `n'")
w("	}")
w("	else {")
w("		matrix __A = J(`n', `n', 0)")
w("		local k : word count `edges'")
w("		forvalues t = 1(2)`k' {")
w("			local i : word `t' of `edges'")
w("			local j : word `=`t'+1' of `edges'")
w("			matrix __A[`i', `j'] = 1")
w("			if \"`kind'\" == \"und\" matrix __A[`j', `i'] = 1")
w("		}")
w("		nwset, mat(__A) `=cond(\"`kind'\"==\"und\",\"undirected\",\"directed\")' name(`name') nooutput")
w("	}")
w("end")
w("")
w("capture program drop ops_var")
w("program ops_var")
w("	args v values")
w("	capture drop `v'")
w("	qui gen double `v' = .")
w("	local k = 0")
w("	foreach x of local values {")
w("		local ++k")
w("		qui replace `v' = `x' in `k'")
w("	}")
w("end")
w("")
w("capture program drop ops_check")
w("program ops_check")
w("	// ops_check net id \"operators\" \"stats\" \"coefs\" \"ses\" [tolerance of the statistics]")
w("	// (R computes Prod as Exp(Sum(Log)) with the value -1/sqrt(eps) for log(0), which limits the precision of its Prod statistics to about 1e-8)")
w("	args net id ops stats coefs ses tol")
w("	if \"`tol'\" == \"\" local tol 1e-8")
w("	qui nwergm `net', edges operators(`ops') method(mple)")
w("	mata: st_matrix(\"__ops_S\", __nwergm_last_M.full_statistic(__nwergm_last_G))")
w("	local p : word count `stats'")
w("	assert colsof(__ops_S) == `p'")
w("	assert colsof(e(b)) == `p'")
w("	forvalues j = 1/`p' {")
w("		local e : word `j' of `stats'")
w("		if abs(__ops_S[1,`j'] - `e') > `tol' * max(1, abs(`e')) {")
w("			di as err \"FAIL statistic `net' `id': term `j' is \" __ops_S[1,`j'] \" but R gives `e'\"")
w("			exit 9")
w("		}")
w("	}")
w("	tempname b V")
w("	matrix `b' = e(b)")
w("	matrix `V' = e(V)")
w("	local dmax 0")
w("	forvalues j = 1/`p' {")
w("		local e : word `j' of `coefs'")
w("		local s : word `j' of `ses'")
w("		if \"`e'\" == \"NA\" {")
w("			assert `b'[1,`j'] == 0")
w("			continue")
w("		}")
w("		local d1 = abs(`b'[1,`j'] - `e')")
w("		local d2 = abs(sqrt(`V'[`j',`j']) - `s')")
w("		if `d1' > 1e-4 * max(1, abs(`e')) | `d2' > 1e-4 * max(1, `s') {")
w("			di as err \"FAIL MPLE `net' `id': coefficient `j' is \" `b'[1,`j'] \" (R `e'), se \" sqrt(`V'[`j',`j']) \" (R `s')\"")
w("			exit 9")
w("		}")
w("		local dmax = max(`dmax', `d1', `d2')")
w("	}")
w("	di \"PASS `net' `id': statistics exact, MPLE max difference \" %%9.2e `dmax'")
w("end")
w("")
w("capture program drop ops_check_off")
w("program ops_check_off")
w("	// as ops_check, for a model with one fixed coefficient: R reports only the free coefficients")
w("	args net id ops stats coefs ses fpos fval")
w("	qui nwergm `net', edges operators(`ops') method(mple)")
w("	mata: st_matrix(\"__ops_S\", __nwergm_last_M.full_statistic(__nwergm_last_G))")
w("	local p : word count `stats'")
w("	forvalues j = 1/`p' {")
w("		local e : word `j' of `stats'")
w("		assert abs(__ops_S[1,`j'] - `e') <= 1e-8 * max(1, abs(`e'))")
w("	}")
w("	tempname b V")
w("	matrix `b' = e(b)")
w("	matrix `V' = e(V)")
w("	local k = 0")
w("	local dmax 0")
w("	forvalues j = 1/`p' {")
w("		if `j' == `fpos' {")
w("			assert abs(`b'[1,`j'] - `fval') < 1e-12")
w("			continue")
w("		}")
w("		local ++k")
w("		local e : word `k' of `coefs'")
w("		local s : word `k' of `ses'")
w("		local d1 = abs(`b'[1,`j'] - `e')")
w("		local d2 = abs(sqrt(`V'[`j',`j']) - `s')")
w("		if `d1' > 1e-4 * max(1, abs(`e')) | `d2' > 1e-4 * max(1, `s') {")
w("			di as err \"FAIL MPLE `net' `id': coefficient `j' is \" `b'[1,`j'] \" (R `e'), se \" sqrt(`V'[`j',`j']) \" (R `s')\"")
w("			exit 9")
w("		}")
w("		local dmax = max(`dmax', `d1', `d2')")
w("	}")
w("	di \"PASS `net' `id': statistics exact, MPLE max difference \" %%9.2e `dmax'")
w("end")
w("")
w("capture program drop ops_mcmle")
w("program ops_mcmle")
w("	// ops_mcmle net id \"operators\" \"coefs\" \"ses\"")
w("	args net id ops coefs ses")
w("	foreach sd in 101 202 {")
w("		set seed `sd'")
w("		qui nwergm `net', edges operators(`ops') method(mcmle) mcmcsamplesize(4000) mcmcinterval(500) mcmcburnin(20000) mcmleiterations(40)")
w("		assert e(converged) == 1")
w("		tempname b")
w("		matrix `b' = e(b)")
w("		local p = colsof(`b')")
w("		forvalues j = 1/`p' {")
w("			local e : word `j' of `coefs'")
w("			local s : word `j' of `ses'")
w("			if abs(`b'[1,`j'] - `e') > 3.5 * `s' {")
w("				di as err \"FAIL MCMLE `net' `id' seed `sd': coefficient `j' is \" `b'[1,`j'] \" but R gives `e' (se `s')\"")
w("				exit 9")
w("			}")
w("		}")
w("	}")
w("	di \"PASS `net' `id': MCMLE within Monte Carlo noise of R for two seeds\"")
w("end")
w("")

emit_net <- function(nm) {
  z <- nets[[nm]]; A <- z$A
  if (z$kind == "bip") {
    e <- which(A == 1, arr.ind=TRUE); el <- paste(as.vector(t(e)), collapse=" ")
    n <- nrow(A) + ncol(A); n1 <- nrow(A)
  } else if (z$kind == "und") {
    e <- which(A == 1 & upper.tri(A), arr.ind=TRUE); el <- paste(as.vector(t(e)), collapse=" ")
    n <- nrow(A); n1 <- ""
  } else {
    e <- which(A == 1, arr.ind=TRUE); el <- paste(as.vector(t(e)), collapse=" ")
    n <- nrow(A); n1 <- ""
  }
  w("ops_net %s %s %d `\"%s\"' %s", nm, z$kind, n, el, n1)
  for (a in names(z$attrs)) w("ops_var %s `\"%s\"'", a, paste(z$attrs[[a]], collapse=" "))
}
done <- character()
for (nm in names(nets)) {
  cs <- Filter(function(r) r$net == nm, res)
  if (!length(cs)) next
  w("* ---------------- network %s", nm)
  emit_net(nm)
  for (r in cs) {
    if (is.na(r$s)) next
    if (r$mcmle) w("ops_mcmle %s `\"%s\"' `\"%s\"' `\"%s\"' `\"%s\"'", nm, r$id, r$s, fmt(r$coef), fmt(r$se))
    else if (!is.null(r$fixed)) w("ops_check_off %s `\"%s\"' `\"%s\"' `\"%s\"' `\"%s\"' `\"%s\"' %d %s", nm, r$id, r$s, fmt(r$stat), fmt(r$coef), fmt(r$se), r$fixed$pos, format(r$fixed$val))
    else w("ops_check %s `\"%s\"' `\"%s\"' `\"%s\"' `\"%s\"' `\"%s\"' %s", nm, r$id, r$s, fmt(r$stat), fmt(r$coef), fmt(r$se), if (grepl("^Prod", r$id)) "1e-6" else "")
  }
  w("")
}
w("di \"test_nwergm_ops: ALL OK\"")
writeLines(out, "cscripts/test_nwergm_ops.do")
cat("wrote cscripts/test_nwergm_ops.do with", length(res), "cases\n")

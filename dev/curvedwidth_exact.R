# Reference values of cscripts/test_nwergm_curvedwidth.do: exact maximum likelihood of the curved terms at decay 0.5 on small networks (every graph enumerated).
# The posterior means of the Bayesian test come from the same enumeration (grid over edges, weight, decay; N(0,100) priors).
suppressMessages(library(ergm))
lse <- function(x) { m <- max(x); m + log(sum(exp(x - m))) }
run <- function(nw, term, K, lab, a=0.5) {
  f <- as.formula(sprintf("nw ~ edges + %s(1:%d%s)", term, K, if (network::is.directed(nw)) ', type="OTP"' else ""))
  sobs <- summary(f); al <- ergm.allstats(f, zeroobs=FALSE)
  S <- al$statmat; logw <- log(al$weights); ek <- exp(a)*(1-(1-exp(-a))^(1:K))
  ll <- function(p){ eta<-c(p[1],p[2]*ek); sum(eta*sobs)-lse(as.vector(S%*%eta)+logw)}
  o <- optim(c(-1,0.3), function(p) -ll(p), control=list(reltol=1e-14,maxit=5000))
  o <- optim(o$par, function(p) -ll(p), method="BFGS", control=list(reltol=1e-15))
  cat(sprintf("EXACT %s edges %.5f weight %.5f\n", lab, o$par[1], o$par[2]))
}
A <- as.matrix(read.csv("/private/tmp/claude-501/-Users-tgrund-FILES-NEW-SOFTWARE-nwcommands/9d5243e9-ee49-4558-835d-02925b410730/scratchpad/divcheck/c1e/tiny_A.csv", header=FALSE))
nw <- network(A, directed=FALSE)
for (t in c("esp","dsp","nsp")) run(nw, t, 5, paste0("und_",t))
set.seed(3); D <- matrix(rbinom(25,1,0.55),5,5); diag(D) <- 0
write.table(D, "dir5.csv", row.names=FALSE, col.names=FALSE, sep=",")
nd <- network(D, directed=TRUE)
for (t in c("esp","dsp","nsp")) run(nd, t, 3, paste0("dir_",t))

lse <- function(x) { m <- max(x); m + log(sum(exp(x - m))) }
M <- matrix(0,3,5); M[1,c(1,2,3)]<-1; M[2,c(2,3,4)]<-1; M[3,c(3,5)]<-1
nw <- network(M, bipartite=3, directed=FALSE, matrix.type="bipartite")
a <- 0.5
for (tt in c("b1dsp","b2dsp")) {
 K <- if (tt=="b1dsp") 5 else 3
 f <- as.formula(sprintf("nw ~ edges + %s(1:%d)", tt, K))
 sobs <- summary(f); al <- ergm.allstats(f, zeroobs=FALSE)
 S <- al$statmat; logw <- log(al$weights); ek <- exp(a)*(1-(1-exp(-a))^(1:K))
 ll <- function(p){ eta<-c(p[1],p[2]*ek); sum(eta*sobs)-lse(as.vector(S%*%eta)+logw)}
 o <- optim(c(-1,0.3), function(p) -ll(p), control=list(reltol=1e-14,maxit=5000))
 o <- optim(o$par, function(p) -ll(p), method="BFGS", control=list(reltol=1e-15))
 cat(sprintf("EXACT bip_%s edges %.5f weight %.5f\n", tt, o$par[1], o$par[2]))
}

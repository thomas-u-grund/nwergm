suppressMessages({library(ergm.ego); library(egor)})
set.seed(20261119)
N <- 1000
nw <- network.initialize(N, directed=FALSE)
nw %v% "g" <- sample(c("a","b","c"), N, TRUE, c(.5,.3,.2))
nw %v% "age" <- sample(18:65, N, TRUE)
theta <- c(edges=-5.2, nodefactor.g.b=-0.3, nodefactor.g.c=0.2, nodematch.g=0.8, nodecov.age=0.004, absdiff.age=-0.03, concurrent=-0.4)
fp <- nw ~ edges + nodefactor("g") + nodematch("g") + nodecov("age") + absdiff("age") + concurrent
y <- simulate(fp, coef=theta, nsim=1, control=control.simulate.formula(MCMC.burnin=2e6, MCMC.interval=1e4))
cat("edges", network.edgecount(y), "meandeg", 2*network.edgecount(y)/N, "\n")
print(summary(fp, basis=y))
full <- as.egor(y)
write.csv(as.data.frame(full$ego), "fix/pl_full_ego.csv", row.names=FALSE)
# unweighted sample of 400 egos
set.seed(11)
s1 <- sample(full, 400)
f <- s1 ~ edges + nodefactor("g") + nodematch("g") + nodecov("age") + absdiff("age") + concurrent
dump <- function(s, tag){
  write.csv(as.data.frame(s$ego), sprintf("fix/%s_ego.csv", tag), row.names=FALSE)
  write.csv(as.data.frame(s$alter), sprintf("fix/%s_alter.csv", tag), row.names=FALSE)
}
dump(s1, "pl")
for (sd in 1:2) {
  fit <- ergm.ego(f, popsize=N, control=control.ergm.ego(ergm=control.ergm(seed=sd, MCMLE.effectiveSize=400, MCMLE.maxit=60)))
  cat("SEED", sd, "\n"); print(summary(fit))
  out <- data.frame(name=names(coef(fit)), b=coef(fit), se=sqrt(diag(fit$covar)))
  write.csv(out, sprintf("fix/pl_coef_s%d.csv", sd), row.names=FALSE)
  if (sd==1) { write.csv(data.frame(name=names(fit$m), m=fit$m), "fix/pl_m.csv", row.names=FALSE); write.csv(fit$v, "fix/pl_v.csv"); write.csv(fit$DtDe, "fix/pl_DtDe.csv") }
}
# weighted sample: probability depends on group
set.seed(12)
pr <- c(a=.2,b=.5,c=.8)[full$ego$g]; pr <- pr*(400/sum(pr))
s2 <- sample(full, 400, prob=pr)
dump(s2, "pw")
f2 <- s2 ~ edges + nodefactor("g") + nodematch("g") + nodecov("age") + absdiff("age") + concurrent
write.csv(data.frame(w=weights(s2)), "fix/pw_w.csv", row.names=FALSE)
for (sd in 1:2) {
  fit <- ergm.ego(f2, popsize=N, control=control.ergm.ego(ergm=control.ergm(seed=sd, MCMLE.effectiveSize=400, MCMLE.maxit=60)))
  cat("WSEED", sd, "pp", fit$ppopsize, "\n"); print(summary(fit))
  out <- data.frame(name=names(coef(fit)), b=coef(fit), se=sqrt(diag(fit$covar)))
  write.csv(out, sprintf("fix/pw_coef_s%d.csv", sd), row.names=FALSE)
  if (sd==1) { write.csv(data.frame(name=names(fit$m), m=fit$m), "fix/pw_m.csv", row.names=FALSE); write.csv(fit$v, "fix/pw_v.csv") }
}
# popsize variants with the unweighted sample: popsize default (1), ppopsize samp, numeric
fitA <- ergm.ego(f, control=control.ergm.ego(ergm=control.ergm(seed=1, MCMLE.effectiveSize=400)))
cat("DEFAULT popsize\n"); print(summary(fitA)); write.csv(data.frame(name=names(coef(fitA)), b=coef(fitA), se=sqrt(diag(fitA$covar))), "fix/pl_default.csv", row.names=FALSE)
fitB <- ergm.ego(f, popsize=5000, control=control.ergm.ego(ppopsize=1000, ergm=control.ergm(seed=1, MCMLE.effectiveSize=400)))
cat("pop5000 pp1000\n"); print(summary(fitB)); write.csv(data.frame(name=names(coef(fitB)), b=coef(fitB), se=sqrt(diag(fitB$covar))), "fix/pl_pop5000.csv", row.names=FALSE)
g <- gof(fit)

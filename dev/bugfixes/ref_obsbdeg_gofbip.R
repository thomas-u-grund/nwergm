suppressMessages(library(ergm)); options(ergm.loglik.warn_dyads=FALSE)
B <- as.matrix(read.csv("bip.csv", header=FALSE)); print(dim(B)); nw <- network(B, bipartite=8, directed=FALSE, matrix.type="bipartite")
print(summary(nw~edges+b1star(2)+b2star(2)))
f <- suppressMessages(ergm(nw~edges+b1star(2), control=control.ergm(seed=1,MCMC.samplesize=300,MCMC.burnin=500,MCMC.interval=20)))
g <- gof(f, GOF=~b1degree+b2degree, control=control.gof.ergm(nsim=20, seed=1)); print(g$summary.b1deg[,1]); print(g$summary.b2deg[,1])
for (m in list(list(nw~edges+b2star(2),"~b1degrees"), list(nw~edges+b2star(2),"~b2degrees"), list(nw~edges+b1star(2),"~b1degrees"), list(nw~edges+b1star(2),"~b2degrees"))) for (sd in 1:2) {
cc <- control.ergm(seed=sd,MCMC.samplesize=4000,MCMC.burnin=10000,MCMC.interval=100,MCMLE.maxit=40)
r <- try(suppressMessages(ergm(m[[1]], obs.constraints=as.formula(m[[2]]), control=cc)),silent=TRUE)
cat("RES", format(m[[1]]), sd, m[[2]], if (inherits(r,"try-error")) conditionMessage(attr(r,"condition")) else round(coef(r),3), "\n") }
for (fm in list(nw~edges+b2star(2), nw~edges+b1star(2))) cat("RES unconstrained", format(fm), round(coef(suppressMessages(ergm(fm, control=control.ergm(seed=1,MCMC.samplesize=10000,MCMC.burnin=20000,MCMC.interval=200)))),3), "\n")

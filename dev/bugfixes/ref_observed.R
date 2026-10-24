suppressMessages(library(ergm)); options(ergm.loglik.warn_dyads=FALSE)
set.seed(3); n<-20; A<-matrix(rbinom(n*n,1,.2),n,n); A[lower.tri(A,TRUE)]<-0; A<-A+t(A)
nwc <- network(A, directed=FALSE)
nwm <- nwc; nwm[2,5] <- NA; nwm[7,9] <- NA; nwm[1,13] <- NA; nwm[3,4]<-NA
cc <- control.ergm(MCMC.samplesize=500, MCMC.burnin=2000, MCMC.interval=50, MCMLE.maxit=5, seed=1)
tr <- function(lab, expr) { r <- try(expr, silent=TRUE); cat("==", lab, ":", if (inherits(r,"try-error")) paste("ERR", conditionMessage(attr(r,"condition"))) else paste(round(coef(r),3), collapse=" "), "\n") }
tr("complete constraints=observed", ergm(nwc~edges+triangle, constraints=~observed, control=cc))
tr("complete obs.constraints=observed", ergm(nwc~edges+triangle, obs.constraints=~observed, control=cc))
tr("complete edges-only constraints=observed", ergm(nwc~edges, constraints=~observed, control=cc))
tr("missing constraints=observed", ergm(nwm~edges+triangle, constraints=~observed, control=cc))
tr("missing obs.constraints=observed", ergm(nwm~edges+triangle, obs.constraints=~observed, control=cc))
tr("missing edges constraints=observed", ergm(nwm~edges, constraints=~observed, control=cc))
tr("missing edges obs.constraints=observed", ergm(nwm~edges, obs.constraints=~observed, control=cc))

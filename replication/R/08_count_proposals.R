# Proposals per fit (manual of nwergm, Appendix C): counts the Metropolis-Hastings proposals of an ergm fit (default settings), including the
# burn-in and the bridge sampling of the log-likelihood, by a trace on ergm's sampler (ergm_MCMC_slave). One untimed
# warm-up fit, then seeds 1 to 3.   Rscript R/08_count_proposals.R Lazega
# Prints "@@EFF ergm <id> <seed> <seconds> <proposals> <iterations> <final sample size>".
args <- commandArgs(TRUE); id <- args[1]
source("R/common.R")
f <- bench_model(id)
tot <- 0
trace("ergm_MCMC_slave", where = asNamespace("ergm"), print = FALSE, tracer = quote({
  b <- if (is.null(burnin)) control$MCMC.burnin else burnin
  n <- if (is.null(samplesize)) control$MCMC.samplesize else samplesize
  i <- if (is.null(interval)) control$MCMC.interval else interval
  assign("tot", get("tot", globalenv()) + b + n * i, globalenv())
}))
set.seed(99); invisible(ergm(f))
for (s in 1:3) {
  tot <- 0
  set.seed(s); t0 <- proc.time()[3]; fit <- ergm(f); secs <- proc.time()[3] - t0
  cat("@@EFF ergm", id, s, sprintf("%.3f", secs), sprintf("%.0f", tot), fit$iterations,
      nrow(as.matrix(fit$sample)), "\n")
}

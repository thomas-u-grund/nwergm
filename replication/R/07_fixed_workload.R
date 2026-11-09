# Time for a fixed amount of work (manual of nwergm, Appendix C): the same amount of sampling in both programs. For benchmark <id>: one MCMLE iteration
# from the MPLE with a fixed sample (4,000 draws, interval 1,024, burn-in 16,384), the adaptive sample size switched
# off and no log-likelihood. The number of proposals is counted by a trace on ergm's sampler.
# Prints the seconds, the proposals and the microseconds per proposal.   Rscript R/07_fixed_workload.R Lazega
args <- commandArgs(TRUE); id <- args[1]
source("R/common.R")
f <- bench_model(id)
ctl <- control.ergm(MCMLE.maxit = 1, MCMC.samplesize = 4000, MCMC.interval = 1024, MCMC.burnin = 16384,
                    MCMLE.effectiveSize = NULL)
tot <- 0
trace("ergm_MCMC_slave", where = asNamespace("ergm"), print = FALSE, tracer = quote({
  b <- if (is.null(burnin)) control$MCMC.burnin else burnin
  n <- if (is.null(samplesize)) control$MCMC.samplesize else samplesize
  i <- if (is.null(interval)) control$MCMC.interval else interval
  assign("tot", get("tot", globalenv()) + b + n * i, globalenv())
}))
set.seed(99); invisible(suppressWarnings(ergm(f, control = ctl, eval.loglik = FALSE)))   # warm-up
tot <- 0
set.seed(1); t0 <- proc.time()[3]
invisible(suppressWarnings(ergm(f, control = ctl, eval.loglik = FALSE)))
secs <- proc.time()[3] - t0
cat("@@FIXED R", id, sprintf("%.3f", secs), sprintf("%.0f", tot), sprintf("%.3f", 1e6 * secs / tot), "\n")

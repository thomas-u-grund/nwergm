# The samplers at given coefficients (manual of nwergm, Appendix C): the samplers at given coefficients. For benchmark <id>, ergm is fitted once (seed 1) and
# its coefficients are written to results/theta_<id>.csv. Then, five times (seeds 11 to 15), 1,000 networks are drawn
# at these coefficients from the observed network (burn-in 16,384, interval 1,024) and the mean of each statistic is
# written to results/sampler_ergm_<id>.csv; the draws of the first run go to results/draws_ergm_<id>.csv. stata/05_sampler_check.do does the same with nwergm, and
# tools/compare_sampler.py compares the two.   Rscript R/05_sampler_check.R Lazega   (about 1 minute)
args <- commandArgs(TRUE); id <- args[1]
source("R/common.R")
f <- bench_model(id)
set.seed(1); fit <- ergm(f, verbose = FALSE)
theta <- coef(fit)
write.csv(data.frame(term = names(theta), b = unname(theta)), file.path("results", paste0("theta_", id, ".csv")), row.names = FALSE)
ctl <- control.simulate.formula(MCMC.burnin = 16384, MCMC.interval = 1024)
out <- NULL
for (s in 11:15) {
  set.seed(s)
  S <- simulate(f, coef = theta, nsim = 1000, control = ctl, output = "stats")
  out <- rbind(out, data.frame(run = s, stat = seq_len(ncol(S)), mean = unname(colMeans(S))))
  if (s == 11) write.table(S, file.path("results", paste0("draws_ergm_", id, ".csv")), sep = ",", row.names = FALSE, col.names = FALSE)
}
write.csv(out, file.path("results", paste0("sampler_ergm_", id, ".csv")), row.names = FALSE)
cat("written", file.path("results", paste0("sampler_ergm_", id, ".csv")), "\n")

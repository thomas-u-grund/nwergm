# 20 further runs (seeds 31 to 50) of R/05_sampler_check.R for one model, at the coefficients of results/theta_<id>.csv
args <- commandArgs(TRUE); id <- args[1]
source("R/common.R")
f <- bench_model(id)
theta <- read.csv(file.path("results", paste0("theta_", id, ".csv")))$b
ctl <- control.simulate.formula(MCMC.burnin = 16384, MCMC.interval = 1024)
out <- NULL
for (s in 31:50) {
  set.seed(s)
  S <- simulate(f, coef = theta, nsim = 1000, control = ctl, output = "stats")
  out <- rbind(out, data.frame(run = s, stat = seq_len(ncol(S)), mean = unname(colMeans(S))))
}
write.csv(out, file.path("results", paste0("sampler20_ergm_", id, ".csv")), row.names = FALSE)

# Estimates of the eight benchmark models of Table 3 with ergm, seeds 1 to 5 (default settings, as timed in Table 3).
# Writes results/bench_est_ergm.csv; tools/compare_bench_estimates.py compares it with the nwergm results.
# Run time: about 5 minutes.
source("R/common.R"); versions()
out <- list()
for (id in c("B1", "B2", "B3", "B4", "B5", "B6", "Lazega", "Mesa")) {
  f <- bench_model(id)
  for (s in 1:5) {
    set.seed(s); fit <- ergm(f, verbose = FALSE)
    b <- coef(fit); se <- sqrt(diag(vcov(fit)))
    out[[length(out) + 1]] <- data.frame(model = id, seed = s, term = seq_along(b), b = unname(b), se = unname(se),
                                         iterations = if (is.null(fit$iterations)) NA else fit$iterations)
  }
}
write.csv(do.call(rbind, out), "results/bench_est_ergm.csv", row.names = FALSE)
cat("written results/bench_est_ergm.csv\n")

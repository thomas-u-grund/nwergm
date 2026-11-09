# Table 3 and Figure 6, R side: one timed ergm fit of benchmark <id> with seed <r>, after one untimed warm-up fit.
#   Rscript R/03_benchmark_fit.R Lazega 1
# Prints "@@B8 <id> <seed> <seconds> <iterations>". tools/run_benchmark.sh calls it for all models and seeds.
args <- commandArgs(TRUE); id <- args[1]; r <- as.integer(args[2])
source("R/common.R")
f <- bench_model(id)
set.seed(99); invisible(ergm(f, verbose = FALSE))
set.seed(r); t0 <- proc.time()[3]; fit <- ergm(f, verbose = FALSE); s <- proc.time()[3] - t0
cat("@@B8", id, r, sprintf("%.3f", s), if (!is.null(fit$iterations)) fit$iterations else NA, "\n")

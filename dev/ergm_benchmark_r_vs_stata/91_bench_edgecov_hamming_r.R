# Harmonisation unit 160 benchmark: 100-node undirected, edges +
# edgecov(covnet) + hamming(refnet), fit via Statnet's ergm() on the
# SAME exported networks 90_bench_edgecov_hamming_stata.do generated,
# using ergm()'s own default settings (MPLE, since the model is
# dyad-independent - matches nwergm's own default routing).

suppressMessages(library(ergm))

d <- "/Users/tgrund/FILES_NEW/SOFTWARE/nwcommands/dev/ergm_benchmark_r_vs_stata"
mat_main <- as.matrix(read.csv(file.path(d, "bench_ech_main.csv"), header = FALSE))
mat_cov  <- as.matrix(read.csv(file.path(d, "bench_ech_cov.csv"), header = FALSE))
mat_ref  <- as.matrix(read.csv(file.path(d, "bench_ech_ref.csv"), header = FALSE))
stopifnot(dim(mat_main) == c(100, 100), dim(mat_cov) == c(100, 100), dim(mat_ref) == c(100, 100))

net <- network(mat_main, directed = FALSE, matrix.type = "adjacency")

set.seed(999)
t0 <- Sys.time()
fit <- ergm(net ~ edges + edgecov(mat_cov) + hamming(mat_ref))
t1 <- Sys.time()
elapsed <- as.numeric(difftime(t1, t0, units = "secs"))

cat("\n======================================\n")
cat("R ergm: 100-node undirected, edges + edgecov() + hamming()\n")
cat("======================================\n")
cat(sprintf("Wall time: %.3f seconds\n", elapsed))
print(coef(fit))
print(summary(fit))

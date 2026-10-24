# Bipartite speed benchmark, R side: SAME 60x40 network
# (dev/ergm_benchmark_bipartite/bipnet.csv) and SAME model
# (edges + b1star(2)) as 02_bench_stata.do, fit via ergm()'s own true
# defaults (no control.ergm() overrides) for a fair default-vs-default
# comparison.
suppressMessages(library(ergm))

d <- "/Users/tgrund/FILES_NEW/SOFTWARE/nwcommands/dev/ergm_benchmark_bipartite"
el <- read.csv(file.path(d, "bipnet.csv"))
n1 <- 60; n2 <- 40; n <- n1 + n2

net <- network.initialize(n, bipartite = n1, directed = FALSE)
net <- add.edges(net, el$person, n1 + el$event)
cat("ties:", network.edgecount(net), "\n")

set.seed(999)
t0 <- Sys.time()
fit <- ergm(net ~ edges + b1star(2))
t1 <- Sys.time()
elapsed <- as.numeric(difftime(t1, t0, units = "secs"))

cat("\n======================================\n")
cat("R ergm: 60x40 bipartite, edges + b1star(2), true defaults\n")
cat("======================================\n")
cat(sprintf("Wall time: %.3f seconds\n", elapsed))
print(coef(fit))
print(summary(fit))

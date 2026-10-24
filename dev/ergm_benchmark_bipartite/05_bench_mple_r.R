# MPLE-side R counterpart to 04_bench_mple_stata.do: same 60x40
# network, edges + b1cov(age), estimate="MPLE" (no MCMC at all).
suppressMessages(library(ergm))

d <- "/Users/tgrund/FILES_NEW/SOFTWARE/nwcommands/dev/ergm_benchmark_bipartite"
el <- read.csv(file.path(d, "bipnet.csv"))
n1 <- 60; n2 <- 40; n <- n1 + n2

net <- network.initialize(n, bipartite = n1, directed = FALSE)
net <- add.edges(net, el$person, n1 + el$event)

set.seed(1)
age <- runif(n1, 20, 60)
set.vertex.attribute(net, "age", c(age, rep(NA, n2)))

t0 <- Sys.time()
fit <- ergm(net ~ edges + b1cov("age"), estimate = "MPLE")
t1 <- Sys.time()
elapsed <- as.numeric(difftime(t1, t0, units = "secs"))

cat("\n======================================\n")
cat("R ergm: 60x40 bipartite, edges + b1cov(age), estimate=MPLE\n")
cat("======================================\n")
cat(sprintf("Wall time: %.3f seconds\n", elapsed))
print(coef(fit))

# Real-world nwergm benchmark: US airport route network, edges + mutual,
# fit via Statnet's ergm() on the SAME exported edgelist
# 01_prep_network.do generated, using ergm()'s own default settings.

suppressMessages(library(ergm))

d <- "/Users/tgrund/FILES_NEW/SOFTWARE/nwcommands/dev/ergm_benchmark_usair"
el <- read.csv(file.path(d, "usair_edgelist.csv"), header = FALSE)
stopifnot(ncol(el) == 2)

net <- network.initialize(549, directed = TRUE)
net <- add.edges(net, el[[1]], el[[2]])
stopifnot(network.edgecount(net) == 5450)

set.seed(999)
t0 <- Sys.time()
fit <- ergm(net ~ edges + mutual)
t1 <- Sys.time()
elapsed <- as.numeric(difftime(t1, t0, units = "secs"))

cat("\n======================================\n")
cat("R ergm: US airport routes, 549 nodes, 5450 ties, edges + mutual\n")
cat("======================================\n")
cat(sprintf("Wall time: %.3f seconds\n", elapsed))
print(coef(fit))
print(summary(fit))

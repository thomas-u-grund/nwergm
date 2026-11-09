# Section 9.3, models with one coefficient per node: edges + sender + receiver on a random directed network of
# 400 nodes (data/net400_edges.csv, written by stata/04_per_node.do), fitted by pseudolikelihood (= likelihood).
# Compares the estimates with results/per_node_nwergm.csv. Run time: about 10 minutes.
source("R/common.R"); versions()
E <- as.matrix(read.csv("data/net400_edges.csv", header = FALSE))
g <- network.initialize(400, directed = TRUE); g <- add.edges(g, E[, 1], E[, 2])
cat("nodes", network.size(g), " ties", network.edgecount(g), "\n")
t0 <- proc.time()[3]
fit <- ergm(g ~ edges + sender + receiver)
cat("ergm seconds:", round(proc.time()[3] - t0, 1), "\n")
b <- coef(fit)
S <- read.csv("results/per_node_nwergm.csv")
d <- abs(unname(b) - S$b)
cat("coefficients:", length(b), "  largest absolute difference to nwergm:", signif(max(d, na.rm = TRUE), 3), "\n")
write.csv(data.frame(term = names(b), b = unname(b)), "results/per_node_ergm.csv", row.names = FALSE)

suppressMessages({library(ergm); library(network)})
L <- as.matrix(read.csv("laz_adj.csv", header = FALSE)); L[is.na(L)] <- 0
nl <- network(L, directed = TRUE); nd <- read.csv("laz_nodes.csv")
nl %v% "prac" <- as.integer(factor(nd$practice)); nl %v% "seniority" <- nd$seniority
f2 <- nl ~ edges + mutual + nodematch("prac") + nodeicov("seniority") + gwesp(0.5, fixed = TRUE)
out <- NULL
for (s in 1:5) { t0 <- proc.time()[3]; fit <- ergm(f2, control = control.ergm(seed = s)); out <- rbind(out, data.frame(setting = "ergm default", seed = s, seconds = round(proc.time()[3] - t0, 2), iterations = fit$iterations)) }
write.csv(out, "r_timing.csv", row.names = FALSE)

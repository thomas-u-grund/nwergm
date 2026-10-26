suppressMessages({library(ergm); library(network)})
L <- as.matrix(read.csv("laz_adj.csv", header = FALSE)); L[is.na(L)] <- 0
nl <- network(L, directed = TRUE); nd <- read.csv("laz_nodes.csv")
nl %v% "prac" <- as.integer(factor(nd$practice)); nl %v% "seniority" <- nd$seniority
f2 <- nl ~ edges + mutual + nodematch("prac") + nodeicov("seniority") + gwesp(0.5, fixed = TRUE)
cf <- read.csv("sim_coef.csv")$coef
for (s in 21:23) { set.seed(s)
  sm <- simulate(f2, coef = cf, nsim = 4000, output = "stats", control = control.simulate.formula(MCMC.burnin = 16384, MCMC.interval = 1024))
  write.csv(as.data.frame(unclass(sm)), paste0("r_sim_", s, ".csv"), row.names = FALSE) }

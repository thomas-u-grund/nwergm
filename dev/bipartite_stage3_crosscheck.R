# Real R ergm crosscheck for harmonisation unit 157 (bipartite Stage 3:
# bdegree1()/bdegree2()/bstar1()/bstar2() - R ergm's own b1degree()/
# b2degree()/b1star()/b2star()). No fabricated numbers - every value
# below is real ergm 4.12.0 MCMLE output.
#
# Two networks, not one: the 6x4 (11-tie) network Stage 1/2 already use
# is too small/sparse to identify b1star(2)/b2star(2) at all (confirmed
# directly - R itself reports "linear dependence... may indicate the
# model is nonidentifiable" and "The MPLE does not exist!" on it, the
# same genuine small-network degeneracy this project has hit before with
# curved GWESP/gwnsp - not an nwergm-specific defect). b1degree(1)/
# b2degree(2) DO identify cleanly on the 6x4 network individually, but
# even THOSE two together are degenerate on this network ("Unconstrained
# MCMC sampling did not mix at all") - so every term below is certified
# as its own separate edges+term model, matching how this project
# established gwnsp's own identification (try until a real one is
# found), not forcing a multi-term fit neither implementation can
# support on data this small.
suppressMessages(library(ergm))
options(digits=17)

n1 <- 6; n2 <- 4; n <- n1 + n2
netA <- network.initialize(n, bipartite = n1, directed = FALSE)
elA <- matrix(c(
  1, n1+1, 1, n1+2, 2, n1+1, 2, n1+3, 3, n1+2, 3, n1+3,
  4, n1+4, 5, n1+4, 5, n1+1, 6, n1+2, 6, n1+4
), ncol = 2, byrow = TRUE)
netA <- add.edges(netA, elA[,1], elA[,2])

cat("=== netA (6x4, 11 ties): edges + b1degree(1) ===\n")
fitA1 <- ergm(netA ~ edges + b1degree(1), estimate = "MLE",
              control = control.ergm(seed = 1, MCMC.samplesize = 5000,
                                      MCMC.burnin = 5000, MCMC.interval = 50))
print(coef(fitA1))

cat("\n=== netA (6x4, 11 ties): edges + b2degree(2) ===\n")
fitA2 <- ergm(netA ~ edges + b2degree(2), estimate = "MLE",
              control = control.ergm(seed = 1, MCMC.samplesize = 5000,
                                      MCMC.burnin = 5000, MCMC.interval = 50))
print(coef(fitA2))

set.seed(77)
n1B <- 8; n2B <- 6; nB <- n1B + n2B
netB <- network.initialize(nB, bipartite = n1B, directed = FALSE)
elB <- do.call(rbind, lapply(1:n1B, function(i) {
  k <- sample(2:4, 1)
  js <- sample((n1B+1):(n1B+n2B), k)
  cbind(i, js)
}))
netB <- add.edges(netB, elB[,1], elB[,2])
cat("\nnetB edgelist (person_id event_id, event_id already offset by n1B):\n")
print(elB)

cat("\n=== netB (8x6, ", network.edgecount(netB), " ties): edges + b1star(2) ===\n")
fitB1 <- ergm(netB ~ edges + b1star(2), estimate = "MLE",
              control = control.ergm(seed = 77, MCMC.samplesize = 3000,
                                      MCMC.burnin = 3000, MCMC.interval = 50))
print(coef(fitB1))

cat("\n=== netB (8x6): edges + b2star(2) ===\n")
fitB2 <- ergm(netB ~ edges + b2star(2), estimate = "MLE",
              control = control.ergm(seed = 77, MCMC.samplesize = 3000,
                                      MCMC.burnin = 3000, MCMC.interval = 50))
print(coef(fitB2))

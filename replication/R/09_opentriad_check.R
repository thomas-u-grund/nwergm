# opentriad: compare the change statistics that ergm uses in estimation with the
# differences of ergm's own summary statistic (g(y with tie ij) - g(y without tie ij)),
# and fit edges + opentriad by pseudolikelihood. Run with an ergm development version that
# contains commit 12e606d of 10 November 2026, the fix of statnet/ergm#666 (we used 4.13.0-8255
# from statnet.r-universe.dev):
# 0 of 66 dyads differ, and the estimates equal nwergm's (edges -1.901886, opentriad .2923868).
# Run: Rscript 09_opentriad_check.R
suppressPackageStartupMessages(library(ergm))
set.seed(1)
m <- matrix(0, 12, 12); m[upper.tri(m)] <- rbinom(66, 1, 0.3); m <- m + t(m)
y <- network(m, directed = FALSE)
cat("ergm", as.character(packageVersion("ergm")), "\n")
cat("summary(y ~ opentriad):", summary(y ~ opentriad), "\n")
# change statistics used by the pseudolikelihood, one row per dyad (tail, head, statistic)
mp <- ergmMPLE(y ~ opentriad, output = "dyadlist")$predictor
ndiff <- 0; maxdiff <- 0
for (r in seq_len(nrow(mp))) {
  i <- mp[r, 1]; j <- mp[r, 2]
  yp <- y; yp[i, j] <- 1
  ym <- y; ym[i, j] <- 0
  d <- summary(yp ~ opentriad) - summary(ym ~ opentriad)
  dif <- abs(mp[r, 3] - d)
  if (dif > 1e-9) ndiff <- ndiff + 1
  maxdiff <- max(maxdiff, dif)
}
cat("dyads:", nrow(mp), " where the change statistic of ergmMPLE() differs from the difference of summary():",
    ndiff, " largest difference:", maxdiff, "\n")
fit <- ergm(y ~ edges + opentriad, estimate = "MPLE")
print(summary(fit)$coefficients)

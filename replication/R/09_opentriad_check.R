# opentriad: compare the change statistics that ergm uses in estimation with the
# differences of ergm's own summary statistic (g(y with tie ij) - g(y without tie ij)).
# Needs R 4.6.0 and ergm 4.12.0 (00_install.R). Run: Rscript 09_opentriad_check.R
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

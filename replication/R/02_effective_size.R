# Section 7.2 / 9.3 of the article: effective sample size of ergm's final sample on the Lazega advice model.
source("R/common.R"); suppressMessages(library(coda)); versions()
g <- lazega()
for (s in 1:3) {
  set.seed(s)
  fit <- ergm(lazega_model(g))
  cat("seed", s, "draws:", nrow(as.matrix(fit$sample)), " ESS:", round(effectiveSize(fit$sample), 1), "\n")
}

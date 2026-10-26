# Comparison of nwergm with R's ergm (chapter "Validation against ergm").
# Run from manual/ex/r after ex91_compare_stata.do and ex90_export_for_r.do:  Rscript compare.R
# Writes r_fits.csv, r_stats.csv.
suppressMessages({library(ergm); library(network)})
cat("ergm", as.character(packageVersion("ergm")), "\n")
rd <- function(f, ...) read.csv(f, header = FALSE, ...)
out <- NULL
add <- function(label, fit) {
  s <- summary(fit)$coefficients
  out <<- rbind(out, data.frame(fit = label, term = rownames(s), est = s[, "Estimate"], se = s[, "Std. Error"]))
}
## Florentine marriages
A <- as.matrix(rd("flo_adj.csv")); A[is.na(A)] <- 0
nw <- network(A, directed = FALSE)
nw %v% "wealth" <- read.csv("flo_nodes.csv")$wealth
add("flo_mple", ergm(nw ~ edges + nodecov("wealth"), estimate = "MPLE"))
## Lazega
L <- as.matrix(rd("laz_adj.csv")); L[is.na(L)] <- 0
nl <- network(L, directed = TRUE)
nd <- read.csv("laz_nodes.csv")
nl %v% "prac" <- as.integer(factor(nd$practice))
nl %v% "seniority" <- nd$seniority
f1 <- nl ~ edges + mutual + nodematch("prac") + nodeicov("seniority")
add("laz_mple", ergm(f1, estimate = "MPLE"))
f2 <- nl ~ edges + mutual + nodematch("prac") + nodeicov("seniority") + gwesp(0.5, fixed = TRUE)
st <- data.frame(net = "lazega", term = colnames(summary(f2, response = NULL) |> as.matrix() |> t()), obs = as.numeric(summary(f2)))
write.csv(st, "r_stats.csv", row.names = FALSE)
for (s in 1:5) {
  t0 <- proc.time()[3]
  fit <- ergm(f2, control = control.ergm(seed = s))
  cat("lazega seed", s, "elapsed", proc.time()[3] - t0, "iterations", fit$iterations, "\n")
  add(paste0("laz_mcmle_", s), fit)
}
## simulated two-mode network
B <- as.matrix(rd("clubs_inc.csv"))
kind <- read.csv("clubs_kind.csv")$kind1
nb <- network(B, bipartite = nrow(B), directed = FALSE, matrix.type = "bipartite")
nb %v% "kind" <- kind
add("clubs_mple", ergm(nb ~ edges + nodemix("kind"), estimate = "MPLE"))
add("clubs_mple2", ergm(nb ~ edges + nodemix("kind") + b2degree(5:6) + b1star(2), estimate = "MPLE"))
write.csv(out, "r_fits.csv", row.names = FALSE)

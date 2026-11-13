# R reference for offset() in models with a curved term (ergm 4.12.0): Florentine marriages and Lazega friendship.
# usage (from dev/):  Rscript offset_curved_ref.R  -> offset_curved_r.csv
# Then run offset_curved_run.do in Stata (writes offset_curved_stata.csv) and  Rscript offset_curved_ref.R compare
suppressMessages({library(ergm); library(network)})
args <- commandArgs(TRUE)
if (length(args) && args[1] == "compare") {
  r <- read.csv("offset_curved_r.csv"); s <- read.csv("offset_curved_stata.csv")
  m <- merge(r, s, by = c("case", "est", "seed", "pos"), suffixes = c(".r", ".s"))
  m$dcoef <- m$coef.s - m$coef.r
  m$dse <- m$se.s - m$se.r
  m$z <- ifelse(m$se.r > 0, m$dcoef / m$se.r, NA)
  print(m[order(m$case, m$est, m$seed, m$pos), c("case", "est", "seed", "term.s", "coef.r", "coef.s", "se.r", "se.s", "z", "ll.r", "ll.s")], digits = 6, row.names = FALSE)
  quit(save = "no")
}
cat("ergm", as.character(packageVersion("ergm")), "\n")
data(florentine)
L <- as.matrix(read.csv("../manual/ex/r/laz_adj.csv", header = FALSE)); L[is.na(L)] <- 0
nl <- network(L, directed = TRUE)
out <- NULL
add <- function(case, est, seed, fit) {
  s <- summary(fit)$coefficients
  ll <- tryCatch(as.numeric(logLik(fit)), error = function(e) NA)
  out <<- rbind(out, data.frame(case = case, est = est, seed = seed, pos = seq_len(nrow(s)), term = rownames(s),
    coef = s[, "Estimate"], se = s[, "Std. Error"], ll = ll))
}
cases <- list(
  # Florentine marriages, undirected
  fA = list(net = "flo", f = flomarriage ~ edges + offset(gwesp(fixed = FALSE)), oc = c(0.5, 0.3), mle = TRUE),
  fB = list(net = "flo", f = flomarriage ~ edges + offset(gwesp(fixed = FALSE), which = 2), oc = 0.3, mle = TRUE),
  fC = list(net = "flo", f = flomarriage ~ edges + offset(gwesp(fixed = FALSE), which = 1), oc = 0.5, mle = FALSE),
  fD = list(net = "flo", f = flomarriage ~ offset(edges) + gwesp(fixed = FALSE), oc = -2, mle = FALSE),
  fE = list(net = "flo", f = flomarriage ~ edges + offset(gwesp(0.5, fixed = TRUE)), oc = 0.5, mle = TRUE),
  # Lazega friendship, directed (gwesp type OTP)
  lB = list(net = "laz", f = nl ~ edges + mutual + offset(gwesp(fixed = FALSE), which = 2), oc = 0.5, mle = TRUE),
  lA = list(net = "laz", f = nl ~ edges + mutual + offset(gwesp(fixed = FALSE)), oc = c(0.8, 0.5), mle = TRUE),
  lD = list(net = "laz", f = nl ~ edges + offset(mutual) + gwesp(fixed = FALSE), oc = 2, mle = FALSE),
  lC = list(net = "laz", f = nl ~ edges + offset(mutual) + offset(gwesp(fixed = FALSE), which = 1), oc = c(2, 0.8), mle = FALSE)
)
for (nm in names(cases)) {
  cs <- cases[[nm]]
  add(nm, "mple", 0, ergm(cs$f, offset.coef = cs$oc, estimate = "MPLE"))
  if (cs$mle) for (sd in 1:3) add(nm, "mcmle", sd, ergm(cs$f, offset.coef = cs$oc, control = control.ergm(seed = sd)))
}
write.csv(out, "offset_curved_r.csv", row.names = FALSE)
print(out, digits = 7)

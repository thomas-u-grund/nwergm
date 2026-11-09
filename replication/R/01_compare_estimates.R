# Table 4 of the article, R side: ergm on the same networks and models as stata/01_compare_estimates.do,
# default settings, several seeds. Writes results/cmp_ergm.csv. Run time: about 10 minutes.
source("R/common.R"); versions()
out <- list()
run <- function(model, seed, expr) {
  set.seed(seed)
  t0 <- proc.time()[3]
  fit <- tryCatch(eval(expr), error = function(e) { cat(model, seed, "ERROR:", conditionMessage(e), "\n"); NULL })
  secs <- proc.time()[3] - t0
  if (is.null(fit)) return(invisible())
  s <- summary(fit)$coefficients
  out[[length(out) + 1]] <<- data.frame(model = model, seed = seed, term = rownames(s), b = s[, "Estimate"],
    se = s[, "Std. Error"], secs = secs, conv = 1, stringsAsFactors = FALSE)
  cat(model, seed, round(secs, 2), "s\n")
}
# a 5-node directed network
toy <- network(matrix(c(0,1,1,0,0, 1,0,0,0,0, 0,0,0,1,0, 0,0,0,0,1, 1,0,0,0,0), 5, byrow = TRUE), directed = TRUE)
for (s in 1:10) run("toy", s, quote(ergm(toy ~ edges + mutual)))
# Florentine marriages
fm <- network(rd("flo_marriage.csv"), directed = FALSE)
fa <- read.csv("data/flo_attr.csv"); fm %v% "seat" <- fa$seat; fm %v% "wealth" <- fa$wealth
for (s in 1:10) run("flo_gwesp", s, quote(ergm(fm ~ edges + nodecov("wealth") + gwesp(0.5, fixed = TRUE))))
run("flo_mple", 1, quote(ergm(fm ~ edges + nodecov("wealth"))))
# Lazega advice and friendship
adv <- lazega("lazega_adv.csv"); fr <- lazega("lazega_fr.csv")
run("lazega_dindep", 1, quote(ergm(adv ~ edges + nodematch("officen") + nodematch("practicen") + nodeofactor("statusn") + nodeifactor("statusn"))))
for (s in 1:5) run("lazega_final", s, quote(ergm(lazega_model(adv))))
for (s in 1:5) run("lazega_sym", s, quote(ergm(fr ~ edges + mutual + nodematch("practicen") + Symmetrize(~triangle, rule = "strong"))))
# Southern women (two-mode)
dv <- rd("davis_full.csv"); da <- read.csv("data/davis_attr.csv")
i1 <- which(da$X_nwmode == 1); i2 <- which(da$X_nwmode == 2)
dn <- network(dv[i1, i2], directed = FALSE, bipartite = length(i1), matrix.type = "bipartite")
dn %v% "titlen" <- c(da$titlen[i1], rep(NA, length(i2)))
for (s in 1:10) run("davis", s, quote(ergm(dn ~ edges + b1factor("titlen") + gwb2degree(1, fixed = TRUE))))
# Faux Mesa High
m <- mesa()
for (s in 1:5) run("mesa_gwesp", s, quote(ergm(m ~ edges + nodematch("grade") + nodematch("racen") + gwesp(0.25, fixed = TRUE))))
for (s in 1:3) run("mesa_curved", s, quote(ergm(m ~ edges + nodematch("grade") + nodematch("racen") + gwesp(0.25, fixed = FALSE))))
dir.create("results", showWarnings = FALSE)
write.csv(do.call(rbind, out), "results/cmp_ergm.csv", row.names = FALSE)
cat("written results/cmp_ergm.csv\n")

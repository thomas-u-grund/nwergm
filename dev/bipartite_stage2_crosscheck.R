# Real R ergm crosscheck for harmonisation unit 156 (bipartite Stage 2:
# b1cov()/b2cov()/b1factor()/b2factor()). Builds the IDENTICAL bipartite
# network and covariates used in nwergm's own end-to-end smoke test
# (cscripts/test_nwergm_bipartite.do), fits with real ergm 4.12.0
# estimate="MPLE", and prints coefficients for direct comparison against
# nwergm's own fit - no fabricated numbers, this is the real reference.
suppressMessages(library(ergm))
options(digits=17)

n1 <- 6  # persons (mode 1)
n2 <- 4  # events (mode 2)
n  <- n1 + n2

net <- network.initialize(n, bipartite = n1, directed = FALSE)

# edges (person, event) -> (person_id, n1 + event_id), matching
# cscripts/test_nwergm_bipartite.do's own edgelist exactly.
el <- matrix(c(
  1, n1+1,
  1, n1+2,
  2, n1+1,
  2, n1+3,
  3, n1+2,
  3, n1+3,
  4, n1+4,
  5, n1+4,
  5, n1+1,
  6, n1+2,
  6, n1+4
), ncol = 2, byrow = TRUE)
net <- add.edges(net, el[,1], el[,2])

age <- c(25, 30, 45, 22, 60, 35)
grp <- c(1, 1, 2, 2, 1, 2)
size <- c(10, 40, 5, 20)
cat_ <- c(1, 2, 1, 2)

set.vertex.attribute(net, "age", c(age, rep(NA, n2)))
set.vertex.attribute(net, "grp", c(grp, rep(NA, n2)))
set.vertex.attribute(net, "size", c(rep(NA, n1), size))
set.vertex.attribute(net, "cat", c(rep(NA, n1), cat_))

cat("=== MPLE: bipartite edges + b1cov(age) + b2cov(size) + b1factor(grp) + b2factor(cat) ===\n")
fit <- ergm(net ~ edges + b1cov("age") + b2cov("size") + b1factor("grp") + b2factor("cat"),
            estimate = "MPLE")
print(coef(fit))

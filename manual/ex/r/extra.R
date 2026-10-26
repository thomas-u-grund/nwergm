suppressMessages({library(ergm); library(network)})
L <- as.matrix(read.csv("laz_adj.csv", header = FALSE)); L[is.na(L)] <- 0
nl <- network(L, directed = TRUE); nd <- read.csv("laz_extra_nodes.csv")
nl %v% "prac" <- nd$prac; nl %v% "seniority" <- nd$seniority; nl %v% "age" <- nd$age; nl %v% "off" <- nd$off
C <- as.matrix(read.csv("laz_cow.csv", header = FALSE)); C[is.na(C)] <- 0
AM <- matrix(c(0, 1, 0.5, 2), 2, 2)   # AM[1,2] = 0.5, AM[2,1] = 1 as the Stata matrix (0, .5 \ 1, 2)
specs <- list("attrcov(prac, mat(AM))" = ~ edges + attrcov("prac", AM), "dyadcov(lazega_cow)" = ~ edges + dyadcov(C), "mm(prac)" = ~ edges + mm("prac"),
  "nodeicovrange(seniority)" = ~ edges + nodeicovrange("seniority"), "nodeofactordistinct(off)" = ~ edges + nodeofactordistinct("off"),
  "nodeocovrange(age)" = ~ edges + nodeocovrange("age"), "nodefactordistinct(off)" = ~ edges + nodefactordistinct("off"))
out <- NULL
for (nm in names(specs)) {
  f <- update.formula(specs[[nm]], nl ~ .)
  fit <- suppressMessages(ergm(f, estimate = "MPLE"))
  s <- summary(fit)$coefficients
  st <- as.numeric(summary(f))
  out <- rbind(out, data.frame(fit = gsub(",", ";", nm), kind = "coef", term = rownames(s), value = s[, 1], se = s[, 2]),
                    data.frame(fit = gsub(",", ";", nm), kind = "obs", term = rownames(s), value = st, se = NA))
}
write.csv(out, "r_extra.csv", row.names = FALSE)

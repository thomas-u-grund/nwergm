# Shared helpers. All scripts are run from the folder replication/ (the folder of README.md):
#   Rscript R/01_compare_estimates.R
suppressMessages(library(ergm))
rd <- function(f) as.matrix(read.csv(file.path("data", f), header = FALSE))
versions <- function() cat("R", R.version.string, "| ergm", as.character(packageVersion("ergm")),
  "| network", as.character(packageVersion("network")), "\n")
lazega <- function(file = "lazega_adv.csv") {
  la <- read.csv(file.path("data", "lazega_attr.csv"))
  g <- network(rd(file), directed = TRUE)
  g %v% "officen" <- la$officen; g %v% "practicen" <- la$practicen; g %v% "statusn" <- la$statusn
  g
}
mesa <- function() {
  ma <- read.csv(file.path("data", "mesa_attr.csv"))
  g <- network(rd("mesa.csv"), directed = FALSE)
  g %v% "grade" <- ma$grade; g %v% "racen" <- ma$racen
  g
}
lazega_model <- function(g) g ~ edges + mutual + nodematch("officen") + nodematch("practicen") +
  nodeofactor("statusn") + nodeifactor("statusn") + gwesp(0.5, fixed = TRUE)
# the eight benchmark models of Table 3 (used by the scripts 03, 05, 06, 07 and 08)
bench_model <- function(id) {
  attr1 <- function(f) read.csv(file.path("data", f), header = FALSE)[[1]]
  if (id == "B1") { g <- network(rd("bench_net.csv"), directed = TRUE); return(g ~ edges + mutual) }
  if (id == "B2") { g <- network(rd("net100dir.csv"), directed = TRUE); g %v% "grp" <- attr1("attr100dir.csv"); return(g ~ edges + mutual + nodematch("grp")) }
  if (id == "B3") { g <- network(rd("net100undir.csv"), directed = FALSE); return(g ~ edges + gwesp(0.5, fixed = TRUE)) }
  if (id == "B4") { g <- network(rd("net500.csv"), directed = FALSE); g %v% "grp" <- attr1("attr500.csv"); return(g ~ edges + nodematch("grp") + gwesp(0.5, fixed = TRUE)) }
  if (id == "B5") { g <- network(rd("net1000.csv"), directed = TRUE); g %v% "grp" <- attr1("attr1000.csv"); return(g ~ edges + mutual + nodematch("grp")) }
  if (id == "B6") { g <- network(rd("net_sp.csv"), directed = FALSE); return(g ~ edges + gwesp(0.5, fixed = TRUE) + gwnsp(0.5, fixed = TRUE)) }
  if (id == "Lazega") { g <- lazega(); return(lazega_model(g)) }
  if (id == "Mesa") { g <- mesa(); return(g ~ edges + nodematch("grade") + nodematch("racen") + gwesp(0.25, fixed = TRUE)) }
  stop("unknown benchmark ", id)
}

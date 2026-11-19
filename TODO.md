# nwergm: open items

## nwergm ego (egocentrically sampled data; R: ergm.ego 1.1.4)

Done in 1.10.0: the statistics `edges`, `degree`, `degrange`, `concurrent`, `nodefactor`, `nodematch` (with `diff`), `nodecov`, `absdist` (R: `absdiff`), the survey
covariance, the fit on the pseudopopulation with the network size adjustment, `estat gof` (model, degree), `nwergm simulate` at the size of the pseudopopulation.

Not done, with the reason:

- **Terms that need the ties among the alters** (`esp`, `gwesp`, `triangle`, `transitiveties`, `cyclicalties`): the ego data model here has no alter-alter ties table; it needs a
  third frame (`aaties`) and per-ego statistics from it (R: `EgoStat.esp` etc.), and R warns that the variance theory is not settled for curved terms such as `gwesp`.
  The `nwergm` sampler fits these terms already; only the estimation of the target statistics is missing. R's `fmhfit` example uses `gwesp(0, fixed = TRUE)`.
- **`estat gof, gof(espartners)`**: same dependency (the observed edgewise shared partners come from the alter-alter ties).
- **`degree1.5`, `nodemix`, `mm`, `degree(d, by=)`, `degree(homophily=)`, `concurrent(by=)`, `degrange(by=)`**: straightforward per-ego formulas (R: `EgoStat.*`), not yet written. `degree1.5` also needs a
  Stata option name (a digit followed by a letter is not allowed in `syntax`).
- **Other estimators of the covariance** (`stats.est = "asymptotic"`, `"bootstrap"`, `"jackknife"`, `"naive"`): only `"survey"`, R's default, is implemented. The bootstrap and jackknife are needed for
  non-scaling statistics (R's `order 0`; none of the terms here is one).
- **Egos with missing attribute values** (`na.rm = TRUE`): an error now; drop the egos with `if`.
- **Clustered or stratified designs** (R's `ego_design`: `strata`, `ids`, `variables`): only the weights are used; the covariance is that of a with-replacement design without clusters.
- **`simulate` at another population size** (R: `popsize =`, which runs a simulated-annealing step to reach the scaled statistics) and `basis =` a network: `nwergm simulate` gives networks of the pseudopopulation size only.
- **`offset()`, constraints, curved terms** with `nwergm ego` (R: `offset.coef`, `constraints`, `bd(maxout)` from the alter design): refused.
- **The initial network** is a random graph with the target density, R's is a simulated-annealing network that matches the target statistics (SAN). The chain moves towards the targets in the first MCMLE
  iterations, which can need more iterations (`mcmleiterations()`) than R for a model with strong homophily and a small sample; the estimates do not depend on it.
- **Windows and Linux** are not tested (no native change in this release; the plugin is the one of 1.9.0).

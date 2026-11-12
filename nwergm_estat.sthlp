{smcl}
{* *! version 1.5.12  12nov2026 author: Thomas Grund}{...}

{title:Title}

{p2colset 9 25 26 2}{...}
{p2col :nwergm postestimation {hline 2}}Postestimation tools for {cmd:nwergm}{p_end}
{p2colreset}{...}


{title:Description}

{pstd}
The following postestimation commands are available after {helpb nwergm}:

{p2colset 9 22 23 2}{...}
{p2col: {cmd:estat mcmcdiag}}MCMC diagnostics for the final simulation (method(mcmle) only); see {help nwergm_estimation}{p_end}
{p2col: {cmd:estat gof}}Simulation-based goodness of fit as in R's {cmd:gof()}; see {help nwergm_estimation}{p_end}
{p2col: {cmd:estat ic}}Log-likelihood, AIC and BIC (see {help nwergm_fit}){p_end}
{p2colreset}{...}

{pstd}
{cmd:db nwergm_estat} opens a dialog for these commands and for {cmd:nwergm simulate} from the last fit; {cmd:db nwergm_simulate} opens the dialog of {cmd:nwergm simulate} with given coefficients.


{title:estat mcmcdiag}

{p 8 17 2}
{cmd:estat mcmcdiag} [{cmd:,} {opt heidel} {opt rep:ort} {opt plot} {opt name(string)} {opt pvalue(#)} {opt eps(#)}]

{pstd}
{cmd:estat mcmcdiag} reports diagnostics for the final MCMC simulation {cmd:nwergm} ran
at its converged (or last-tried) coefficient vector: per-statistic mean, standard deviation,
lag-1 autocorrelation, and the effective sample size (ESS), computed as {cmd:coda}'s {cmd:effectiveSize()} does: n*var(x) divided by the spectral density at frequency 0, estimated from an
autoregressive model; the Geweke (1992) z-score and
the Heidelberger-Welch (1983) stationarity/halfwidth test (the two formal convergence hypothesis
tests behind R {cmd:ergm}'s own {cmd:mcmc.diagnostics()}, via its {cmd:coda} package
dependency); plus the overall Metropolis-Hastings acceptance rate and {cmd:nwergm}'s own MCMLE
convergence-test result. Available only after {opt method(mcmle)} - a pure MPLE fit involves no
MCMC simulation at all, so there is nothing to diagnose.

{pstd}
By default the command prints the sample size, burn-in, interval and acceptance rate, and one
table with the mean, standard deviation, lag-1 autocorrelation, ESS and Geweke z of every
statistic. {opt heidel} adds the table of the Heidelberger-Welch test. {opt report} adds the report
that R's {cmd:mcmc.diagnostics()} prints: sample statistics, quantiles, cross-correlations and
the joint Geweke test. All results are stored in {cmd:r()} whichever options are given.

{pstd}
{bf:This command never claims a fit converged merely because estimation stopped.} A satisfied
convergence test is reported as exactly that - a necessary check that passed, not a proof of
global convergence - and low ESS, low acceptance rate, high autocorrelation, a large Geweke
{bf:z}, or a failed Heidelberger-Welch stationarity test are all signs worth investigating even
when {cmd:e(converged)} is 1.

{pstd}
{bf:Geweke's diagnostic} compares the mean of the first 10% of the retained sample against the
mean of the last 50%, each corrected for autocorrelation via the same AR(p) spectral-density
estimator {cmd:nwergm}'s own final variance estimate uses. {bf:|z| > 1.96} (flagged with a
{bf:*}) rejects convergence of that parameter's own chain at the 5% level.

{pstd}
{bf:The Heidelberger-Welch test} first checks STATIONARITY: whether a Cramer-von-Mises test on
the chain's own cumulative-sum path passes once an increasing initial fraction (up to 50%) is
discarded - {bf:Start} reports the first retained iteration once it does; {bf:FAILED} means no
discard fraction achieved it. {opt pvalue()} sets the significance level and must be one of
{bf:0.10}, {bf:0.05} (the default), {bf:0.025}, or {bf:0.01} - the test is evaluated against a
fixed table of Cramer-von-Mises critical values at these four levels (each solved directly from
the real {cmd:coda} package's own {cmd:pcramer()} CDF, not approximated), rather than a
continuously computed p-value. Only once stationarity passes does the HALFWIDTH test run: the
retained portion's own 95% CI halfwidth must be within {opt eps()} (default 10%) of its own
mean - a separate, stricter precision check.

{pstd}
{opt plot} additionally draws a trace plot and a kernel density plot for each model statistic
in the final MCMC sample - an analogous pair of diagnostic plots to R's {cmd:mcmc.diagnostics()}
produces, combined here into a single figure (one row per statistic) via {help graph combine}.
A trace plot that drifts or shows long runs at one level, rather than a stationary-looking
"fuzzy caterpillar", indicates poor mixing even when the numeric diagnostics above look
acceptable. {opt name()} sets the combined graph's name; default {cmd:mcmcdiag}.


{title:estat gof}

{p 8 17 2}
{cmd:estat gof} [{cmd:,} {opt gof(statistics)} {opt nsim(#)} {opt seed(#)} {opt gofburnin(#)} {opt gofinterval(#)} {opt plot} {opt maxdeg(#)} {opt maxdist(#)} {opt name(string)}]

{pstd}
{cmd:estat gof} follows R's {cmd:gof()}: it simulates {opt nsim()} networks (default 100, at least 2) from the fitted model and,
for each requested statistic, shows the observed value, the minimum, mean and maximum over the simulated networks and the Monte Carlo
p-value; {help nwergm_estimation} describes the tables and the option {opt gof()}. The default statistics are those of R for the type of
network: {cmd:degree espartners distance} (undirected), {cmd:idegree odegree espartners distance} (directed) and
{cmd:b1degree b2degree dspartners distance} (two-mode), each together with the model statistics.
The chain starts from the last network of the fit ({opt method(mcmle)}) or from the observed network ({opt method(mple)}), with the
proposal and the sample-space constraints of the fit. {opt gofburnin()} defaults to {cmd:e(mcmc_burnin)} (16,384 after
{opt method(mple)}); {opt gofinterval()} defaults to {cmd:e(mcmc_interval_final)} (1,024 after {opt method(mple)}) times
{cmd:e(mcmc_samplesize)} / {opt nsim()}, as in R.{p_end}

{pstd}
On a one-mode network {cmd:estat gof} also returns summary values: the mean degree, the average geodesic distance (over the simulated
networks that are connected) and the triad census (counts of each MAN triad type: 16 types on a directed network, {bf:003}, {bf:102},
{bf:201} and {bf:300} on an undirected one; computed only when {cmd:triadcensus} is requested or the network has at most 100 nodes).
See {it:Stored results} below.{p_end}

{pstd}
{bf:This is a check, not a formal test.} A large, systematic gap between the observed value and the
simulated ones is evidence against the fitted model; rough agreement is evidence for it, not proof.
The simulated networks are {opt gofinterval()} Metropolis-Hastings steps apart, not independent draws, so
for a slowly mixing model (see the autocorrelation and ESS columns of {cmd:estat mcmcdiag}) the simulated
means can change noticeably between runs; increase {opt nsim()} (and consider {opt gofinterval()})
before treating a single run as a stable estimate.{p_end}

{pstd}
{opt plot} (one-mode networks) draws the degree distribution (in-degree on a directed network) and the
geodesic-distance distribution across the simulated networks, each as its own panel: a whisker
(minimum-maximum), a box (interquartile range) and a median marker summarize the simulated networks at each
value, with the observed proportion overlaid as a connected red line with circle markers, as in
{cmd:nwsaom}'s goodness-of-fit plots and similar to R's {cmd:plot(gof())}. {opt maxdeg()} (default 15) caps the
degree axis (values above it are pooled into a single "{it:maxdeg}+" category); {opt maxdist()} (default 6)
caps the geodesic-distance axis (unreached pairs are pooled into their own "NR" category). {opt name()} sets
the name of the combined graph; default {cmd:gof}.{p_end}


{title:Network types}

{pstd}
The {cmd:estat} commands use the network and the model of the last fit. {bf:Directed:} {cmd:estat gof} uses in- and out-degrees on a directed fit, degrees on an undirected one.
{bf:Valued:} the statistics are those of the fitted 0/1 graph. {bf:Two-mode:} {cmd:estat gof} reports the bipartite statistics, as R's {cmd:gof()}.
{bf:Signed:} not applicable. See {help nwnetworktypes}.{p_end}


{title:Examples}

{pstd}
Fit a dyad-dependent {help nwergm} model ({opt method(mcmle)} runs automatically whenever any
dyad-dependent term like {opt gwesp()} is present), then check MCMC diagnostics and basic
goodness of fit:

	{cmd:. nwwebuse florentine, nwclear}
	{cmd:. nwergm flomarriage, edges gwesp(.5)}
	{cmd:. estat mcmcdiag}
	{cmd:. estat gof, nsim(50)}


{title:Stored results}

{pstd}
{cmd:estat mcmcdiag} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{bf:r(acceptrate)}}Metropolis-Hastings acceptance rate over the final simulation{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{bf:r(ess)}}1 x {it:p} row vector of effective sample sizes, as {cmd:coda}'s {cmd:effectiveSize()}{p_end}
{synopt:{bf:r(geweke)}}1 x {it:p} row vector of Geweke z-scores, one per model term (same
column order as {bf:e(b)}){p_end}
{synopt:{bf:r(heidel)}}{it:p} x 6 matrix, one row per model term, columns
{bf:stest} (1/0, stationarity test passed), {bf:start} (first retained
iteration, missing if {bf:stest}=0), {bf:teststat} (the retained window's
own Cramer-von-Mises statistic), {bf:htest} (1/0, halfwidth test passed,
missing if {bf:stest}=0), {bf:mean} and {bf:halfwidth} of the retained
window (both missing if {bf:stest}=0){p_end}
{synopt:{bf:r(mc_summary)}, {bf:r(mc_quantiles)}}with {opt report}: sample statistics and quantiles of the centered statistics{p_end}
{synopt:{bf:r(mc_obstest)}, {bf:r(mc_crosscorr)}}with {opt report}: test of the sample statistics against the observed ones, cross-correlations{p_end}
{synopt:{bf:r(mc_autocorr)}, {bf:r(mc_geweke)}}with {opt report}: autocorrelations and Geweke statistics with p-values{p_end}

{pstd}
{cmd:estat gof} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{bf:r(nsim)}}number of simulated networks{p_end}
{synopt:{bf:r(burnin)}}burn-in used{p_end}
{synopt:{bf:r(interval)}}interval between simulated networks used{p_end}
{synopt:{bf:r(obs_meandeg)}}observed mean degree (one-mode networks){p_end}
{synopt:{bf:r(sim_meandeg)}}simulated mean degree, averaged over the {opt nsim()} networks{p_end}
{synopt:{bf:r(obs_avgpath)}}observed average geodesic distance; -1 if the observed network is not connected{p_end}
{synopt:{bf:r(sim_avgpath)}}simulated average geodesic distance over the connected simulated networks (missing if none is connected){p_end}
{synopt:{bf:r(obs_triad300)}}observed complete-triad count (when the triad census is computed){p_end}
{synopt:{bf:r(sim_triad300)}}simulated complete-triad count, averaged over the simulated networks{p_end}
{synopt:{bf:r(obs_triad_}{it:XXX}{bf:)}}observed count of MAN triad type {it:XXX}, e.g. {bf:r(obs_triad_021D)}, {bf:r(obs_triad_300)}{p_end}
{synopt:{bf:r(sim_triad_}{it:XXX}{bf:)}}simulated mean count of MAN triad type {it:XXX}{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{bf:r(gof_}{it:statistic}{bf:)}}one table per requested statistic ({bf:r(gof_model)}, {bf:r(gof_degree)}, {bf:r(gof_distance)} ...): columns
observed value, minimum, mean, maximum and Monte Carlo p-value{p_end}

{pstd}
{cmd:estat ic} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{bf:r(S)}}1 x 6 matrix with N, ll(null), ll(model), df, AIC and BIC{p_end}


{title:See also}

	{help nwergm}

{hline}
{pstd}{it:nwergm version 1.5.12, 12 November 2026}{p_end}{* nwversion}

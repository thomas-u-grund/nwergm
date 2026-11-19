{smcl}
{* *! version 1.10.0  19nov2026 author: Thomas Grund}{...}
{vieweralsosee "nwergm" "help nwergm"}{...}
{vieweralsosee "nwergm estimation" "help nwergm_estimation"}{...}
{vieweralsosee "nwergm postestimation" "help nwergm_estat"}{...}
{title:Title}

{p2colset 9 27 28 2}{...}
{p2col :nwergm Bayesian estimation {hline 2}}Bayesian ERGM with {cmd:estimate(bayes)}{p_end}
{p2colreset}{...}

{title:Syntax}

{p 8 17 2}
{cmd:nwergm} [{it:netname}]{cmd:,} {opt edges} [{it:terms}] {opt est:imate(bayes)} [{it:bayes options}]

{synoptset 28 tabbed}{...}
{synopthdr:bayes options}
{synoptline}
{syntab:Sampler}
{synopt:{opt chains(#)}}number of chains in the population; default max(2 x coefficients, 4), at least 3{p_end}
{synopt:{opt burn:in(#)}}adaptation iterations per chain, discarded; default 100{p_end}
{synopt:{opt iter:ations(#)}}iterations per chain before thinning; default 1000{p_end}
{synopt:{opt thin(#)}}keep every {it:#}th iteration; default 1{p_end}
{synopt:{opt aux:iterations(#)}}Metropolis-Hastings steps of the auxiliary network per proposal; default 1000{p_end}
{synopt:{opt gamma(#)}}initial scale of the population move; default 0.5{p_end}
{synopt:{opt proposalvar(#)}}variance of the random noise added to every move; default 0.0025{p_end}
{synopt:{opt targetaccept(#)}}acceptance rate the move scale adapts towards; default 0.25{p_end}
{synopt:{opt noadapt}}keep the move scale fixed{p_end}
{synopt:{opt nodelayed}}no delayed acceptance{p_end}
{synopt:{opt dainflate(#)}}inflation of the delayed-acceptance surrogate covariance; default 1.5{p_end}
{synopt:{opt startvals(numlist)}}centre of the starting population; default the pseudolikelihood estimate{p_end}
{synopt:{opt seed(#)}}random-number seed{p_end}
{syntab:Prior}
{synopt:{opt priormean(numlist)}}prior means, one per coefficient; default 0{p_end}
{synopt:{opt priorvar(numlist)}}prior variances, one value or one per coefficient; default 100{p_end}
{synopt:{opt priorcov(matname)}}prior covariance matrix, instead of {opt priorvar()}{p_end}
{synopt:{opt priordecay(# #)}}mean and standard deviation of log(decay) for a free decay parameter; default -0.693 and 0.75{p_end}
{syntab:Output}
{synopt:{opt level(#)}}credible level; default 95{p_end}
{synopt:{opt frame(name)}}frame that receives the draws; default {cmd:nwergm_bayes_draws}{p_end}
{synopt:{opt nodraws}}do not keep the draws in a frame{p_end}
{synoptline}
{p2colreset}{...}
{pstd}{cmd:method(bayes)} is a synonym of {cmd:estimate(bayes)}.

{title:Description}

{pstd}
{cmd:estimate(bayes)} fits the ERGM by Bayesian inference and follows R's {cmd:Bergm::bergm()} (Caimo and Friel 2011, 2014; Bergm 6.0.0). The
posterior is sampled with the exchange algorithm: every proposed coefficient vector is judged with one auxiliary network drawn from the model at the
proposal, which avoids the intractable normalising constant. A population of chains moves by adaptive direction sampling, the difference of two other
chains of the population plus random noise. During burn-in the move scale adapts towards the target acceptance rate, and a Gaussian surrogate fitted to the
second half of burn-in screens proposals before the costly auxiliary simulation (delayed acceptance).

{pstd}
The prior is multivariate normal, by default with mean 0 and variance 100 per coefficient. A free decay parameter (for example in
{opt gwesp(#, free)}) has a log-normal prior with log-mean log(0.5) and log-standard deviation 0.75. Coefficients fixed by {opt offset()} are held
at their value and are not sampled.

{pstd}
The chains run one after another in a single process. All terms of the plugin are available that {cmd:nwergm} fits by Monte Carlo maximum likelihood,
with the exceptions listed here: {opt operators()}, {opt constraints()}, {opt obsconstraints()}, {opt structural()}, {opt fixdensity}, {opt logstat()}, {opt expstat()},
{opt init()}, {opt mainmethod()}, {opt nonative}, {opt submodel()} and networks with missing dyads are not allowed with {cmd:estimate(bayes)}.

{pstd}
The table shows, for each coefficient, the posterior mean, standard deviation, median, equal-tailed credible interval, the effective sample size (ESS,
as {cmd:coda}'s {cmd:effectiveSize()}, summed over the chains) and the Gelman-Rubin statistic (R-hat). {cmd:e(b)} holds the posterior means and {cmd:e(V)}
the posterior covariance matrix. The draws are kept in a frame.

{title:Postestimation}

{phang}
{cmd:estat posterior} [{cmd:,} {opt saving(filename)} {opt replace} {opt plot(trace|density|both)} {opt name(string)} {opt pars(namelist)} {opt level(#)} {opt notable}]
summarises the draws, saves them to a Stata data set and draws trace and density plots.

{phang}
{cmd:estat mcmcdiag} [{cmd:,} {opt plot} {opt name(string)}] shows ESS, Monte Carlo standard error, R-hat with its upper limit, the Geweke z-score, the lag-1
autocorrelation and the acceptance rate of every chain.

{phang}
{cmd:estat gof} is a posterior predictive check: networks are simulated at draws from the posterior and compared with the observed network. The default
burn-in per simulated network is 10000.

{phang}
{cmd:estat ic} is not available (there is no maximum likelihood).

{title:Examples}

{phang2}{cmd:. nwwebuse florentine, nwclear}{p_end}
{phang2}{cmd:. nwergm flomarriage, edges triangle estimate(bayes) seed(1)}{p_end}
{phang2}{cmd:. estat mcmcdiag, plot}{p_end}
{phang2}{cmd:. estat posterior, saving(draws) replace plot(both)}{p_end}
{phang2}{cmd:. estat gof, nsim(100)}{p_end}
{phang2}{cmd:. nwergm flomarriage, edges gwesp(0.5, free) estimate(bayes) priorvar(25) iterations(5000)}{p_end}

{title:Stored results}

{pstd}
{cmd:nwergm} with {cmd:estimate(bayes)} stores in {cmd:e()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:e(chains)}, {cmd:e(burnin)}, {cmd:e(iterations)}, {cmd:e(thin)}}settings of the sampler{p_end}
{synopt:{cmd:e(ndraws)}, {cmd:e(draws_per_chain)}}number of draws kept{p_end}
{synopt:{cmd:e(accept_rate)}}overall acceptance rate{p_end}
{synopt:{cmd:e(gamma)}}final move scale{p_end}
{synopt:{cmd:e(level)}, {cmd:e(seconds)}}credible level, run time{p_end}
{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:e(b)}, {cmd:e(V)}}posterior mean and covariance{p_end}
{synopt:{cmd:e(median)}, {cmd:e(sd)}, {cmd:e(ci)}}posterior median, standard deviation, credible limits (rows lower and upper){p_end}
{synopt:{cmd:e(ess)}, {cmd:e(rhat)}, {cmd:e(rhat_upper)}}diagnostics{p_end}
{synopt:{cmd:e(accept_chains)}}acceptance rate by chain{p_end}
{synopt:{cmd:e(prior_mean)}, {cmd:e(prior_var)}}prior{p_end}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:e(method)}}{cmd:bayes}{p_end}
{synopt:{cmd:e(post_frame)}}name of the frame with the draws{p_end}
{p2colreset}{...}

{title:References}

{phang}
Caimo, A. and N. Friel. 2011. Bayesian inference for exponential random graph models. {it:Social Networks} 33: 41-55.{p_end}
{phang}
Caimo, A. and N. Friel. 2014. Bergm: Bayesian exponential random graphs in R. {it:Journal of Statistical Software} 61(2).{p_end}

{hline}
{pstd}{it:nwergm version 1.10.0, 19 November 2026}{p_end}{* nwversion}

{smcl}
{* *! version 1.13.0  22nov2026 author: Thomas Grund}{...}
{vieweralsosee "nwergm" "help nwergm"}{...}
{vieweralsosee "nwergm estimation" "help nwergm_estimation"}{...}
{vieweralsosee "nwergm postestimation" "help nwergm_estat"}{...}
{title:Title}

{p2colset 9 27 28 2}{...}
{p2col :nwergm ego {hline 2}}ERGM for egocentrically sampled data{p_end}
{p2colreset}{...}

{title:Syntax}

{p 8 17 2}
{cmd:nwergm ego} [{it:if}] [{it:in}]{cmd:,} {opt edges} [{it:terms}] {opt egoid(varname)} {c -(}{opt alters(framename)} | {opt egodeg:ree(varname)}{c )-} [{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr:terms}
{synoptline}
{synopt:{opt edges}}number of ties; required{p_end}
{synopt:{opt degree(numlist)}}number of nodes of degree {it:d}, for each {it:d}{p_end}
{synopt:{opt degrange(numlist)} {opt degrangeto(numlist)}}number of nodes of degree from {it:a} up to, not including, {it:b}; without {opt degrangeto()} no upper limit{p_end}
{synopt:{opt concurrent}}number of nodes of degree 2 or more{p_end}
{synopt:{opt nodefactor(varlist)}}main effects of the levels of a categorical attribute (the first level is the base){p_end}
{synopt:{opt nodematch(varlist)}}homophily on a categorical attribute{p_end}
{synopt:{opt nodematchdiff(varlist)}}homophily by level{p_end}
{synopt:{opt nodecov(varlist)}}main effect of a numeric attribute{p_end}
{synopt:{opt absdist(varlist)}}absolute difference of a numeric attribute{p_end}
{synoptline}

{synopthdr:options}
{synoptline}
{syntab:Ego data}
{synopt:{opt egoid(varname)}}variable that identifies the egos (numeric or string); required with {opt alters()}{p_end}
{synopt:{opt alters(framename)}}frame with one row per alter{p_end}
{synopt:{opt alteregoid(varname)}}variable of the alter frame that holds the identifier of the ego; default the name of {opt egoid()}{p_end}
{synopt:{opt egodegree(varname)}}number of alters of each ego, when only the degree was collected{p_end}
{synopt:{opt weights(varname)}}sampling weights of the egos; default equal weights{p_end}
{syntab:Population}
{synopt:{opt popsize(#)}}number of nodes of the population; default 1; 0 switches the network size adjustment off{p_end}
{synopt:{opt ppopsize(auto|samp|pop|#)}}size of the pseudopopulation; default {cmd:auto}{p_end}
{synopt:{opt ppopmul(#)}}multiplier of the pseudopopulation size; default 1{p_end}
{synopt:{opt ppopwt(round|sample)}}how the egos are copied into the pseudopopulation; default {cmd:round}{p_end}
{syntab:Estimation}
{synopt:{opt seed(#)}}random-number seed (pseudopopulation and sampler){p_end}
{synopt:{opt mcmcinterval(#)}, {opt mcmcburnin(#)}, {opt mcmcsamplesize(#)}}as in {help nwergm_estimation:nwergm}; the defaults are those of {cmd:nwergm}{p_end}
{synopt:{opt mcmleiterations(#)}, {opt mcmleeffectivesize(#)}, {opt mcmletermination()}}as in {help nwergm_estimation:nwergm}{p_end}
{synopt:{opt proposal(tnt|uniform)}, {opt nonative}, {opt verbose}}as in {help nwergm_estimation:nwergm}{p_end}
{synopt:{opt ci}, {opt level(#)}, {opt noci}, ...}display options of the coefficient table{p_end}
{synoptline}
{p2colreset}{...}

{title:Description}

{pstd}
{cmd:nwergm ego} fits an exponential random graph model to egocentrically sampled data: a sample of egos with their attributes and the attributes of
their alters, but no network. It follows R's {cmd:ergm.ego} (Krivitsky and Morris 2017; ergm.ego 1.1.4). The data in memory are the egos, one row per
ego. The alters are in a second frame, one row per alter, with the identifier of the ego ({opt alters()}); the attributes of the alters carry the
names of the attributes of the egos. If only the number of alters of each ego was collected, {opt egodegree()} gives it, and the terms that need the
attributes of the alters are not available. No network has to be declared with {cmd:nwset}.

{pstd}
Each ego contributes to the statistics of the terms (for example half of its alters to {opt edges}, the alters of its own group to
{opt nodematch()}). The mean of these contributions, weighted by {opt weights()}, times the size of the network estimates the statistics of the
network. The model is then fitted to these target statistics on a pseudopopulation: a network of {opt ppopsize()} nodes, the egos copied in
proportion to their weights, on which the Monte Carlo sampler of {cmd:nwergm} draws networks until the expected statistics equal the targets. With
{opt popsize(#)} the coefficient of {opt edges} refers to a network of that many nodes (R's network size adjustment, an offset
-log(ppopsize/popsize) on the number of ties during the sampling). The default {cmd:popsize(1)} gives the coefficients of a network of size 1, as R
does; give the size of the population to compare with a model for a network of that size. {opt ppopsize(auto)} is the size of the population when it
is given, else the size of the sample; {cmd:samp} is the size of the sample, {cmd:pop} the size of the population, or give a number. The pseudopopulation
can have a few nodes more or fewer than requested, because the number of copies of each ego is rounded (R rounds halves to the even number, as
{cmd:nwergm ego} does).

{pstd}
The standard errors are R's: the covariance of the estimated statistics, from the design of the sample (weights; the egos are independent), passed
through the information of the model at the size of the pseudopopulation, V = A^-1 V_t A^-1, where A is the covariance of the statistics of the
sampled networks and V_t the covariance of the target statistics. The covariance does not include the Monte Carlo error of the fit, which is
reduced with a longer sample ({opt mcmleeffectivesize()}, {opt mcmcsamplesize()}). The estimator is moments-based: there is no log-likelihood, and
{cmd:estat ic} and {cmd:predict} are not available.

{pstd}
Not available (R's ergm.ego has them): terms that need the ties among the alters ({cmd:esp}, {cmd:gwesp}, {cmd:triangle}, {cmd:transitiveties}),
{cmd:degree1.5}, {cmd:nodemix}, {cmd:mm}, the other estimators of the covariance ({cmd:asymptotic}, {cmd:bootstrap}, {cmd:jackknife}), terms of the
alters that are not attributes (valued networks), curved terms, constraints and {cmd:offset()}. Egos with missing attribute values are an error:
drop them with {cmd:if}.

{title:Postestimation}

{pstd}
{cmd:estat gof} compares the statistics of the model and the degree distribution of the sample with networks simulated at the estimate (R's
{cmd:gof.ergm.ego}; statistics per node). {cmd:gof(model degree)} chooses the statistics; the ties-among-alters statistic of R ({cmd:espartners}) is not
available. {cmd:nwergm simulate} (without a number of nodes) draws networks of the size of the pseudopopulation from the fit; the networks have no
node attributes. {cmd:estat mcmcdiag} works as after other Monte Carlo fits.

{title:Example}

{phang2}{cmd:. frame create alters}{p_end}
{phang2}{cmd:. frame alters: import delimited alters.csv, clear}{p_end}
{phang2}{cmd:. import delimited egos.csv, clear}{p_end}
{phang2}{cmd:. nwergm ego, edges degree(1/3) nodefactor(race sex) nodematch(race sex) absdist(grade) egoid(id) alters(alters) popsize(205)}{p_end}
{phang2}{cmd:. estat gof, nsim(100)}{p_end}

{title:Stored results}

{pstd}
{cmd:nwergm ego} stores the results of {cmd:nwergm} (in {cmd:e(b)} the coefficients, with the coefficient of {cmd:edges} for a network of {cmd:popsize()} nodes; in
{cmd:e(V)} the covariance above) and

{synoptset 22 tabbed}{...}
{synopt:{cmd:e(estimate)}}{cmd:Ego}{p_end}
{synopt:{cmd:e(egos)}, {cmd:e(N)}}number of egos{p_end}
{synopt:{cmd:e(popsize)}, {cmd:e(ppopsize)}}population and pseudopopulation size{p_end}
{synopt:{cmd:e(egoshift)}}the offset of the network size adjustment, -log(ppopsize/popsize); zero for {cmd:popsize(0)}{p_end}
{synopt:{cmd:e(sum_weights)}}sum of the weights{p_end}
{synopt:{cmd:e(target)}}target statistics, scaled to the pseudopopulation{p_end}
{synopt:{cmd:e(V_target)}}covariance of the target statistics (R: {cmd:v}){p_end}
{synopt:{cmd:e(info)}}information of the model, the covariance of the statistics at the estimate (R: {cmd:DtDe}){p_end}
{synopt:{cmd:e(degdist)}, {cmd:e(maxdeg)}}degree distribution of the egos (shares of degree 0, 1, ..., maxdeg-1, maxdeg or more), for {cmd:estat gof}{p_end}
{p2colreset}{...}

{title:References}

{phang}
Krivitsky, P. N. and M. Morris. 2017. Inference for social network models from egocentrically sampled data, with application to understanding persistent racial disparities in HIV prevalence in the US. {it:Annals of Applied Statistics} 11: 427-455.{p_end}
{phang}
Krivitsky, P. N., M. S. Handcock and M. Morris. 2011. Adjusting for network size and composition effects in exponential-family random graph models. {it:Statistical Methodology} 8: 319-339.{p_end}

{hline}
{pstd}{it:nwergm version 1.13.0, 22 November 2026}{p_end}{* nwversion}

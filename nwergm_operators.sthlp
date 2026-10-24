{smcl}
{* *! version 1.0.1  24oct2026 author: Thomas Grund}{...}
{title:Title}

{p2colset 9 33 34 2}{...}
{p2col :nwergm operators() {hline 2}}Operator terms of R's ergm package in {helpb nwergm}{p_end}
{p2colreset}{...}
{pstd}{it:nwergm version 1.0.1, 24 October 2026}{p_end}{* nwversion}

{title:Syntax}

{p 8 17 2}
{cmd:nwergm} [{it:{help netname}}]{cmd:,} {opt edges} {cmd:operators(}{it:oplist}{cmd:)} [{it:other options}]

{pstd}
{it:oplist} is a list of operator calls separated by blanks, written like R's operator terms: {it:Name}{cmd:(}{it:terms}[{cmd:,} {it:suboptions}]{cmd:)}. The names are not case sensitive.
The {it:terms} inside an operator are written as options of {cmd:nwergm}, for example {cmd:triangle nodematch(sex) gwesp(0.5) kstar(2)} or {cmd:structural(twopath)};
they give the statistics of the operator in the order in which they are written, as in an R formula. An operator can be used inside another operator, for example
{cmd:Sum(F(triangle, filter(nodematch(sex))) | S(triangle, attrs(age>30)), label(a))}.
Example:

{phang2}{cmd:. nwergm mynet, edges operators(F(triangle kstar(2), filter(nodematch(sex))) Symmetrize(triangle, rule(strong)))}{p_end}

{pstd}
The coefficient names are those of R ({cmd:Sum~a}, {cmd:S(age>30)~triangle}, {cmd:Symmetrize(strong)~triangle}, {cmd:Proj1~edges}) with {cmd:.} replaced by {cmd:_}.
An operator makes the model dyad-dependent unless its terms are dyad-independent and the operator itself introduces no dependence, so {cmd:method(mcmle)} is then the default.
All operators run in the native plugin that ships with the package; there is no slower fallback.

{title:Operators}

{synoptset 40 tabbed}{...}
{synopthdr:operator}
{synoptline}
{synopt:{cmd:Sum(}{it:f1} [{cmd:|} {it:f2} ...]{cmd:, label(}{it:names}{cmd:))}}Sum of the statistics of one or more formulas, element by element. A formula can start with its weights and a colon: a number ({cmd:2: triangle}), one weight per statistic, {cmd:matrix(}{it:name}{cmd:):},
	or {cmd:sum:} / {cmd:mean:}, which combine all statistics of the formula into one. {opt label()} is required: one name, to which the index is appended, or one name per resulting statistic{p_end}
{synopt:{cmd:Prod(}{it:f1} [{cmd:|} {it:f2} ...]{cmd:, label(}{it:names}{cmd:))}}Product of the statistics of the formulas; weights are exponents; the presets are {cmd:prod:} and {cmd:geomean:}. The statistics must not be negative. Formulas inside {cmd:Prod()} cannot contain {cmd:Sum()}
	or {cmd:Prod()}{p_end}
{synopt:{cmd:S(}{it:terms}{cmd:, attrs(}{it:expr}{cmd:))}}Terms evaluated on the subgraph induced by the nodes for which {it:expr} (a variable, or a condition such as {cmd:age>30}) is true (R's one-sided {opt attrs} formula; the two-sided form that selects different node sets for tails
	and heads is not available). One-mode networks only{p_end}
{synopt:{cmd:F(}{it:terms}{cmd:, filter(}{it:term}{cmd:))}}Terms evaluated on the network from which the ties are removed for which the filter term is zero. The filter is one dyad-independent term with one statistic; {cmd:!} in front of it, or a comparison after it
	({cmd:absdist(age) > 3}, with {cmd:==  !=  >  <  >=  <=}), selects the ties kept{p_end}
{synopt:{cmd:NodematchFilter(}{it:terms}{cmd:, attrname(}{it:varlist}{cmd:))}}Terms evaluated on the network without the ties between nodes that differ in one of the attributes{p_end}
{synopt:{cmd:Symmetrize(}{it:terms}{cmd:, rule(}{it:rule}{cmd:))}}Terms evaluated on the undirected network obtained from a directed one; {it:rule} is {cmd:weak} (default, or {cmd:max}), {cmd:strong} ({cmd:min}), {cmd:upper} or {cmd:lower}. Directed networks only{p_end}
{synopt:{cmd:Project(}{it:terms}{cmd:, mode(}{it:#}{cmd:))}}Terms evaluated on the one-mode network of the nodes of mode {it:#} (1 or 2), in which two nodes are tied if they have a partner in common; the terms see this network of ties and non-ties (in R,
	{cmd:Proj1(~B(}{it:terms}{cmd:, "nonzero"))}), not the counts of common partners. {cmd:Proj1(}{it:terms}{cmd:)} and {cmd:Proj2(}{it:terms}{cmd:)} are the short forms.
	Two-mode networks only{p_end}
{synopt:{cmd:I(}{it:terms}{cmd:)}}The terms themselves; useful to paste a list of terms kept in a local macro{p_end}
{synopt:{cmd:For(}{it:name}{cmd:=}{it:values}[{cmd:,} {it:name2}{cmd:=}{it:values2}]{cmd:,} {it:terms}{cmd:)}}The terms repeated for each value; {cmd:{c -(}}{it:name}{cmd:{c )-}} in the terms is replaced by the value. With several loops, the first one is the outermost. Example:
	{cmd:For(v = sex region, nodematch({c -(}v{c )-}))}{p_end}
{synopt:{cmd:Label(}{it:terms}{cmd:, label(}{it:names}{cmd:)} [{cmd:pos(}{it:pos}{cmd:)}]{cmd:)}}The terms with other coefficient names; {it:pos} is {cmd:paren} (default: {cmd:label(coefficient)}), {cmd:prepend}, {cmd:append} or {cmd:replace}{p_end}
{synopt:{cmd:Log(}{it:terms}[{cmd:, log0(}{it:#}{cmd:)}]{cmd:)}}Natural logarithm of the statistics; {opt log0()} (default -1/sqrt(epsdouble)) stands in for the logarithm of zero{p_end}
{synopt:{cmd:Exp(}{it:terms}{cmd:)}}Exponential function of the statistics{p_end}
{synopt:{cmd:Curve(}{it:terms}{cmd:, params(}{it:names}{cmd:) map(}{it:map}{cmd:))}}The coefficients of the terms are a linear function of the parameters: eta = L * theta, where {it:map} is {cmd:rep} or {cmd:matrix(}{it:name}{cmd:)}. {cmd:map(rep)} recycles the parameters over the terms'
	coefficients,
	{cmd:map(matrix(L))} takes the matrix L (one row per coefficient, one column per parameter). The model is estimated for the parameters, which carry the names given in {opt params()}. {cmd:Parametrise()} and {cmd:Parametrize()} are the same operator. Map functions, {opt gradient()},
	{opt minpar()}, {opt maxpar()} and {opt cov()} of R are not available{p_end}
{synopt:{cmd:Offset(}{it:terms}[{cmd:, coef(}{it:numlist}{cmd:) which(}{it:selection}{cmd:)}]{cmd:)}}Coefficients held at fixed values (default 0) instead of being estimated; {opt which()} selects them by position or coefficient name, default all. The fixed coefficients are reported with
	standard error 0{p_end}
{synoptline}

{title:Remarks}

{pstd}
The operators work with the sampling and estimation methods of {cmd:nwergm}: the maximum pseudolikelihood estimate, the maximum likelihood estimate, {cmd:nwergm simulate} from a fit and {cmd:estat gof}.
They cannot be combined with {opt constraints()}, {opt obsconstraints()}, {opt freedyads()}, {opt blockdiag()} or {opt fixdensity}, and a curved (free-decay) term cannot be used inside an operator.
Dyadic covariates ({cmd:edgecov()}, {cmd:dyadcov()} ...) cannot be used inside {cmd:S()} or {cmd:Project()}, which change the set of nodes.

{pstd}
For {cmd:Symmetrize()} with {cmd:rule(weak)} on a network with reciprocated ties, the pseudolikelihood is formed from the exact change statistics of the symmetrized network.

{title:Also see}

{psee}
{helpb nwergm}, {helpb nwergm_structural}, {helpb nwergm_estimation}

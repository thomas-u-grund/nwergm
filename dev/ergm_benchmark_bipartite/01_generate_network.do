/*
	Generates ONE random bipartite network (fixed seed), exported as a
	plain (person, event) edgelist CSV, for both R and Stata to fit
	identically - same discipline as
	dev/ergm_benchmark_r_vs_stata's own "generate once, export
	identically for both tools" benchmarks.

	60 mode-1 nodes ("persons"), 40 mode-2 nodes ("events"). Guarantees
	every node has at least one tie (one random cross-mode partner
	assigned first, deduplicated, before topping up to the target
	density with additional random ties) - a real correctness issue
	found and worked around here, not incidental: nwset's own `twomode'
	edgelist declaration builds its node set purely from the ids that
	actually APPEAR in the data (unlike R's `network.initialize(n,
	bipartite=n1)', which explicitly declares the full node count
	including isolates) - a first attempt without this guarantee left 6
	persons/3 events with zero ties, so Stata silently fit a 91-node
	network against R's own 100-node network, an apples-to-oranges
	comparison caught by comparing `e(nodes)'/`network.size()' before
	trusting any timing number.
*/
local ddir "/Users/tgrund/FILES_NEW/SOFTWARE/nwcommands/dev/ergm_benchmark_bipartite"

mata:
mata set matastrict off
rseed(20260829)
n1 = 60
n2 = 40
p = 0.05
tie = J(n1, n2, 0)

// guarantee every node has at least one tie
for (i=1; i<=n1; i++) tie[i, ceil(runiform(1,1)*n2)] = 1
for (j=1; j<=n2; j++) tie[ceil(runiform(1,1)*n1), j] = 1

// top up to the target density with additional random ties
for (i=1; i<=n1; i++) {
	for (j=1; j<=n2; j++) {
		if (runiform(1,1) < p) tie[i,j] = 1
	}
}

if (fileexists("`ddir'/bipnet.csv")) unlink("`ddir'/bipnet.csv")
fh = fopen("`ddir'/bipnet.csv", "w")
fput(fh, "person,event")
nties = 0
for (i=1; i<=n1; i++) {
	for (j=1; j<=n2; j++) {
		if (tie[i,j]) {
			fput(fh, strofreal(i) + "," + strofreal(j))
			nties++
		}
	}
}
fclose(fh)
printf("generated bipnet.csv: %g mode-1 x %g mode-2, %g ties (density %6.4f), every node has >=1 tie\n", n1, n2, nties, nties/(n1*n2))
end

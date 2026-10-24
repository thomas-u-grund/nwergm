/*
	Real-world nwergm benchmark: US airport route network (OpenFlights-
	derived, data/usair_full_edges.csv/usair_full_nodes.csv) - 549
	airports, 5450 directed routes, zero isolates (every listed airport
	has at least one route both directions or a one-way listing).

	Builds the network via nwfromedge (string IATA node labels), then
	exports a plain numeric directed edgelist CSV (1-indexed node ids in
	nwfromedge's own row order) so R reads back the IDENTICAL topology
	byte-for-byte, matching this suite's own established
	generate-once/export-identically convention.
*/
adopath + "/Users/tgrund/FILES_NEW/SOFTWARE/nwcommands/lib"
adopath + "/Users/tgrund/FILES_NEW/SOFTWARE/nwcommands"
* The core package nwcommands is found through the environment variable NWCORE (path of the core checkout).
local nwcore : env NWCORE
if `"`nwcore'"' == "" {
	di as error "set the environment variable NWCORE to the directory of the nwcommands (core) package"
	exit 198
}
adopath ++ `"`nwcore'"'
adopath ++ `"`c(pwd)'"'
quietly do `"`nwcore'/unw_core.do"'
do unw_ergm.do
run "/Users/tgrund/FILES_NEW/SOFTWARE/nwcommands/nwergm.ado"

local ddir "/Users/tgrund/FILES_NEW/SOFTWARE/nwcommands/dev/ergm_benchmark_usair"

nwclear
import delimited "`ddir'/usair_full_edges.csv", clear varnames(1) stringcols(_all)
nwfromedge sourceap destap, directed name(usair)

di "nodes: " e(nodes)
di "ties: " e(ties)

mata:
mata set matastrict off
p = nw.nws.pdefs[nw.nws.get_index_of("usair")]
el = p->edgelist()
fh = fopen("`ddir'/usair_edgelist.csv", "w")
for (i=1; i<=rows(el); i++) fput(fh, strofreal(el[i,1]) + "," + strofreal(el[i,2]))
fclose(fh)
printf("exported usair_edgelist.csv: %g nodes, %g directed ties\n", p->get_nodes(), rows(el))
end

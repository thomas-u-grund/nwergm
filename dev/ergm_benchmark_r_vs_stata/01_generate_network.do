/*
	Generates one reproducible directed random network and exports its
	adjacency matrix as a plain CSV (no header, 0/1 values) so BOTH the
	Stata (nwergm) and R (ergm) benchmark runs fit the exact same
	network - isolating the comparison to estimation speed, not network
	structure differences.
*/
* The core package nwcommands is found through the environment variable NWCORE (path of the core checkout).
local nwcore : env NWCORE
if `"`nwcore'"' == "" {
	di as error "set the environment variable NWCORE to the directory of the nwcommands (core) package"
	exit 198
}
adopath ++ `"`nwcore'"'
adopath ++ `"`c(pwd)'"'
quietly do `"`nwcore'/unw_core.do"'

set seed 20260822
nwclear
nwrandom 30, prob(0.12) directed name(bench30)

nw_syntax bench30, max(1)
mata:
mata set matastrict off
M = *`netobj'->get_matrix_mod(1,1)
_editmissing(M, 0)
fh = fopen("/Users/tgrund/FILES_NEW/SOFTWARE/nwcommands/dev/ergm_benchmark_r_vs_stata/bench_net.csv", "w")
for (i=1; i<=rows(M); i++) {
	fput(fh, invtokens(strofreal(M[i,.]), ","))
}
fclose(fh)
printf("exported %g x %g adjacency matrix, %g ties\n", rows(M), cols(M), sum(M))
end

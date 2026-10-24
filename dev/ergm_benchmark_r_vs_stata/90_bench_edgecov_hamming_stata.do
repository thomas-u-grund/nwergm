/*
	Harmonisation unit 160 benchmark: 100-node undirected network,
	edges + edgecov(covnet) + hamming(refnet), now that edgecov()/
	hamming() are native-eligible (the last remaining gap in the "move
	all effects to C" migration). Exercises the new covmat wire
	mechanism (native_covidx/native_covmatstack in unw_ergm.do,
	TERMCODE_EDGECOV/TERMCODE_HAMMING in native/ergm_mcmc.c) at a
	realistic scale, following the same benchmark-harness pattern as
	the rest of this directory (generate once, export identically for
	both tools, time each tool's own default settings).
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

local ddir "/Users/tgrund/FILES_NEW/SOFTWARE/nwcommands/dev/ergm_benchmark_r_vs_stata"

// Main network to fit on.
set seed 20260829
nwclear
nwrandom 100, prob(0.04) undirected name(bench_ech_main)

// Dyadic covariate network for edgecov() - a separate random network
// whose own tie/no-tie pattern serves as a continuous-looking 0/1
// covariate (matches how a real "prior relationship" or "same-
// department" dyadic covariate is typically coded).
nwrandom 100, prob(0.06) undirected name(bench_ech_cov)

// Reference network for hamming() - independent again, so the
// hamming distance genuinely varies across the MCMC run rather than
// trivially tracking the main network.
nwrandom 100, prob(0.05) undirected name(bench_ech_ref)

nw_syntax bench_ech_main, max(1)
capture erase "`ddir'/bench_ech_main.csv"
mata:
mata set matastrict off
M = *`netobj'->get_matrix_mod(1,0)
_editmissing(M, 0)
fh = fopen("`ddir'/bench_ech_main.csv", "w")
for (i=1; i<=rows(M); i++) fput(fh, invtokens(strofreal(M[i,.]), ","))
fclose(fh)
printf("exported bench_ech_main.csv: %g x %g, %g ties\n", rows(M), cols(M), sum(M)/2)
end

nw_syntax bench_ech_cov, max(1)
capture erase "`ddir'/bench_ech_cov.csv"
mata:
mata set matastrict off
M = *`netobj'->get_matrix_mod(1,0)
_editmissing(M, 0)
fh = fopen("`ddir'/bench_ech_cov.csv", "w")
for (i=1; i<=rows(M); i++) fput(fh, invtokens(strofreal(M[i,.]), ","))
fclose(fh)
printf("exported bench_ech_cov.csv: %g x %g, %g ties\n", rows(M), cols(M), sum(M)/2)
end

nw_syntax bench_ech_ref, max(1)
capture erase "`ddir'/bench_ech_ref.csv"
mata:
mata set matastrict off
M = *`netobj'->get_matrix_mod(1,0)
_editmissing(M, 0)
fh = fopen("`ddir'/bench_ech_ref.csv", "w")
for (i=1; i<=rows(M); i++) fput(fh, invtokens(strofreal(M[i,.]), ","))
fclose(fh)
printf("exported bench_ech_ref.csv: %g x %g, %g ties\n", rows(M), cols(M), sum(M)/2)
end

timer clear 1
set seed 999
timer on 1
nwergm bench_ech_main, edges edgecov(bench_ech_cov) hamming(bench_ech_ref)
timer off 1
timer list 1

di
di "======================================"
di "STATA nwergm: 100-node undirected, edges + edgecov() + hamming() (native, unit 160)"
di "======================================"
di "Wall time: " %8.3f r(t1) " seconds"
di "e(native): " e(native)
di "Converged: " e(converged)
matrix list e(b)
matrix list e(V)

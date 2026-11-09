* Section 9.3, models with one coefficient per node: edges + sender + receiver on a random directed network of
* 400 nodes, fitted by pseudolikelihood (here the likelihood). Writes the network to data/net400_edges.csv
* and the estimates to results/per_node_nwergm.csv; R/04_per_node.R fits the same model and compares.
do stata/setup.do
nwclear
set seed 400
nwrandom 400, prob(0.025) name(net)
* edge list (sender, receiver), as read by R
_nwsyntax net, max(1)
mata: M = *`netobj'->get_matrix_mod(1, 1)
mata: _editmissing(M, 0)
mata: k = selectindex(vec(M') :!= 0)
mata: E = (ceil(k :/ cols(M)), k :- (ceil(k :/ cols(M)) :- 1) :* cols(M))
capture erase "data/net400_edges.csv"
mata: fh = fopen("data/net400_edges.csv", "w"); for (k = 1; k <= rows(E); k++) fput(fh, strofreal(E[k, 1]) + "," + strofreal(E[k, 2])); fclose(fh)
mata: st_local("nt", strofreal(rows(E)))
display "ties: `nt'"
quietly nwergm net, edges sender receiver seed(1)
timer clear 1
timer on 1
quietly nwergm net, edges sender receiver
timer off 1
quietly timer list 1
display "nwergm seconds: " %6.2f r(t1) "   coefficients: " colsof(e(b))
tempname b
matrix `b' = e(b)
preserve
clear
local k = colsof(`b')
quietly set obs `k'
generate str32 term = ""
generate double b = .
local names : colnames `b'
forvalues i = 1/`k' {
	quietly replace term = "`: word `i' of `names''" in `i'
	quietly replace b = `b'[1, `i'] in `i'
}
export delimited using "results/per_node_nwergm.csv", replace
restore

cscript

* DRAFT, not yet run.
* xt_stats_bipartite: observed sufficient statistics (e(obs_stats) after method(mple)) of the two-mode terms and of the
* one-mode terms R allows on a two-mode network, on a 4 x 5 network with an isolate in each mode, compared with R ergm
* 4.12.0 summary(); decay 0 / 0.5 / 10; terms refused on a two-mode network and two-mode terms refused on a one-mode one.
* Expected runtime: about 1 minute.
* Runs from the repository root; the runner sets PLUS, the adopath and the plugin path.
capture program drop nwinstall
set graphics off

capture program drop xt_stat
program xt_stat
	args id net opts expected
	capture noisily nwergm `net', edges `opts' method(mple)
	local rc = _rc
	if `rc' {
		di as txt "NOTE `id': MPLE fit stopped with r(`rc'); retrying with mplecheck(off)"
		capture noisily nwergm `net', edges `opts' method(mple) mplecheck(off)
		local rc = _rc
	}
	if `rc' {
		di as err "FAIL `id': nwergm `net', edges `opts' stopped with r(`rc')"
		exit 9
	}
	tempname S
	matrix `S' = e(obs_stats)
	local k : word count `expected'
	if colsof(`S') != `k' {
		di as err "FAIL `id': " colsof(`S') " statistics, expected `k'"
		matrix list `S'
		exit 9
	}
	forvalues j = 1/`k' {
		local x : word `j' of `expected'
		if abs(`S'[1, `j'] - (`x')) > 1e-6 * max(1, abs(`x')) {
			di as err "FAIL `id': statistic `j' is " %20.12g `S'[1, `j'] ", R gives `x'"
			matrix list `S'
			exit 9
		}
	}
	di as txt "PASS `id'"
end

* Two-mode network: mode 1 = nodes 1-4, mode 2 = nodes 5-9.
* R: B <- matrix(c(1,1,0,0,0, 0,1,1,0,0, 1,1,1,1,0, 0,0,0,0,0), 4, 5, byrow=TRUE); nb <- network(B, bipartite=4, directed=FALSE)
*    nb %v% "g" <- c(1,2,1,2, 1,1,2,2,1); nb %v% "x" <- c(1,2,3,4, 0.5,1.5,2.5,3.5,4.5)
* Mode-1 node 4 and mode-2 node 9 (the 5th event) are isolates.
* nwset, mat() bipartite puts the COLUMNS of the matrix in the first mode (see cscripts/test_nwergm_bip.do and
* test_nwergm_gofbip.do), so the matrix given to nwset is t(B): 5 rows (mode 2) x 4 columns (mode 1).
nwclear
clear
mata: B = (1,1,0,0,0 \ 0,1,1,0,0 \ 1,1,1,1,0 \ 0,0,0,0,0)
mata: st_matrix("BT", B')
nwset, mat(BT) bipartite name(bip) nooutput
qui nwsummarize bip
assert "`r(mode2)'" == "true"
assert r(nodes) == 9 & r(nodes1) == 4 & r(nodes2) == 5
assert r(edges) == 8
* a one-mode network for the refusal checks
mata: st_matrix("A1", (0,1,1\1,0,1\1,1,0))
nwset, mat(A1) undirected name(onemode) nooutput
clear
set obs 9
gen g = .
gen x = .
mata: st_store(., "g", (1\2\1\2\1\1\2\2\1))
mata: st_store(., "x", (1\2\3\4\.5\1.5\2.5\3.5\4.5))

xt_stat B_edges bip "" "8"
assert e(N) == 20
assert e(ties) == 8
xt_stat B_b1degree bip "bdegree1(0/3)" "8 1 0 2 0"                 // b1degree(0:3) = 1 0 2 0
xt_stat B_b2degree bip "bdegree2(0/3)" "8 1 1 2 1"                 // b2degree(0:3) = 1 1 2 1
xt_stat B_b1star bip "bstar1(2 3)" "8 8 4"                         // b1star(2:3) = 8 4
xt_stat B_b2star bip "bstar2(2 3)" "8 5 1"                         // b2star(2:3) = 5 1
xt_stat B_b1cov bip "bcov1(x)" "8 18"                              // b1cov("x") = 18
xt_stat B_b2cov bip "bcov2(x)" "8 14"                              // b2cov("x") = 14
xt_stat B_b1factor bip "bfactor1(g)" "8 2"                         // b1factor("g") = 2 (level 2)
xt_stat B_b2factor bip "bfactor2(g)" "8 3"                         // b2factor("g") = 3
xt_stat B_b1nodematch bip "bnodematch1(g)" "8 2"                   // b1nodematch("g") = 2
xt_stat B_b2nodematch bip "bnodematch2(g)" "8 3"                   // b2nodematch("g") = 3
xt_stat B_gwb1deg0 bip "bgwdegree1(0)" "8 3"                       // gwb1degree(0, fixed=TRUE) = 3
xt_stat B_gwb2deg0 bip "bgwdegree2(0)" "8 4"
xt_stat B_gwb1deg05 bip "bgwdegree1(.5)" "8 4.39614232683627"
xt_stat B_gwb2deg05 bip "bgwdegree2(.5)" "8 5.33522614260828"
xt_stat B_gwb1deg10 bip "bgwdegree1(10)" "8 7.99963680880642"
xt_stat B_gwb2deg10 bip "bgwdegree2(10)" "8 7.99977300241234"
xt_stat B_b1concurrent bip "bconcurrent1(all)" "8 3"               // b1concurrent = 3
xt_stat B_b2concurrent bip "bconcurrent2(all)" "8 3"               // b2concurrent = 3
xt_stat B_b1mindegree bip "bmindegree1(1/2)" "8 3 3"               // b1mindegree(1:2) = 3 3
xt_stat B_b1dsp bip "bdsp1(0/2)" "8 3 1 2"                         // b1dsp(0:2) = 3 1 2
xt_stat B_b2dsp bip "bdsp2(0/2)" "8 4 4 2"                         // b2dsp(0:2) = 4 4 2
xt_stat B_gwb1dsp bip "bgwdsp1(.5)" "8 3.78693868057473"           // gwb1dsp(0.5, fixed=TRUE)
xt_stat B_gwb2dsp bip "bgwdsp2(.5)" "8 6.78693868057473"
di "PASS block two-mode terms"

* one-mode terms that R evaluates on the whole node set of a two-mode network
xt_stat B_nodecov bip "nodecov(x)" "8 32"
xt_stat B_nodefactor bip "nodefactor(g)" "8 5"
xt_stat B_nodematch bip "nodematch(g)" "8 5"
xt_stat B_kstar bip "kstar(2)" "8 13"
xt_stat B_degree bip "degree(0/2)" "8 2 1 4"                       // degree(0:2) = 2 1 4 (both isolates)
xt_stat B_concurrent bip "concurrent" "8 6"
xt_stat B_triangle bip "triangle" "8 0"
xt_stat B_gwesp bip "gwesp(.5)" "8 0"
xt_stat B_gwdsp bip "gwdsp(.5)" "8 10.5738773611495"
xt_stat B_gwnsp bip "gwnsp(.5)" "8 10.5738773611495"
xt_stat B_esp bip "esp(0/1)" "8 8 0"
xt_stat B_dsp bip "dsp(0/2)" "8 27 5 4"
di "PASS block one-mode terms on a two-mode network"

* refused on a two-mode network, as in R ("Term may not be used with networks with directed==FALSE / bipartite > 0"),
* r(198) in nwergm.ado lines 205-221
foreach t in mutual ctriple transitiveties sender receiver {
	capture noisily nwergm bip, edges `t' method(mple)
	assert _rc == 198
}
foreach t in "gwdegree(.5)" "odegree(1)" "idegree(1)" "nodeocov(x)" "gwodegree(.5)" "structural(twopath)" {
	capture noisily nwergm bip, edges `t' method(mple)
	assert _rc == 198
}
* two-mode terms refused on a one-mode network (nwergm.ado lines 250-262)
foreach t in "bdegree1(1)" "bcov1(x)" "bgwdegree2(.5)" "bconcurrent1(all)" "bdsp1(1)" "coincidence(active(1))" {
	capture noisily nwergm onemode, edges `t' method(mple)
	assert _rc == 198
}
di "PASS block refusals"

di "ALL PASS"

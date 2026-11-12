cscript

* DRAFT, not yet run.
* xt_stats_directed: observed sufficient statistics (e(obs_stats) after method(mple)) of the directed terms on a small
* fixed network with reciprocated arcs, a sink, a source and an isolate, under all five shared-partner types, compared
* with R ergm 4.12.0 summary(); plus a near-complete directed network.
* Expected runtime: about 1 minute (about 70 small pseudolikelihood fits).
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

* D: 7 nodes, arcs 1->2 2->1 1->3 3->1 2->3 3->4 4->2 4->5 6->5; node 5 a sink, node 6 a source, node 7 an isolate
* R: ed <- rbind(c(1,2),c(2,1),c(1,3),c(3,1),c(2,3),c(3,4),c(4,2),c(4,5),c(6,5))
*    D <- add.edges(network.initialize(7, directed=TRUE), ed[,1], ed[,2]); D %v% "g" <- c(1,1,2,2,1,3,1)
*    D %v% "x" <- c(1.5,2,0,4,3.5,1,2); WD <- outer(1:7,1:7,function(i,j) 10*i+j); diag(WD) <- 0
* DK: 4 nodes, every arc except 1->2. R: Ad <- matrix(1,4,4)-diag(4); Ad[1,2] <- 0; DK <- network(Ad, directed=TRUE)
nwclear
clear
mata: E = (1,2\2,1\1,3\3,1\2,3\3,4\4,2\4,5\6,5)
mata: A = J(7, 7, 0)
mata: for (k = 1; k <= rows(E); k++) A[E[k,1], E[k,2]] = 1
mata: st_matrix("AD", A)
mata: W = 10 :* (1::7) * J(1, 7, 1) + J(7, 1, 1) * (1..7); W = W :* (1 :- I(7)); st_matrix("WD", W)
mata: B = J(4, 4, 1) - I(4); B[1,2] = 0; st_matrix("ADK", B)
nwset, mat(AD) directed name(D) nooutput
nwset, mat(WD) directed name(WD) nooutput
nwset, mat(ADK) directed name(DK) nooutput
clear
set obs 7
gen g = .
gen x = .
mata: st_store(., "g", (1\1\2\2\1\3\1))
mata: st_store(., "x", (1.5\2\0\4\3.5\1\2))

xt_stat D_edges D "" "9"
assert e(ties) == 9
assert e(N) == 42
assert "`e(directed)'" == "true"
xt_stat D_mutual D "mutual" "9 2"                                  // summary(D ~ edges + mutual)
xt_stat D_nodematch D "nodematch(g)" "9 3"
xt_stat D_nodecov D "nodecov(x)" "9 34"
xt_stat D_nodeocov D "nodeocov(x)" "9 16"
xt_stat D_nodeicov D "nodeicov(x)" "9 18"
xt_stat D_nodeofactor D "nodeofactor(g)" "9 4 1"                   // nodeofactor("g") = 4 1
xt_stat D_nodeifactor D "nodeifactor(g)" "9 3 0"                   // nodeifactor("g") = 3 0 (level 3 never receives)
xt_stat D_nodemix D "nodemix(g)" "9 3 1 2 1 0 0 0 0"               // mix.g.2.1 3.1 1.2 2.2 3.2 1.3 2.3 3.3
xt_stat D_edgecov D "edgecov(WD)" "9 286"                          // edgecov(WD), asymmetric valued covariate
xt_stat D_odegree D "odegree(0/3)" "9 2 1 4 0"
xt_stat D_idegree D "idegree(0/3)" "9 2 1 4 0"
xt_stat D_ostar D "ostar(2)" "9 4"
xt_stat D_istar D "istar(2)" "9 4"
xt_stat D_ctriple D "ctriple" "9 2"
xt_stat D_transitiveties D "transitiveties" "9 3"
xt_stat D_cyclicalties D "cyclicalties" "9 5"
xt_stat D_sender D "sender" "9 2 2 2 0 1 0"                        // sender: sender2 ... sender7
xt_stat D_receiver D "receiver" "9 2 2 1 2 0 0"                    // receiver: receiver2 ... receiver7
xt_stat D_structural_triangle D "structural(triangle)" "9 5"       // triangle on a directed network = 5
di "PASS block D: covariate, degree, star and triad terms"

* shared partners under the five types. R: desp(0:2, type=T), ddsp(0:2, type=T), dgwesp/dgwdsp/dgwnsp(0.5, fixed=TRUE, type=T)
xt_stat D_esp_OTP D "esp(0/2) type(OTP)" "9 6 3 0"
xt_stat D_esp_ITP D "esp(0/2) type(ITP)" "9 4 4 1"
xt_stat D_esp_OSP D "esp(0/2) type(OSP)" "9 6 3 0"
xt_stat D_esp_ISP D "esp(0/2) type(ISP)" "9 6 3 0"
xt_stat D_esp_RTP D "esp(0/2) type(RTP)" "9 8 1 0"
xt_stat D_dsp_OTP D "dsp(0/2) type(OTP)" "9 33 8 1"
xt_stat D_dsp_ITP D "dsp(0/2) type(ITP)" "9 33 8 1"
xt_stat D_dsp_OSP D "dsp(0/2) type(OSP)" "9 34 8 0"
xt_stat D_dsp_ISP D "dsp(0/2) type(ISP)" "9 34 8 0"
xt_stat D_dsp_RTP D "dsp(0/2) type(RTP)" "9 40 2 0"
xt_stat D_gwesp_OTP D "gwesp(.5) type(OTP)" "9 3"
xt_stat D_gwesp_ITP D "gwesp(.5) type(ITP)" "9 5.39346934028737"
xt_stat D_gwesp_OSP D "gwesp(.5) type(OSP)" "9 3"
xt_stat D_gwesp_ISP D "gwesp(.5) type(ISP)" "9 3"
xt_stat D_gwesp_RTP D "gwesp(.5) type(RTP)" "9 1"
xt_stat D_gwdsp_OTP D "gwdsp(.5) type(OTP)" "9 9.39346934028737"
xt_stat D_gwdsp_ITP D "gwdsp(.5) type(ITP)" "9 9.39346934028737"
xt_stat D_gwdsp_OSP D "gwdsp(.5) type(OSP)" "9 8"
xt_stat D_gwdsp_ISP D "gwdsp(.5) type(ISP)" "9 8"
xt_stat D_gwdsp_RTP D "gwdsp(.5) type(RTP)" "9 2"
xt_stat D_gwnsp_OTP D "gwnsp(.5) type(OTP)" "9 6.39346934028737"
xt_stat D_gwnsp_ITP D "gwnsp(.5) type(ITP)" "9 4"
xt_stat D_gwnsp_OSP D "gwnsp(.5) type(OSP)" "9 5"
xt_stat D_gwnsp_ISP D "gwnsp(.5) type(ISP)" "9 5"
xt_stat D_gwnsp_RTP D "gwnsp(.5) type(RTP)" "9 1"
* lower-case type and the default type: R's gwesp(0.5, fixed=TRUE) on a directed network is OTP = 3
xt_stat D_gwesp_lower D "gwesp(.5) type(itp)" "9 5.39346934028737"
xt_stat D_gwesp_default D "gwesp(.5)" "9 3"
* type() applies to EVERY shared-partner term of the model (help nwergm, type()): esp and gwdsp both ITP
* R: summary(D ~ edges + desp(1, type="ITP") + dgwdsp(0.5, fixed=TRUE, type="ITP")) = 9 4 9.39346934028737
* (the column order of nwergm is edges, esp, gwdsp: the esp block comes before the geometrically weighted block)
xt_stat D_type_all D "esp(1) gwdsp(.5) type(ITP)" "9 4 9.39346934028737"
di "PASS block D: shared partners, five types"

xt_stat D_gwodegree0 D "gwodegree(0)" "9 5"
xt_stat D_gwidegree0 D "gwidegree(0)" "9 5"
xt_stat D_gwodegree05 D "gwodegree(.5)" "9 6.57387736114947"
xt_stat D_gwidegree05 D "gwidegree(.5)" "9 6.57387736114947"
xt_stat D_gwodegree10 D "gwodegree(10)" "9 8.99981840028095"
xt_stat D_gwidegree10 D "gwidegree(10)" "9 8.99981840028095"
di "PASS block D: geometrically weighted degree"

* near-complete directed network
xt_stat DK_mutual DK "mutual" "11 5"
xt_stat DK_ctriple DK "ctriple" "11 6"
xt_stat DK_transitiveties DK "transitiveties" "11 11"
xt_stat DK_cyclicalties DK "cyclicalties" "11 11"
xt_stat DK_gwesp DK "gwesp(.5)" "11 13.7542853820116"
xt_stat DK_odegree DK "odegree(2/3)" "11 1 3"
xt_stat DK_istar DK "istar(3)" "11 3"
di "PASS block DK: near-complete directed network"

* triangle on a directed network: R's summary(D ~ triangle) = 5 and ergm() accepts it; nwergm refuses the option
* triangle there (nwergm.ado around line 548) and offers structural(triangle) (checked above). Recorded, not asserted.
capture noisily nwergm D, edges triangle method(mple)
if _rc == 0 {
	matrix __S = e(obs_stats)
	assert abs(__S[1,2] - 5) < 1e-9
	di as txt "PASS triangle on a directed network (as R)"
}
else di as txt "SOFT triangle on a directed network refused with r(" _rc "); R gives 5 (structural(triangle) works)"

di "ALL PASS"

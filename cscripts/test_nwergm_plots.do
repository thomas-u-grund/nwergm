cscript

* nwergm result plots: estat gof, plot (one panel per statistic of gof(): model statistics, degree, in-/out-degree, edgewise and dyadwise
* shared partners, triad census, geodesic distance, two-mode degrees), estat mcmcdiag, plot, estat posterior and estat mcmcdiag after a
* Bayesian fit; name(), saving(), export() and graph options; error paths.
* The core package nwcommands is found through the environment variable NWCORE (path of the core checkout).
local nwcore : env NWCORE
if `"`nwcore'"' == "" {
	di as error "set the environment variable NWCORE to the directory of the nwcommands (core) package"
	exit 198
}
adopath ++ `"`nwcore'"'
adopath ++ `"`c(pwd)'"'
local out `"`c(tmpdir)'/nwergm_plots_test"'
capture mkdir `"`out'"'
local mc mcmcsamplesize(300) mcmcburnin(500) mcmcinterval(20) mcmleiterations(3) seed(1)

* ---- undirected: every statistic, name(), saving(), export(), graph options
nwclear
nwwebuse florentine, nwclear
qui nwergm flomarriage, edges gwesp(.5) `mc'
capture erase `"`out'/g1.gph"'
capture erase `"`out'/g1.png"'
estat gof, nsim(20) seed(3) plot gof(model degree espartners dspartners triadcensus distance) name(pg1) saving(`"`out'/g1.gph"') export(`"`out'/g1.png"', width(1200)) scheme(s2color)
graph describe pg1
confirm file `"`out'/g1.gph"'
confirm file `"`out'/g1.png"'
di as text "  PASS: undirected, six panels, name(), saving(), export(), graph options"
* default: name gof; the default statistics
estat gof, nsim(10) seed(3) plot
graph describe gof
graph drop gof
di as text "  PASS: default panels and name"

* ---- directed
nwclear
nwset, mat((0,1,1,0,0,1\1,0,0,0,0,0\0,0,0,1,0,0\0,0,0,0,1,0\1,0,0,0,0,1\0,1,0,0,0,0)) directed name(toynet)
qui nwergm toynet, edges mutual `mc'
estat gof, nsim(10) seed(3) plot gof(model idegree odegree espartners dspartners triadcensus distance) name(pg2) export(`"`out'/g2.png"', width(1200)) title("directed")
graph describe pg2
confirm file `"`out'/g2.png"'
di as text "  PASS: directed panels"

* ---- two-mode
nwclear
clear
mata: rseed(13); B = runiform(8,10) :< 0.3; st_matrix("Bbip", B)
nwset, mat(Bbip) bipartite name(bip) nooutput
qui nwergm bip, edges bstar1(2) `mc'
estat gof, nsim(10) seed(3) plot name(pg3) export(`"`out'/g3.png"', width(1200))
graph describe pg3
confirm file `"`out'/g3.png"'
di as text "  PASS: two-mode panels (b1degree, b2degree, dspartners, distance)"

* ---- estat mcmcdiag, plot
nwclear
nwwebuse florentine, nwclear
qui nwergm flomarriage, edges gwesp(.5) `mc'
estat mcmcdiag, plot name(pm1) saving(`"`out'/m1.gph"') export(`"`out'/m1.png"', width(900)) title("MCMC")
graph describe pm1
confirm file `"`out'/m1.gph"'
confirm file `"`out'/m1.png"'
di as text "  PASS: mcmcdiag plot with saving(), export() and graph options"

* ---- Bayesian fit: estat posterior, estat mcmcdiag
qui nwergm flomarriage, edges triangle estimate(bayes) seed(2) iterations(300) burnin(100)
estat posterior, plot(both) name(pb1) gsaving(`"`out'/b1.gph"') export(`"`out'/b1.png"', width(900)) title("posterior")
graph describe pb1
confirm file `"`out'/b1.gph"'
confirm file `"`out'/b1.png"'
estat mcmcdiag, plot name(pb2) saving(`"`out'/b2.gph"') export(`"`out'/b2.png"', width(900))
graph describe pb2
confirm file `"`out'/b2.gph"'
confirm file `"`out'/b2.png"'
di as text "  PASS: Bayesian plots"

* ---- error paths
nwclear
nwwebuse florentine, nwclear
qui nwergm flomarriage, edges gwesp(.5) `mc'
capture estat gof, nsim(10) saving(`"`out'/x.gph"')
assert _rc == 198
capture estat gof, nsim(10) export(`"`out'/x.png"')
assert _rc == 198
capture estat gof, nsim(10) title("x")
assert _rc == 198
capture estat gof, nsim(10) gof(nosuch) plot
assert _rc == 198
capture estat gof, nsim(10) gof(idegree) plot
assert _rc == 198
capture estat mcmcdiag, saving(`"`out'/x.gph"')
assert _rc == 198
capture estat mcmcdiag, export(`"`out'/x.png"')
assert _rc == 198
qui nwergm flomarriage, edges triangle estimate(bayes) seed(2) iterations(200) burnin(50)
capture estat posterior, gsaving(`"`out'/x.gph"')
assert _rc == 198
capture estat posterior, export(`"`out'/x.png"')
assert _rc == 198
capture estat mcmcdiag, saving(`"`out'/x.gph"')
assert _rc == 198
di as text "  PASS: error paths"
di as text "ALL TESTS PASSED"

* header: sysdir PLUS scratch, adopath this repo + lib/plugins/macos + core, then do unw_ergm.do; see cscripts/test_nwergm_obsbdeg.do for the two-mode data
mata: n = 24; rseed(11); R = runiform(n,n) :< 0.18; R = R :* (1 :- I(n)); A = ((R + R') :> 0); st_matrix("Aund", A)
nwset, mat(Aund) undirected name(und) nooutput
forvalues s = 1/30 {
  capture quietly nwergm und, edges triangle mcmletermination(none) mcmcsamplesize(300) mcmcburnin(500) mcmcinterval(20) mcmleiterations(3) seed(`s')
  di "SEED `s' rc=" _rc
}

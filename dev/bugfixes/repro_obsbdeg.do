* header: sysdir PLUS scratch, adopath this repo + lib/plugins/macos + core, then do unw_ergm.do; see cscripts/test_nwergm_obsbdeg.do for the two-mode data
nwergm bip, edges bstar1(2) obsconstraints(b1degrees) mcmcsamplesize(300) mcmcburnin(500) mcmcinterval(20) mcmleiterations(3)
nwergm bip, edges bstar1(2) obsconstraints(b2degrees) mcmcsamplesize(300) mcmcburnin(500) mcmcinterval(20) mcmleiterations(3)

* header: sysdir PLUS scratch, adopath this repo + lib/plugins/macos + core, then do unw_ergm.do; see cscripts/test_nwergm_obsbdeg.do for the two-mode data
nwergm bip, edges bstar1(2) mcmcsamplesize(300) mcmcburnin(500) mcmcinterval(20) mcmleiterations(3)
estat gof, gof(b1degree b2degree)
matrix list r(gof_b1degree)
matrix list r(gof_b2degree)
estat gof, gof(b1degree b2degree dspartners) 

do setup.doh
*# kap_data
nwwebuse kapferer, nwclear
nwset
nwsummarize kapferer_t2
*# kap_tri
capture noisily nwergm kapferer_t2, edges triangle seed(1) mcmcsamplesize(1000)
display "return code: " _rc
*# kap_gw
nwergm kapferer_t2, edges gwesp(0.5) seed(1)
*# kap_gof
estat gof, nsim(100) seed(2)
*# kap_end

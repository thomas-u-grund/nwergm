do setup.doh
* run times of the Lazega model (Section "The Lazega lawyers"): default settings, long chain, and the Mata sampler; written to r/timing.csv
nwwebuse lazega, nwclear
encode practice, generate(prac)
file open fh using "r/timing.csv", write replace text
file write fh "setting,seed,seconds,iterations" _n
forvalues s = 1/5 {
	timer clear 1
	timer on 1
	quietly nwergm lazega_fr, edges mutual nodematch(prac) nodeicov(seniority) gwesp(0.5) seed(`s')
	timer off 1
	quietly timer list 1
	file write fh "default,`s'," %9.2f (r(t1)) "," (e(mcmle_iterations)) _n
}
forvalues s = 1/5 {
	timer clear 1
	timer on 1
	quietly nwergm lazega_fr, edges mutual nodematch(prac) nodeicov(seniority) gwesp(0.5) seed(`s') mcmcinterval(1000) mcmcburnin(20000)
	timer off 1
	quietly timer list 1
	file write fh "long,`s'," %9.2f (r(t1)) "," (e(mcmle_iterations)) _n
}
timer clear 1
timer on 1
quietly nwergm lazega_fr, edges mutual nodematch(prac) nodeicov(seniority) gwesp(0.5) seed(1) nonative
timer off 1
quietly timer list 1
file write fh "default nonative,1," %9.2f (r(t1)) "," (e(mcmle_iterations)) _n
file close fh

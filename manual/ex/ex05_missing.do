do setup.doh
*# miss_make
nwwebuse florentine, nwclear
nwtomata flomarriage, mat(A)
mata: A[1,2] = A[2,1] = .
mata: A[3,5] = A[5,3] = .
mata: A[4,9] = A[9,4] = .
mata: st_matrix("Am", A)
tempfile nodes
save `nodes'
nwset, mat(Am) undirected name(flomiss)
use `nodes', clear
*# miss_dd
nwergm flomarriage, edges nodecov(wealth)
nwergm flomiss, edges nodecov(wealth)
display "missing dyads: " e(nmissing) "   informative dyads: " e(N)
*# miss_mcmle
nwergm flomiss, edges nodecov(wealth) gwesp(0.5) seed(1)
display "missing dyads: " e(nmissing) "   informative dyads: " e(N)
*# miss_cov
preserve
replace wealth = . in 3
capture noisily nwergm flomarriage, edges nodecov(wealth)
display "return code: " _rc
restore
*# cmp_data
nwwebuse lazega, nwclear
encode practice, generate(prac)
*# cmp_m1
nwergm lazega_fr, edges mutual nodematch(prac) seed(1) mcmcinterval(1000) mcmcburnin(20000)
estimates store m1
*# cmp_m2
nwergm lazega_fr, edges mutual nodematch(prac) gwesp(0.5) seed(1) mcmcinterval(1000) mcmcburnin(20000)
estimates store m2
*# cmp_ic
estimates stats m1 m2
*# cmp_lr
lrtest m2 m1
*# cmp_pred
predict, frame(pp) pr
frame pp: summarize p
frame pp: list in 1/5
*# cmp_predm
predict, matrix(P) pr
matrix P5 = P[1..5, 1..5]
matrix list P5, format(%7.4f)
*# cmp_end

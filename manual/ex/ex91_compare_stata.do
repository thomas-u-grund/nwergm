do setup.doh
* Fits of the comparison with R (chapter "Validation"): the estimates are written to r/stata_fits.csv, the observed statistics to r/stata_stats.csv.
capture program drop savefit
program savefit
	args file label
	tempname b V
	matrix `b' = e(b)
	matrix `V' = e(V)
	local names : colnames `b'
	local k 0
	foreach nm of local names {
		local ++k
		file write `file' `"`label',`nm',"' %18.10g (`b'[1,`k']) "," %18.10g (sqrt(`V'[`k',`k'])) _n
	}
end
file open fh using "r/stata_fits.csv", write replace text
file write fh "fit,term,est,se" _n

* Florentine, dyad-independent
nwwebuse florentine, nwclear
quietly nwergm flomarriage, edges nodecov(wealth)
savefit fh flo_mple

* Lazega
nwwebuse lazega, nwclear
encode practice, generate(prac)
quietly nwergm lazega_fr, edges mutual nodematch(prac) nodeicov(seniority) estimate(mple)
savefit fh laz_mple
forvalues s = 1/5 {
	quietly nwergm lazega_fr, edges mutual nodematch(prac) nodeicov(seniority) gwesp(0.5) seed(`s')
	savefit fh laz_mcmle_`s'
}
forvalues s = 1/5 {
	quietly nwergm lazega_fr, edges mutual nodematch(prac) nodeicov(seniority) gwesp(0.5) seed(`s') mcmcburnin(3000) mcmcinterval(50)
	savefit fh laz_mcmleO_`s'
}
* observed statistics of the model (first row of the model block of estat gof)
quietly nwergm lazega_fr, edges mutual nodematch(prac) nodeicov(seniority) gwesp(0.5) seed(1)
quietly estat gof, gof(model) nsim(2) seed(1)
matrix G = r(gof_model)
local names : rownames G
file open fs using "r/stata_stats.csv", write replace text
file write fs "net,term,obs" _n
local k 0
foreach nm of local names {
	local ++k
	file write fs `"lazega,`nm',"' %18.10g (G[`k',1]) _n
}
file close fs

* the coefficients of a fit, written for the simulation check (ex97_simcheck.do, r/simcheck.R)
nwwebuse lazega, nwclear
encode practice, generate(prac)
quietly nwergm lazega_fr, edges mutual nodematch(prac) nodeicov(seniority) gwesp(0.5) seed(1)
matrix bsim = e(b)
local names : colnames bsim
file open fc using "r/sim_coef.csv", write replace text
file write fc "term,coef" _n
local k 0
foreach nm of local names {
	local ++k
	file write fc `"`nm',"' %18.12g (bsim[1,`k']) _n
}
file close fc

* the simulated two-mode network of the manual (see ex06): mode 1 = the 30 people, mode 2 = the 12 clubs
clear
nwclear
set seed 20261024
mata:
g1 = (runiform(30,1) :> 0.5) :+ 1
g2 = (runiform(12,1) :> 0.5) :+ 1
P = J(30,12,0.08)
for (i=1;i<=30;i++) for (j=1;j<=12;j++) if (g1[i]==g2[j]) P[i,j] = 0.30
B = (runiform(30,12) :< P)
st_matrix("B", B')
end
nwset, mat(B) bipartite name(clubs)
set obs 42
generate byte kind = .
mata: st_store(., "kind", (g1 \ g2))
quietly nwergm clubs, edges nodemix(kind)
savefit fh clubs_mple
quietly nwergm clubs, edges nodemix(kind) bdegree2(5 6) bstar1(2) estimate(mple)
savefit fh clubs_mple2
file close fh

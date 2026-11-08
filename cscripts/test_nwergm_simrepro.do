cscript
* nwergm simulate after a fit: seed() must reproduce the draws however often simulate is run, and simulate must not
* change the fit's last network. Regression test: up to 1.4.0 the chain changed the network the fit leaves behind
* (the start of later simulations without basis(), and with basis() the order of its ties, which steers the TNT
* proposal), so the same call with the same seed gave other draws the second time. Also checks that output(stats)
* (one pass of the sampler) and output(network) (one call per draw) draw from the same distribution.
local nwcore : env NWCORE
if `"`nwcore'"' == "" {
	di as error "set the environment variable NWCORE to the directory of the nwcommands (core) package"
	exit 198
}
adopath ++ `"`nwcore'"'
adopath ++ `"`c(pwd)'"'
quietly do `"`nwcore'/unw_core.do"'
do unw_ergm.do
capture adopath ++ "lib/plugins/macos"
capture adopath ++ "lib/plugins/unix"
capture adopath ++ "lib/plugins/windows"
nwwebuse lazega, nwclear
encode practice, generate(prac)
quietly nwergm lazega_fr, edges nodematch(prac) gwesp(.5) seed(1) mcmleiterations(3) nologlik
matrix b = e(b)
* A: the same call three times, without and with basis(), output(stats) and output(network)
foreach o in "" "basis(lazega_fr)" "nosequential" {
	foreach out in stats network {
		forvalues k = 1/3 {
			quietly nwergm simulate, nsim(20) output(`out') seed(7) burnin(2000) interval(100) `o'
			matrix S`k' = r(stats)
		}
		assert mreldif(S1, S2) == 0
		assert mreldif(S1, S3) == 0
		di "PASS same seed three times, output(`out') `o': identical"
	}
}
* B: simulate does not change the fit: a fit with the same seed after simulations equals the first fit
quietly nwergm lazega_fr, edges nodematch(prac) gwesp(.5) seed(1) mcmleiterations(3) nologlik
assert mreldif(b, e(b)) < 1e-12
quietly nwergm simulate, nsim(5) output(stats) seed(3)
matrix T1 = r(stats)
quietly nwergm simulate, nsim(50) output(stats) seed(4) basis(lazega_fr)
quietly nwergm simulate, nsim(5) output(stats) seed(3)
assert mreldif(T1, r(stats)) == 0
di "PASS a simulation with basis() in between does not change the next one"
* C: output(stats) and output(network) draw from the same distribution (means over 400 draws, 4 standard errors)
quietly nwergm simulate, nsim(400) output(stats) seed(11)
matrix A = r(stats)
quietly nwergm simulate, nsim(400) output(network) seed(12) generate(srep)
matrix B = r(stats)
nwdrop srep_*
mata: A = st_matrix("A"); B = st_matrix("B")
mata: z = abs(mean(A) - mean(B)) :/ sqrt(diagonal(variance(A))' / 40 + diagonal(variance(B))' / 40)
mata: z
mata: st_local("zmax", strofreal(max(z)))
assert `zmax' < 4
di "PASS output(stats) and output(network): same means (largest |z| `zmax', effective size taken as 40 of 400)"
di "ALL OK"

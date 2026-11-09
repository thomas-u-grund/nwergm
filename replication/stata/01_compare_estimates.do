* Table 4 of the article, Stata side: the models of R/01_compare_estimates.R on the same networks, several seeds.
* Writes results/cmp_nwergm.csv (model, seed, term, estimate, std. err., seconds, converged). Run time: a few minutes.
do stata/setup.do
nwergm version
tempname ph
capture erase results/cmp_nwergm.csv
postfile `ph' str24 model int seed str40 term double(b se secs conv) using results/cmp_nwergm_tmp.dta, replace

capture program drop runfit
program runfit
    args ph model seed cmd
    timer clear 9
    timer on 9
    quietly `cmd' seed(`seed')
    timer off 9
    quietly timer list 9
    local secs = r(t9)
    tempname b V
    matrix `b' = e(b)
    matrix `V' = e(V)
    local nm : colnames `b'
    local k = colsof(`b')
    local conv = e(converged)
    if "`conv'" == "." local conv = 1
    forvalues i = 1/`k' {
        local t : word `i' of `nm'
        post `ph' ("`model'") (`seed') ("`t'") (`b'[1,`i']) (sqrt(`V'[`i',`i'])) (`secs') (`conv')
    }
    di "`model' seed `seed': `secs' s"
end

* --- toy network (5 nodes) ---
nwclear
nwset, mat((0,1,1,0,0\1,0,0,0,0\0,0,0,1,0\0,0,0,0,1\1,0,0,0,0)) directed name(toynet)
forvalues s = 1/10 {
    runfit `ph' toy `s' "nwergm toynet, edges mutual method(mcmle)"
}
* --- Florentine ---
nwwebuse florentine, nwclear
forvalues s = 1/10 {
    runfit `ph' flo_gwesp `s' "nwergm flomarriage, edges nodecov(wealth) gwesp(.5)"
}
runfit `ph' flo_mple 1 "nwergm flomarriage, edges nodecov(wealth)"
* --- Lazega ---
nwwebuse lazega, nwclear
foreach v in office practice status {
    encode `v', generate(`v'n)
}
runfit `ph' lazega_dindep 1 "nwergm lazega_adv, edges nodematch(officen practicen) nodeofactor(statusn) nodeifactor(statusn)"
forvalues s = 1/5 {
    runfit `ph' lazega_final `s' "nwergm lazega_adv, edges mutual nodematch(officen practicen) nodeofactor(statusn) nodeifactor(statusn) gwesp(.5)"
}
forvalues s = 1/5 {
    runfit `ph' lazega_sym `s' "nwergm lazega_fr, edges mutual nodematch(practicen) operators(Symmetrize(triangle, rule(strong)))"
}
* --- Davis ---
nwwebuse davis, nwclear
encode title, generate(titlen)
forvalues s = 1/10 {
    runfit `ph' davis `s' "nwergm davis, edges bfactor1(titlen) bgwdegree2(1)"
}
* --- Mesa ---
nwwebuse mesa, nwclear
encode race, generate(racen)
forvalues s = 1/5 {
    runfit `ph' mesa_gwesp `s' "nwergm mesa, edges nodematch(grade racen) gwesp(.25)"
}
forvalues s = 1/3 {
    runfit `ph' mesa_curved `s' "nwergm mesa, edges nodematch(grade racen) gwespfree(.25)"
}
postclose `ph'
use results/cmp_nwergm_tmp.dta, clear
export delimited using results/cmp_nwergm.csv, replace
erase results/cmp_nwergm_tmp.dta
display "written results/cmp_nwergm.csv"

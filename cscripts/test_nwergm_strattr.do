* test_nwergm_strattr: string node attributes (1.5.11) give the same fit as their
* encoded versions, leave the data as they were, and work for simulate and estat
cscript

* The core package nwcommands is found through the environment variable NWCORE (path of the core checkout).
local nwcore : env NWCORE
if `"`nwcore'"' == "" {
	di as error "set the environment variable NWCORE to the directory of the nwcommands (core) package"
	exit 198
}
adopath ++ `"`nwcore'"'
adopath ++ `"`c(pwd)'"'
quietly do `"`nwcore'/unw_core.do"'
do unw_ergm.do
nwwebuse lazega, nwclear
foreach v in office practice status {
    encode `v', generate(`v'n)
}
* 1. encoded (the old way) and string attributes give identical estimates (MPLE and MCMLE)
nwergm lazega_adv, edges mutual nodematch(officen practicen) nodeofactor(statusn) nodeifactor(statusn) method(mple)
matrix bn = e(b)
describe, varlist
local vars0 `r(varlist)'
datasignature
local sig0 `r(datasignature)'
nwergm lazega_adv, edges mutual nodematch(office practice) nodeofactor(status) nodeifactor(status) method(mple)
matrix bs = e(b)
assert mreldif(bn, bs) < 1e-12
local cn : colnames bs
assert "`cn'" == "edges mutual nodematch_office nodematch_practice nodeofactor_status_2 nodeifactor_status_2"
* the data are unchanged: same variables in the same order, same values, office still a string
describe, varlist
assert "`r(varlist)'" == "`vars0'"
datasignature
assert "`r(datasignature)'" == "`sig0'"
confirm string variable office
* MCMLE with gwesp
nwergm lazega_adv, edges mutual nodematch(officen practicen) gwesp(.5) seed(12345)
matrix bn = e(b)
nwergm lazega_adv, edges mutual nodematch(office practice) gwesp(.5) seed(12345)
matrix bs = e(b)
assert mreldif(bn, bs) < 1e-12
* 2. simulate and estat after a string fit
nwergm simulate, nsim(3) output(network) seed(1) generate(s)
quietly nwsummarize s_3
assert r(nodes) == 71
confirm string variable office
estat gof, nsim(20) seed(1)
confirm string variable office
* 3. simulate from chosen coefficients with a string covariate
preserve
nwergm simulate 71, edges mutual nodematch(office) directed theta(-2.4 1.5 1) nsim(1) seed(5) generate(h)
restore
confirm string variable office
* same draw as with the encoded attribute
nwtomata h, mat(H1)
nwdrop h
preserve
nwergm simulate 71, edges mutual nodematch(officen) directed theta(-2.4 1.5 1) nsim(1) seed(5) generate(h)
restore
nwtomata h, mat(H2)
mata: assert(H1 == H2)
* 4. an error inside the call leaves the strings in place
capture nwergm lazega_adv, edges nodematch(office) nosuchoption
assert _rc
confirm string variable office
datasignature
assert "`r(datasignature)'" == "`sig0'"
* 4b. a term that uses the values as numbers still refuses a string variable
capture nwergm lazega_adv, edges nodecov(office) method(mple)
assert _rc == 109
confirm string variable office
* nodemix and nodefactor with strings equal their encoded versions
nwergm lazega_adv, edges nodemix(practicen) nodefactor(officen) method(mple)
matrix bn = e(b)
nwergm lazega_adv, edges nodemix(practice) nodefactor(office) method(mple)
assert mreldif(bn, e(b)) < 1e-12
* 5. missing strings are reported as missing attribute values (416)
generate str10 office2 = office
replace office2 = "" in 3
capture nwergm lazega_adv, edges nodematch(office2) method(mple)
assert _rc == 416
confirm string variable office2
assert office2 == "" in 3
display "test_nwergm_strattr: ALL TESTS PASSED"

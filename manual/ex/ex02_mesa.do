do setup.doh
*# mesa_data
nwwebuse mesa, nwclear
nwset
describe, short
tabulate grade
tabulate race
tabulate sex
*# mesa_encode
encode race, generate(race_n)
encode sex, generate(sex_n)
label list race_n
label list sex_n
*# mesa_edges
nwergm mesa, edges
*# mesa_nm
nwergm mesa, edges nodematch(grade)
*# mesa_nm3
nwergm mesa, edges nodematch(grade race_n sex_n)
*# mesa_diff
nwergm mesa, edges nodematch(grade) nodematchdiff(sex_n)
*# mesa_mix
nwergm mesa, edges nodematch(grade) nodefactor(race_n) nodemix(sex_n)
*# mesa_end

do setup.doh
* writes the networks and attributes of the examples to the csv files in r/, for the comparison with R's ergm (r/compare.R)
nwwebuse florentine, nwclear
nwtomata flomarriage, mat(A)
preserve
keep wealth
export delimited using "r/flo_nodes.csv", replace
restore
mata: st_matrix("A", A)
svmat double A, names(c)
keep c*
export delimited using "r/flo_adj.csv", replace novarnames
drop _all
nwwebuse lazega, nwclear
nwtomata lazega_fr, mat(L)
mata: st_matrix("L", L)
keep seniority practice
encode practice, generate(prac)
export delimited using "r/laz_nodes.csv", replace
drop _all
svmat double L, names(c)
export delimited using "r/laz_adj.csv", replace novarnames
* two-mode network of ex06
drop _all
nwclear
set seed 20261024
mata:
g1 = (runiform(30,1) :> 0.5) :+ 1
g2 = (runiform(12,1) :> 0.5) :+ 1
P = J(30,12,0.08)
for (i=1;i<=30;i++) for (j=1;j<=12;j++) if (g1[i]==g2[j]) P[i,j] = 0.30
B = (runiform(30,12) :< P)
st_matrix("B", B)
st_matrix("G", (g1 \ g2))
end
svmat double B, names(c)
export delimited using "r/clubs_inc.csv", replace novarnames
drop _all
svmat double G, names(kind)
export delimited using "r/clubs_kind.csv", replace

do setup.doh
*# typ_make
clear
set seed 20261026
set obs 150
generate int a = ceil(runiform()*40)
generate int b = ceil(runiform()*40)
drop if a == b
duplicates drop a b, force
generate byte w = 1 + (runiform() > 0.7)
generate byte one = 1
tempfile edges
save `edges'
*# typ_valued
nwfromedge a b w, undirected name(val) valued
nwsummarize val
nwergm val, edges
*# typ_binary
use `edges', clear
nwfromedge a b one, undirected name(val1) valued
nwergm val1, edges
*# typ_cov2make
clear
set seed 20261024
nwclear
mata: g1 = (runiform(30,1) :> 0.5) :+ 1
mata: g2 = (runiform(12,1) :> 0.5) :+ 1
mata: B = (runiform(30,12) :< 0.2)
mata: C = (runiform(30,12) :< 0.3)
mata: st_matrix("B", transposeonly(B))
mata: st_matrix("C", transposeonly(C))
nwset, mat(B) bipartite name(clubs)
nwset, mat(C) bipartite name(visits)
set obs 42
*# typ_cov2
nwergm clubs, edges edgecov(visits)
*# typ_end

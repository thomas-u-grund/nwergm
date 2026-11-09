* Writes the networks of the article to data/ as CSV, so that R reads the same data as Stata.
* The files are already in data/; this do-file shows where they come from. The first four benchmark networks
* (bench_net, net100dir, net100undir, net500 and their attributes) are fixed inputs of earlier benchmarks.
do stata/setup.do
nwwebuse florentine, nwclear
outsheet seat wealth using "data/flo_attr.csv", comma replace nolabel
expnet flomarriage "data/flo_marriage.csv"
nwwebuse lazega, nwclear
foreach v in office practice status {
	encode `v', generate(`v'n)
}
outsheet officen practicen statusn using "data/lazega_attr.csv", comma replace nolabel
expnet lazega_adv "data/lazega_adv.csv"
expnet lazega_fr "data/lazega_fr.csv"
nwwebuse mesa, nwclear
encode race, generate(racen)
outsheet grade racen using "data/mesa_attr.csv", comma replace nolabel
expnet mesa "data/mesa.csv"
nwwebuse davis, nwclear
encode title, generate(titlen)
outsheet _nwmode titlen using "data/davis_attr.csv", comma replace nolabel
expnet davis "data/davis_full.csv"
* benchmark networks 5 and 6
set seed 20260826
nwclear
nwrandom 1000, prob(0.006) name(bench1000)
generate grp = ceil(3*runiform())
outsheet grp using "data/attr1000.csv", comma nonames replace nolabel
expnet bench1000 "data/net1000.csv"
set seed 20260903
nwclear
nwrandom 1000, prob(0.006) undirected name(bench8)
expnet bench8 "data/net_sp.csv"

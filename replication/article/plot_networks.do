* Network plots for the nwergm article: Florentine marriages (fig_florentine.pdf)
* and Lazega advice (fig_lazega.pdf). Stata 17, nwcommands 3.10.0.
* Globals NWC (core directory) and PLUSDIR (empty scratch PLUS) are set by the caller.
capture program drop nwinstall
clear all
sysdir set PLUS "$PLUSDIR"
adopath ++ "$NWC"
adopath ++ "$NWC/lib"
adopath ++ "$NWC/lib/plugins/macos"
capture set scheme stsj
set seed 2026

* Florentine marriages: node size by wealth (the attribute of nodecov(wealth))
nwwebuse florentine, nwclear
* style shared with the nwsaom article: grey markers with a thin black outline, thin grey ties, no legend (the caption gives the key)
nwplot flomarriage, layout(kk) lab size(wealth, legendoff) nodefactor(1.1) scatteropt(mfcolor(gs6) mlcolor(black) mlwidth(vthin)) lineopt(lcolor(gs10) lwidth(thin)) labelopt(mlabposition(6) mlabgap(*2.5) mlabsize(small) mlabcolor(black)) legend(off) xsize(5.6) ysize(4.2) name(flo, replace)
graph export fig_florentine.pdf, name(flo) replace

* Lazega advice: colour by office, shape by status
nwwebuse lazega, nwclear
* ties lighter than in the other figures (gs13): the network is dense
nwplot lazega_adv, layout(kk) arrows color(office, legendoff colorpalette(gs11 gs6 black)) symbol(status, legendoff symbolpalette(circle diamond)) nodefactor(.6) arrowfactor(.3) scatteropt(mlcolor(black) mlwidth(vthin)) lineopt(lcolor(gs13) lwidth(vthin)) legend(off) xsize(5.6) ysize(4.2) name(laz, replace)
graph export fig_lazega.pdf, name(laz) replace

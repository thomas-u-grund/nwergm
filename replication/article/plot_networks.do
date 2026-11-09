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

* Florentine marriages: shade and shape by council seat (the attribute of nodematch(seat))
nwwebuse florentine, nwclear
nwplot flomarriage, layout(kk) lab color(seat, colorpalette(gs11 gs3)) symbol(seat, legendoff symbolpalette(circle diamond)) nodefactor(.45) labelopt(mlabposition(6) mlabgap(*2.5) mlabsize(small) mlabcolor(black)) legend(cols(1) size(small) position(3) region(lstyle(none))) xsize(5.6) ysize(4.2) name(flo, replace)
graph export fig_florentine.pdf, name(flo) replace

* Lazega advice: colour by office, shape by status
nwwebuse lazega, nwclear
nwplot lazega_adv, layout(kk) arrows color(office, colorpalette(gs11 gs6 black)) symbol(status, symbolpalette(circle diamond)) nodefactor(.32) arrowfactor(.3) lineopt(lcolor(gs13) lwidth(vthin)) legend(cols(1) size(small) position(3) region(lstyle(none))) xsize(5.6) ysize(4.2) name(laz, replace)
graph export fig_lazega.pdf, name(laz) replace

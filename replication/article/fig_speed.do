version 17
capture set scheme stsj
* ---------- Figure: ergm vs nwergm, seven seeds
import delimited using fig_speed_bench.csv, clear varnames(1)
gen row = .
local i 0
foreach b in Mesa Lazega B6 B5 B4 B3 B2 B1 {
	local ++i
	quietly replace row = `i' if bench=="`b'"
}
label define rl 1 "Faux Mesa High, 205 nodes" 2 "Lazega advice, 71 nodes" ///
	3 "1,000 nodes, sparse, gwesp+gwnsp" 4 "1,000 nodes, directed" ///
	5 "500 nodes, sparse, gwesp" 6 "100 nodes, undirected, gwesp" ///
	7 "100 nodes, directed" 8 "30 nodes, directed"
label values row rl
gen y = row + cond(prog=="R", 0.15, -0.15)
bysort prog row: egen med = median(time)
gen medR0 = med if prog=="R"
gen medN0 = med if prog=="new"
bysort row: egen medR = max(medR0)
bysort row: egen medN = max(medN0)
bysort row (prog seed): gen first = _n==1
gen ratio = string(medR/medN, "%3.1f") + "{c 215}"
gen xr = 30
twoway ///
	(pcspike row medN row medR if first, lcolor(gs13) lwidth(vthick)) ///
	(scatter y time if prog=="R", msymbol(Oh) mcolor(gs9) msize(vsmall)) ///
	(scatter y time if prog=="new", msymbol(Oh) mcolor(black) msize(vsmall)) ///
	(scatter row medR if first, msymbol(O) mcolor(gs9) msize(medium)) ///
	(scatter row medN if first, msymbol(O) mcolor(black) msize(medium)) ///
	(scatter row xr if first, msymbol(none) mlabel(ratio) mlabposition(0) mlabcolor(black) mlabsize(small)) ///
	, xscale(log range(0.03 40)) ///
	xlabel(0.05 "0.05" 0.1 "0.1" 0.2 "0.2" 0.5 "0.5" 1 2 5 10, labsize(small) grid glcolor(gs14)) ///
	ylabel(1/8, valuelabel angle(0) labsize(small) nogrid) yscale(range(0.5 8.8)) ///
	xtitle("Seconds per fit (log scale)", size(small)) ytitle("") ///
	text(8.75 30 "faster by", size(small)) ///
	legend(order(5 "nwergm 1.5.2, median" 3 "single fits" 4 "ergm 4.12.0, median" 2 "single fits") ///
		rows(1) size(small) position(6) symxsize(*0.5)) ///
	graphregion(color(white)) plotregion(color(white)) name(a, replace) xsize(6.5) ysize(4)
graph export fig_speed.pdf, name(a) replace


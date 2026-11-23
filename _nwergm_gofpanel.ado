*! version 1.16.0  23nov2026 _nwergm_gofpanel.ado -- one panel of the estat gof plot with free category labels
* Copyright (C) 2026 Thomas U. Grund
* This file is part of nwergm, a Stata package derived from the R package 'ergm (statnet)' (Mark S. Handcock, David R. Hunter, Carter T. Butts, Steven M. Goodreau, Pavel N. Krivitsky, Martina Morris and contributors; GPL-3 (+ file LICENSE)).
* nwergm is free software: you can redistribute it and/or modify it under the terms of the GNU General
* Public License, version 3, as published by the Free Software Foundation. It is distributed in the hope
* that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
* or FITNESS FOR A PARTICULAR PURPOSE. See the file LICENSE for the full text.
* one panel of the estat gof plot with arbitrary category labels: obs() the observed values (1 x k), summ() the k x 5 summary (min, p25, median,
* p75, max) of the simulated draws; labs() the tick labels as pairs "position label"
capture program drop _nwergm_gofpanel
program define _nwergm_gofpanel
	syntax , OBS(name) SUMM(name) TTL(string) YTTL(string) GNAME(string) LABS(string asis)
	preserve
	qui drop _all
	mata: st_addobs(cols(`obs'))
	mata: st_store(., st_addvar("double", "observed"), `obs'')
	mata: st_store(., st_addvar("double", "ymin"), `summ'[.,1])
	mata: st_store(., st_addvar("double", "yp25"), `summ'[.,2])
	mata: st_store(., st_addvar("double", "ymedian"), `summ'[.,3])
	mata: st_store(., st_addvar("double", "yp75"), `summ'[.,4])
	mata: st_store(., st_addvar("double", "ymax"), `summ'[.,5])
	qui gen xval = _n
	twoway (rcap ymin ymax xval, lcolor(gs10)) ///
		(rbar yp25 yp75 xval, barwidth(0.5) fcolor(gs14) lcolor(gs8)) ///
		(scatter ymedian xval, mcolor(black) msymbol(diamond)) ///
		(connected observed xval, lcolor(red) mcolor(red) msymbol(circle) lwidth(medthin)), ///
		xlabel(`labs', angle(45) labsize(vsmall)) ylabel(, angle(horizontal) labsize(small)) ///
		xtitle("") ytitle("`yttl'", size(small) color(black)) ///
		title("`ttl'", size(small) color(black)) legend(off) nodraw name(`gname', replace)
	restore
end

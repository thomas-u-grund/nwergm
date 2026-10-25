*! version 1.2.2  26oct2026 _nwergm_slowwarn: warning line before a long run on the Mata fallback sampler
* Copyright (C) 2026 Thomas U. Grund
* This file is part of nwergm, a Stata package derived from the R package 'ergm (statnet)' (Mark S. Handcock, David R. Hunter, Carter T. Butts, Steven M. Goodreau, Pavel N. Krivitsky, Martina Morris and contributors; GPL-3 (+ file LICENSE)).
* nwergm is free software: you can redistribute it and/or modify it under the terms of the GNU General
* Public License, version 3, as published by the Free Software Foundation. It is distributed in the hope
* that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
* or FITNESS FOR A PARTICULAR PURPOSE. See the file LICENSE for the full text.
* _nwergm_slowwarn: one warning line before a long computation that runs on the Mata fallback sampler (the
* compiled plugin is missing for the platform, option nonative, or the model is outside the plugin's capacity).
* The Mata sampler is orders of magnitude slower (the Lazega model: 31 s against 0.6 s), so the slowness must not be silent.
capture program drop _nwergm_slowwarn
program _nwergm_slowwarn
	args what nonative
	local os = cond(c(os) == "Windows", "windows", cond(c(os) == "MacOSX", "macos", "unix"))
	if "`nonative'" == "fit" local why "the fit ran without it"
	else if "`nonative'" != "" local why "option nonative"
	else {
		capture findfile ergm_mcmc_`os'.plugin
		if _rc local why "the plugin file ergm_mcmc_`os'.plugin was not found; reinstall the package with {bf:net install nwergm, replace}"
		else local why "the model is outside the capacity of the plugin"
	}
	di as txt "(Warning: the compiled plugin is not used for `what' (`why'); the Mata fallback is much slower, possibly minutes to hours. See {help nwergm##native:Performance}.)"
end

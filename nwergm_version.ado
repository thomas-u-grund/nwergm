*! version 1.2.3  26oct2026 nwergm version: shows the package, core, plugin and reference versions
* Copyright (C) 2026 Thomas U. Grund
* nwergm is free software under the GNU General Public License, version 3 (file LICENSE).
capture program drop nwergm_version
program nwergm_version, rclass
	version 14
	local __pkgver "1.2.3"
	local __pkgdate "26oct2026"
	// the core package: its distribution date from Stata's package list (net install writes it to stata.trk)
	local __core "not found"
	local __coredate ""
	capture findfile nwset.ado
	if _rc == 0 {
		local __core "installed"
		capture confirm file `"`c(sysdir_plus)'stata.trk"'
		if _rc == 0 {
			tempname fh
			file open `fh' using `"`c(sysdir_plus)'stata.trk"', read text
			file read `fh' line
			local __in 0
			while r(eof) == 0 {
				if substr(`"`macval(line)'"', 1, 2) == "N " local __in = (trim(substr(`"`macval(line)'"', 3, .)) == "nwcommands.pkg")
				if `__in' & substr(`"`macval(line)'"', 1, 21) == "d Distribution-Date: " & "`__coredate'" == "" {
					local __coredate = trim(substr(`"`macval(line)'"', 22, .))
				}
				file read `fh' line
			}
			file close `fh'
		}
		if "`__coredate'" != "" local __core "distribution of `__coredate'"
		else local __core "installed (development copy, no distribution date)"
	}
	capture mata: st_local("__plp", ErgmNativePluginPath())
	capture mata: st_local("__pla", strofreal(ErgmNativeAvailable()))
	if "`__pla'" == "1" {
		local __plug "`__plp' (ships with the package, no separate version number)"
	}
	else local __plug "missing (see the help file for what runs without it)"
	local __ref "ergm 4.12.0"
	display as text "nwergm version `__pkgver', `__pkgdate'"
	display as text "  core package nwcommands : `__core'"
	display as text "  native plugin           : `__plug'"
	display as text "  compared with           : R ergm 4.12.0"
	display as text "  license                 : GNU GPL-3"
	return local version "`__pkgver'"
	return local date "`__pkgdate'"
	return local core "`__core'"
	return local plugin "`__plug'"
	return local reference "ergm 4.12.0"
	return local license "GPL-3"
end

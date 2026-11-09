* hdr_local.do: called by gen_logs.do.
* By default the installed packages are used: install them with
*   . net install nwcommands, from(https://nwcommands.org/net/) replace
*   . nwinstall, all
*   . nwinstall, modelpkg(nwergm)
* and install sjlog (Stata Journal) for the log files.
* To run against source trees instead, set these globals before calling gen_logs.do:
*   NWPLUS   a PLUS folder that holds only sjlog (so that no installed copy is found first)
*   NWCORE   the core nwcommands tree
*   NWERGM   the nwergm tree
clear all
set more off
if `"$NWPLUS"' != "" {
	sysdir set PLUS `"$NWPLUS"'
}
foreach t in NWCORE NWERGM {
	if `"${`t'}"' != "" {
		adopath ++ `"${`t'}"'
		adopath ++ `"${`t'}/lib"'
		adopath ++ `"${`t'}/lib/plugins/macos"'
	}
}

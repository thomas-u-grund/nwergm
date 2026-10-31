*! version 1.3.6  31oct2026 _nwergm_dlgprep.ado -- fills the lists of the nwergm dialogs when a dialog opens
* Copyright (C) 2026 Thomas U. Grund
* Part of nwergm (GPL-3, see LICENSE). Called by the dialogs (PROGRAM initialize); works with core 3.12.1.
* Fills, for the dialog named in the argument: netlist (network names), netlist_a (one action per network that sets the
* "Network type" drop-down) and fitlist (one entry: "fit" if the last estimation was nwergm, else "nofit").
capture program drop _nwergm_dlgprep
program _nwergm_dlgprep
	version 14
	syntax anything(name=dialogname)
	local d ".`dialogname'_dlg"
	qui nwset
	local nets "`r(nets)'"
	capture `d'.netlist.Arrdropall
	capture `d'.netlist_a.Arrdropall
	capture `d'.fitlist.Arrdropall
	`d'.netlist.Arrpush " "
	capture `d'.netlist_a.Arrpush "script nettype_auto"
	foreach n of local nets {
		local act "nettype_auto"
		capture {
			_nwsyntax `n', max(1)
			if "`is2mode'" == "true" local act "nettype_b"
			else if "`directed'" == "true" local act "nettype_d"
			else local act "nettype_u"
		}
		`d'.netlist.Arrpush "`n'"
		capture `d'.netlist_a.Arrpush "script `act'"
	}
	local f "nofit"
	if `"`e(cmd)'"' == "nwergm" local f "fit"
	capture `d'.fitlist.Arrpush "`f'"
end

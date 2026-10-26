* Common set-up of the example do-files of the manual. The environment variables
* NWCORE (directory of the nwcommands core), NWERGM (directory of nwergm) and
* NWPLUS (an empty scratch directory used as PLUS) are set by run_examples.sh.
capture program drop nwinstall
local nwcore : env NWCORE
local nwergm : env NWERGM
local nwplus : env NWPLUS
sysdir set PLUS "`nwplus'"
quietly adopath ++ "`nwcore'"
quietly adopath ++ "`nwcore'/lib"
quietly adopath ++ "`nwergm'/lib"
quietly adopath ++ "`nwergm'/lib/plugins/macos"
quietly adopath ++ "`nwergm'"
set more off

* Builds lib/lnwergm.mlib from the Mata source(s) of this package. Run from the root of the repository:
*   NWCORE=/path/to/nwcommands StataBE -e do lib/build.do
* The sources use the core classes (nw_def) at compile time; the core library is found through NWCORE/lib.
version 12
clear all
capture mata: mata clear
local nwcore : env NWCORE
if `"`nwcore'"' == "" {
	di as error "set the environment variable NWCORE to the directory of the nwcommands (core) package"
	exit 198
}
local root `"`c(pwd)'"'
* The library is compiled against the core's FINISHED library lib/lnwcommands.mlib (not against a fresh compile of the core source): a
* Mata class carries the time it was compiled, and objects made by the installed core are only accepted by code compiled against
* that very library (otherwise r(3021) "class compiled at different times").
capture confirm file `"`nwcore'/lib/lnwcommands.mlib"'
if _rc {
	di as error "`nwcore'/lib/lnwcommands.mlib not found: build the core library first (do lib/build.do in the core)"
	exit 601
}
adopath ++ `"`nwcore'/lib"'
mata: mata mlib index
mata: mata which nw_def()
do unw_ergm.do
mata: mata mlib create lnwergm, dir(`"`root'/lib"') replace
mata: mata mlib add lnwergm *(), dir(`"`root'/lib"')
mata: mata mlib index

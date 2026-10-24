cscript

capture adopath ++ "."
capture adopath ++ "lib"
* The core package nwcommands is found through the environment variable NWCORE (path of the core checkout).
local nwcore : env NWCORE
if `"`nwcore'"' == "" {
	di as error "set the environment variable NWCORE to the directory of the nwcommands (core) package"
	exit 198
}
adopath ++ `"`nwcore'"'
adopath ++ `"`c(pwd)'"'
quietly do `"`nwcore'/unw_core.do"'
do unw_ergm.do
capture adopath ++ "lib/plugins/macos"
capture adopath ++ "lib/plugins/unix"
capture adopath ++ "lib/plugins/windows"

* Certifies the term balance (structural(balance)) against R ergm 4.12.0: statistic, MPLE and MCMLE; reference values from dev/gen_test_balance.R

capture program drop bl_net
program bl_net
	args name kind n edges
	nwclear
	matrix __A = J(`n', `n', 0)
	local k : word count `edges'
	forvalues t = 1(2)`k' {
		local i : word `t' of `edges'
		local j : word `=`t'+1' of `edges'
		matrix __A[`i', `j'] = 1
	}
	nwset, mat(__A) `=cond("`kind'"=="und","undirected","directed")' name(`name') nooutput
end

capture program drop bl_check
program bl_check
	args net stat coefs ses
	qui nwergm `net', edges structural(balance) method(mple)
	mata: st_matrix("__bl_S", __nwergm_last_M.full_statistic(__nwergm_last_G))
	local p : word count `stat'
	forvalues j = 1/`p' {
		local e : word `j' of `stat'
		assert abs(__bl_S[1,`j'] - `e') < 1e-9
	}
	tempname b V
	matrix `b' = e(b)
	matrix `V' = e(V)
	local dmax 0
	forvalues j = 1/`p' {
		local e : word `j' of `coefs'
		local s : word `j' of `ses'
		local d1 = abs(`b'[1,`j'] - `e')
		local d2 = abs(sqrt(`V'[`j',`j']) - `s')
		if `d1' > 1e-4 * max(1, abs(`e')) | `d2' > 1e-4 * max(1, `s') {
			di as err "FAIL balance `net': coefficient `j' is " `b'[1,`j'] " (R `e'), se " sqrt(`V'[`j',`j']) " (R `s')"
			exit 9
		}
		local dmax = max(`dmax', `d1', `d2')
	}
	di "PASS balance `net': statistic exact, MPLE max difference to R " %9.2e `dmax'
end

capture program drop bl_mcmle
program bl_mcmle
	args net coefs ses
	foreach sd in 101 202 {
		set seed `sd'
		qui nwergm `net', edges structural(balance) method(mcmle) mcmcsamplesize(4000) mcmcinterval(500) mcmcburnin(20000) mcmleiterations(40) nologlik
		tempname b
		matrix `b' = e(b)
		forvalues j = 1/2 {
			local e : word `j' of `coefs'
			local s : word `j' of `ses'
			if abs(`b'[1,`j'] - `e') > 3.5 * `s' {
				di as err "FAIL balance MCMLE `net' seed `sd': coefficient `j' is " `b'[1,`j'] " but R gives `e' (se `s')"
				exit 9
			}
		}
	}
	di "PASS balance MCMLE `net': within Monte Carlo noise of R for two seeds"
end

bl_net ru und 35 `"1 3 3 5 6 9 7 9 4 10 6 10 2 13 12 13 3 14 7 14 4 17 13 17 6 18 7 18 12 18 2 19 14 19 8 20 9 20 18 20 8 21 9 21 14 21 5 22 6 22 8 22 13 22 2 23 4 23 11 23 17 23 13 24 22 24 7 25 16 25 23 25 24 25 2 26 9 26 11 26 14 26 25 26 1 27 6 27 9 27 14 27 24 27 8 28 12 28 16 28 25 28 1 29 5 29 9 29 11 29 18 29 6 30 7 30 14 30 4 31 22 31 23 31 7 32 8 32 9 32 17 32 25 32 28 32 30 32 31 32 23 33 3 34 9 34 18 34 20 34 32 34 1 35 3 35 4 35 8 35 9 35 15 35 32 35"'
bl_check ru `"              83             2035"' `"-1.56140902582281 -0.0151403881828895"' `"0.41609923581201 0.0235910750676769"'
bl_mcmle ru `"-1.59410353364754 -0.013150741764516"' `"0.578778925584008 0.0334334770403226"'

bl_net flo und 16 `"3 5 2 6 2 7 4 7 7 8 1 9 2 9 3 9 4 11 5 11 9 13 9 14 10 14 4 15 5 15 11 15 13 15 7 16 9 16 13 16"'
bl_check flo `"              20              198"' `"-1.7159284596988 0.0169020482908222"' `"0.517372476285582 0.0715649603579231"'

bl_net mesa und 205 `"9 19 15 22 1 25 8 30 23 36 16 40 25 43 11 44 29 51 1 52 2 52 9 54 30 54 15 55 22 55 29 55 51 55 1 58 21 59 25 60 43 60 13 61 51 61 55 61 18 63 22 64 59 65 55 66 64 66 27 68 1 70 56 71 11 74 44 74 47 74 15 76 22 76 25 77 43 77 47 79 66 82 53 83 55 86 1 87 25 87 87 88 1 92 25 92 87 92 27 93 1 96 87 96 36 97 79 99 1 100 2 100 96 100 21 102 47 102 8 104 30 104 59 104 65 104 47 105 79 108 101 108 1 110 87 110 92 110 96 110 89 111 31 114 9 115 54 115 90 117 109 121 17 122 22 123 55 123 64 123 1 127 52 127 87 127 103 128 18 129 56 129 81 131 89 131 57 133 2 134 110 134 44 136 53 136 74 136 83 136 78 137 96 137 100 137 114 138 47 139 64 139 105 139 123 139 16 140 21 140 33 140 103 141 109 142 124 142 115 144 25 147 58 149 96 150 100 150 127 150 132 150 1 151 127 151 13 153 47 153 38 155 87 156 55 157 64 157 66 157 123 157 18 158 70 158 129 158 8 160 30 160 104 160 124 160 140 160 142 160 1 161 124 161 79 164 99 164 149 165 160 166 36 167 153 170 79 173 99 173 108 173 164 173 1 174 74 176 32 178 123 178 165 178 87 179 96 179 137 179 138 180 14 182 181 182 87 183 88 183 31 185 112 185 114 185 132 185 138 185 149 186 34 187 75 187 91 187 165 187 15 189 22 189 47 189 102 189 123 189 139 189 2 190 52 190 161 190 183 190 47 191 189 191 98 192 146 192 139 193 140 194 148 194 160 194 18 195 70 195 158 195 134 196 179 196 63 198 165 199 34 200 47 201 102 201 136 202 5 204 75 204 125 204 9 205"'
bl_check mesa `"             203            40139"' `"3.29704662882104 -0.0407288973094528"' `"2.04869307803803 0.0105702431987353"'

bl_net rd dir 25 `"2 1 3 1 11 1 5 2 11 2 20 2 21 2 6 3 14 3 2 4 10 4 23 4 4 5 6 5 9 5 24 5 1 6 2 6 15 6 4 7 5 7 10 7 14 7 6 8 21 8 25 8 1 9 12 9 13 9 19 10 21 10 24 10 25 10 9 11 25 11 16 12 17 12 1 13 25 13 6 14 7 14 25 14 10 15 13 15 5 16 8 16 14 16 25 16 14 17 12 19 23 19 24 19 7 20 11 20 17 20 18 20 4 21 17 21 4 22 8 22 10 22 25 22 7 23 12 23 17 23 21 23 8 24 16 24 17 24 7 25 13 25"'
bl_check rd `"              71               26"' `"-1.93989388235974 -0.0716512646251646"' `"0.128416876874409 0.038806435758796"'
bl_mcmle rd `"-1.94361293000412 -0.0666459830723041"' `"0.134279407852643 0.0581775667582184"'

bl_net samp dir 18 `"2 1 3 1 5 1 6 1 7 1 8 1 12 1 14 1 15 1 16 1 18 1 1 2 3 2 7 2 8 2 12 2 14 2 15 2 16 2 17 2 18 2 1 3 17 3 18 3 5 4 6 4 8 4 10 4 11 4 1 5 4 5 6 5 9 5 10 5 11 5 13 5 15 5 4 6 8 6 2 7 12 7 13 7 15 7 16 7 18 7 1 8 7 8 9 8 10 8 11 8 5 9 6 9 8 9 10 9 4 10 8 10 4 11 5 11 14 11 1 12 2 12 7 12 9 12 14 12 15 12 16 12 3 13 5 13 10 13 17 13 18 13 1 14 2 14 10 14 11 14 12 14 15 14 2 15 14 15 16 15 7 16 9 16 11 16 3 17 18 17 3 18 13 18 17 18"'
bl_check samp `"              88              198"' `"-0.968529563663298 0.20764653766435"' `"0.148562966860655 0.0261452842329983"'

di "test_nwergm_balance: ALL OK"

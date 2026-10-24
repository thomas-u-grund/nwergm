#!/bin/zsh
# nwergm test runner (macOS). Usage: NWCORE=/path/to/nwcommands cscripts/run_tests.sh [jobs]
# NWCORE: directory of the core nwcommands package (unw_core.do and the core .ado files).
# The tests are independent do-files; each runs in its own Stata process (-e); logs are run_<test>.log in the repo root.
cd "$(dirname "$0")/.." || exit 1
python3 tools/check_version.py || exit 1
if [[ -z $NWCORE || ! -f $NWCORE/unw_core.do ]]; then echo "set NWCORE to the nwcommands (core) directory"; exit 1; fi
export NWCORE
jobs=${1:-3}
STATA=${STATA:-/Applications/Stata/StataBE.app/Contents/MacOS/StataBE}
tests=(test_nwergm_adaptive_interval test_nwergm_ado test_nwergm_bip test_nwergm_bipartite test_nwergm_changestat test_nwergm_constr test_nwergm_constraints test_nwergm_covterms test_nwergm_curved test_nwergm_demoterm test_nwergm_elist test_nwergm_ess test_nwergm_est test_nwergm_estat test_nwergm_exact_enum test_nwergm_gof test_nwergm_ll test_nwergm_mcmc test_nwergm_mcmle test_nwergm_missing test_nwergm_mple test_nwergm_mple_scale test_nwergm_native test_nwergm_ops test_nwergm_ops_native test_nwergm_simulate test_nwergm_spcache test_nwergm_speed test_nwergm_sptype test_nwergm_statistics test_nwergm_structural test_nwergm_termexpansion1 test_nwergm_termexpansion2 test_nwergm_termexpansion3 test_nwergm_termexpansion4 test_nwergm_termexpansion5 test_nwergm_termexpansion6 test_nwergm_termexpansion7 test_nwergm_termexpansion8 test_nwergm_termexpansion9 test_nwergm_variance)
tmp=$(mktemp -d)
run_one() {
  local t=$1
  echo "do cscripts/$t.do" > $tmp/run_$t.do
  $STATA -e do $tmp/run_$t.do > /dev/null 2>&1
  printf '%-34s PASS lines: %3s   errors: %s\n' $t "$(grep -c -E 'PASS|ALL OK|ALL TESTS PASSED' run_$t.log)" "$(grep -E '^r\([0-9]+\)' run_$t.log | sort -u | tr '\n' ' ')" > $tmp/res_$t.txt
  rm -f run_$t.log
}
running=0
for t in $tests; do
  run_one $t &
  running=$((running + 1))
  if (( running >= jobs )); then wait -n 2>/dev/null || wait; running=$((running - 1)); fi
done
wait
for t in $tests; do [[ -f $tmp/res_$t.txt ]] && cat $tmp/res_$t.txt; done
rm -rf $tmp
echo "done"

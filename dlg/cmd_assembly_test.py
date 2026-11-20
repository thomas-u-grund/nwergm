#!/usr/bin/env python3
"""Command-assembly test: does the PROGRAM command of every generated dialog build a command in the real dialog engine?

Why: the engine silently aborts a PROGRAM whose `if` condition it cannot evaluate (e.g. parentheses in a condition): the OK
button then does nothing and no message appears. check_dialogs.py cannot see that (db only loads the dialog).

For each dialog this copies the .dlg, turns the body of PROGRAM command into a PROGRAM that POSTINIT runs after setting some
controls, and makes it call a stub `nwdlgcap` instead of the real command; Stata (-e, batch) prints the assembled string.
Usage:  python3 dlg/cmd_assembly_test.py --nwcore <core dir> [--stata <StataBE>] [--work <scratch dir>]
Exit status 1 if any case is missing or differs. Needs Stata 17 or 18 (batch, one process).
"""
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
STATA = "/Applications/Stata 17.0/StataBE.app/Contents/MacOS/StataBE"

# dialog -> [(case id, setup statements, expected command)]; the expected text is compared after collapsing blanks
CASES = {
    "nwergm": [
        ("default", ['call main.cb_net.setvalue "w1"'], "nwergm w1, edges"),
        ("terms", ['call main.cb_net.setvalue "w1"', "call main.cx_mutual.seton", "call tri.cx_gwesp.seton"],
         "nwergm w1, edges mutual gwesp(0.5)"),
        ("bayes", ['call main.cb_net.setvalue "w1"', 'call est.f_estimate.setvalue "bayes"', 'call bayes.f_chains.setvalue "4"',
                   'call bayes.f_iterations.setvalue "200"', 'call bayes.f_priorvar.setvalue "10"', "call bayes.f_nodelayed.seton"],
         "nwergm w1, edges estimate(bayes) chains(4) iterations(200) nodelayed priorvar(10)"),
    ],
    "nwergm_ego": [
        ("default", ['call main.vn_egoid.setvalue "id"', 'call main.ed_alters.setvalue "alt"'], "nwergm ego, edges egoid(id) alters(alt)"),
        ("terms", ['call main.vn_egoid.setvalue "id"', 'call main.ed_alters.setvalue "alt"', 'call terms.ed_degree.setvalue "0/3"',
                   'call terms.ed_degrange.setvalue "4"', 'call terms.ed_degrangeto.setvalue "8"', "call terms.cx_concurrent.seton",
                   'call terms.vl_nodefactor.setvalue "sex race"', 'call terms.vl_nodematch.setvalue "sex"', 'call terms.vl_nodematchdiff.setvalue "race"',
                   'call terms.vl_nodecov.setvalue "age"', 'call terms.vl_absdist.setvalue "grade"'],
         "nwergm ego, edges degree(0/3) degrange(4) degrangeto(8) concurrent nodefactor(sex race) nodematch(sex) nodematchdiff(race) nodecov(age) absdist(grade) egoid(id) alters(alt)"),
        ("data", ['call main.vn_egoid.setvalue "id"', 'call main.ed_alters.setvalue "alt"', 'call main.ed_alteregoid.setvalue "eid"',
                  'call main.vn_weights.setvalue "w"', 'call main.ed_popsize.setvalue "1000"', 'call main.ed_ppopsize.setvalue "samp"',
                  'call main.ed_ppopmul.setvalue "2"', 'call main.cb_ppopwt.setvalue "sample"'],
         "nwergm ego, edges egoid(id) alters(alt) alteregoid(eid) weights(w) popsize(1000) ppopsize(samp) ppopmul(2) ppopwt(sample)"),
        ("mcmc", ['call main.vn_egoid.setvalue "id"', 'call main.ed_alters.setvalue "alt"', 'call mcmc.ed_seed.setvalue "7"',
                  'call mcmc.ed_interval.setvalue "2048"', 'call mcmc.ed_burnin.setvalue "5000"', 'call mcmc.ed_samplesize.setvalue "3000"',
                  'call mcmc.ed_iterations.setvalue "30"', 'call mcmc.ed_effsize.setvalue "100"', "call mcmc.cx_nonative.seton", "call mcmc.cx_verbose.seton"],
         "nwergm ego, edges egoid(id) alters(alt) seed(7) mcmcinterval(2048) mcmcburnin(5000) mcmcsamplesize(3000) mcmleiterations(30) mcmleeffectivesize(100) nonative verbose"),
        ("egodegree", ['call main.vn_egoid.setvalue "id"', 'call main.vn_egodegree.setvalue "k"', "call terms.cx_edges.setoff"], "nwergm ego, egoid(id) egodegree(k)"),
    ],
    "nwergm_simulate": [
        ("nodes, theta", ['call simctl.f_sim_nodes.setvalue "20"', 'call simctl.f_theta.setvalue "-2"'],
         "nwergm simulate 20, edges theta(-2)"),
        ("from last fit", ["call main.cx_fit.seton", 'call simctl.f_nsim.setvalue "3"'], "nwergm simulate, nsim(3)"),
    ],
    "nwergm_estat": [("default", [], "estat gof"),
                     ("posterior", ['call main.cb_which.setvalue "posterior"', 'call posterior.f_p_saving.setvalue "d"', "call posterior.f_p_replace.seton"],
                      "estat posterior, saving(d) replace"),
                     ("gof plot", ['call main.cb_which.setvalue "gof"', "call gof.f_g_plot.seton", "call gof.f_g_panels.seton", 'call gof.f_g_name.setvalue "pg"',
                                   'call gof.f_g_saving.setvalue "g1"', 'call gof.f_g_export.setvalue "g1.png, width(300)"'],
                      "estat gof, name(pg) plot panels saving(g1) export(g1.png, width(300))"),
                     ("mcmcdiag plot", ['call main.cb_which.setvalue "mcmcdiag"', "call mcmcdiag.f_m_plot.seton", 'call mcmcdiag.f_m_name.setvalue "pm"',
                                        'call mcmcdiag.f_m_saving.setvalue "m1"', 'call mcmcdiag.f_m_export.setvalue "m1.png, width(300)"'],
                      "estat mcmcdiag, name(pm) plot saving(m1) export(m1.png, width(300))"),
                     ("posterior plot", ['call main.cb_which.setvalue "posterior"', 'call posterior.f_p_plot.setvalue "both"', 'call posterior.f_p_name.setvalue "pp"',
                                         'call posterior.f_p_pars.setvalue "edges"', 'call posterior.f_p_gsaving.setvalue "p1"',
                                         'call posterior.f_p_export.setvalue "p1.png, width(300)"'],
                      "estat posterior, plot(both) name(pp) pars(edges) gsaving(p1) export(p1.png, width(300))"),
                     ("simulate from fit", ['call main.cb_which.setvalue "simfit"'], "nwergm simulate")],
}


def build(dlgname, setup, outdir):
    s = open(os.path.join(ROOT, dlgname + ".dlg"), encoding="utf-8").read()
    i = s.index("PROGRAM command\nBEGIN\n")
    j = s.index("\nEND", i)
    body = s[i + len("PROGRAM command\nBEGIN\n"):j].rstrip("\n")
    body = re.sub(r"(?m)^(\s*)stata\s*$", r"\1stata hidden immediate", body)
    assert "stata hidden immediate" in body, dlgname + ": PROGRAM command has no stata statement"
    run = "PROGRAM zzrun\nBEGIN\n" + "".join("\t%s\n" % x for x in setup) + '\tput "nwdlgcap "\n' + body + "\nEND\n\n"
    if "SCRIPT POSTINIT\nBEGIN\n" in s:
        s = s.replace("SCRIPT POSTINIT\nBEGIN\n", "SCRIPT POSTINIT\nBEGIN\n\tprogram zzrun\n", 1)
    else:
        k = s.index("\nDIALOG ") + 1
        s = s[:k] + "SCRIPT POSTINIT\nBEGIN\n\tprogram zzrun\nEND\n\n" + s[k:]
    s = s.replace("PROGRAM command\nBEGIN", "PROGRAM command_orig\nBEGIN", 1)
    os.makedirs(outdir, exist_ok=True)
    open(os.path.join(outdir, dlgname + ".dlg"), "w", encoding="utf-8").write(s + "\n" + run)


def main(argv):
    nwcore = None
    work = None
    stata = STATA
    i = 0
    while i < len(argv):
        if argv[i] == "--nwcore":
            nwcore = argv[i + 1]; i += 1
        elif argv[i] == "--work":
            work = argv[i + 1]; i += 1
        elif argv[i] == "--stata":
            stata = argv[i + 1]; i += 1
        i += 1
    if not nwcore:
        print("usage: cmd_assembly_test.py --nwcore <core dir> [--work <dir>] [--stata <StataBE>]")
        return 2
    work = work or tempfile.mkdtemp(prefix="dlg_cmdasm_")
    os.makedirs(os.path.join(work, "plus"), exist_ok=True)
    os.makedirs(os.path.join(work, "stub"), exist_ok=True)
    open(os.path.join(work, "stub", "nwdlgcap.ado"), "w").write('program nwdlgcap\n\tdi "CAP|$CASE|`0\'"\nend\n')
    pkg_lib = os.path.join(ROOT, "lib")
    bad = 0
    todo = [d for d in CASES if os.path.exists(os.path.join(ROOT, d + ".dlg"))]
    do = ["capture program drop nwinstall", "clear all", "set linesize 250", 'sysdir set PLUS "%s/plus"' % work,
          'adopath ++ "%s"' % nwcore, 'adopath ++ "%s/lib"' % nwcore, 'adopath ++ "%s"' % ROOT, 'adopath ++ "%s"' % pkg_lib,
          'adopath ++ "%s/plugins/macos"' % pkg_lib, 'adopath ++ "%s/stub"' % work, "nwclear",
          "nwrandom 8, prob(.3) name(w1)", "nwrandom 8, prob(.3) name(w2)", "nwrandom 8, prob(.3) name(w3)",
          "set obs 8", "gen id=_n", "gen k=_n", "gen w=1", "gen sex=1", "gen race=1", "gen age=1", "gen grade=1"]
    # a minimal fit is not needed: the stub replaces the command
    ids = []
    for d in todo:
        for k, (cid, setup, exp) in enumerate(CASES[d]):
            dd = os.path.join(work, "t_%s_%d" % (d, k))
            build(d, setup, dd)
            ids.append((d, cid, exp))
            do += ['global CASE "%s|%s"' % (d, cid), 'adopath ++ "%s"' % dd, "discard", "capture noisily db %s" % d]
    open(os.path.join(work, "run.do"), "w").write("\n".join(do) + "\n")
    subprocess.run(["perl", "-e", "alarm 600; exec @ARGV", stata, "-e", "do", "run.do"], cwd=work,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    log = open(os.path.join(work, "run.log"), encoding="utf-8", errors="replace").read() if os.path.exists(os.path.join(work, "run.log")) else ""
    got = {}
    for m in re.finditer(r"^CAP\|([^|]*)\|([^|]*)\|(.*)$", log, re.M):
        got[(m.group(1), m.group(2))] = " ".join(m.group(3).split())
    for d, cid, exp in ids:
        g = got.get((d, cid))
        if g is None:
            print("FAIL %-18s %-20s no command was built (the engine aborted silently?)" % (d, cid)); bad += 1
        elif g != exp:
            print("FAIL %-18s %-20s got %r, expected %r" % (d, cid, g, exp)); bad += 1
        else:
            print("ok   %-18s %-20s %s" % (d, cid, g))
    print("%d case(s), %d failed" % (len(ids), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

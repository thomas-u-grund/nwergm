#!/usr/bin/env python3
"""Command-line smoke test of the dialogs.

For every entry of the spec the command text is built by running the PROGRAM command block of the generated
.dlg file (the interpreter in check_dialogs.py) with the control values a user would set, and the command is
then run in Stata on a small network.  Stata cannot open a dialog in batch mode, so this tests what the dialog
would send to Stata, not the look or the behaviour of the controls.

  python3 dlg/smoke_dialogs.py gen    <workdir> <nwcore>     write the do-files and cases.json into <workdir>
  python3 dlg/smoke_dialogs.py report <workdir>              read the logs <workdir>/smoke_*.log and summarise

Run each do-file with:  perl -e 'alarm 900; exec @ARGV' StataBE -e do <workdir>/smoke_und.do
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import nwergm_dialog_spec as S  # noqa: E402
import gen_dialogs as G  # noqa: E402
import check_dialogs as K  # noqa: E402

MCMC_SMALL = {"mcmcsamplesize": "300", "mcmcburnin": "500", "mcmcinterval": "20", "mcmleiterations": "3"}


def setfield(vals, e, fname, v):
    vals[G.cid_f(e, fname)] = v


def apply_use(vals, e, use):
    for k, v in (use or {}).items():
        setfield(vals, e, k, v)


def ent(i):
    return S_by_id[i]


S_by_id = {e["id"]: e for e in S.ENTRIES}


def apply_also(vals, also):
    for k, v in (also or {}).items():
        if k == "mcmc_small":
            for kk, vv in MCMC_SMALL.items():
                if not vals.get(G.cid_f(ent(kk))):
                    vals[G.cid_f(ent(kk))] = vv
            continue
        e = ent(k)
        if e["kind"] == "flag":
            vals[G.cid_cx(e)] = True
        elif e["kind"] == "ctl":
            f = e["fields"][0]
            vals[G.cid_f(e)] = True if f["w"] == "check" else v
        elif e["kind"] in ("opt", "struct"):
            vals[G.cid_cx(e)] = True
            if isinstance(v, dict):
                apply_use(vals, e, v)
            elif isinstance(v, str):
                setfield(vals, e, "main", v)
        else:
            raise ValueError(k)


def case_vals(init, e, net, variant=None):
    vals = dict(init)
    vals["cb_net"] = net
    sm = e["smoke"]
    k = e["kind"]
    also = sm.get("also") or {}
    apply_also(vals, also)
    if not any(x in also for x in ("method", "estimate", "mcmc_small", "mainmethod")):
        vals[G.cid_f(ent("method"))] = "mple"
    use = sm.get("use") or {}
    if k == "flag":
        vals[G.cid_cx(e)] = True
    elif k in ("opt", "struct", "oper"):
        vals[G.cid_cx(e)] = True
        apply_use(vals, e, use)
    elif k == "ctl":
        f = e["fields"][0]
        vals[G.cid_f(e)] = True if f["w"] == "check" else use.get("main", "")
    elif k == "cons":
        comp = {"und": "triangle", "dir": "mutual", "bip": "bstar1"}[net]
        vals[G.cid_cx(ent(comp))] = True
        if comp == "bstar1":
            vals[G.cid_f(ent(comp))] = "2"
        pref = "" if variant == "cons" else "o_"
        vals[pref + G.cid_cx(e)] = True
        if e.get("has_arg") and use.get("main"):
            vals[pref + G.cid_f(e)] = use["main"]
    return vals


def main_cases():
    dlg = K.Dlg(os.path.join(ROOT, "nwergm.dlg"))
    init = K.initial_values(dlg)
    cases = []
    for e in S.ENTRIES:
        if e["tab"] == "simctl":
            continue
        net0 = e["smoke"].get("net", "und")
        variants = [None]
        if e["kind"] == "cons":
            variants = ["cons", "obs"]
        for var in variants:
            cid = "ergm:" + e["id"] + ("" if var is None else (":" + var))
            net = net0
            vals = case_vals(init, e, net, var)
            if var == "obs":
                # observation constraints need method(mcmle) and a dyad-dependent model
                vals[G.cid_f(ent("method"))] = "mcmle"
                for kk, vv in MCMC_SMALL.items():
                    vals[G.cid_f(ent(kk))] = vv
                comp = {"und": "triangle", "dir": "ctriple", "bip": "bstar1"}[net]
                vals[G.cid_cx(ent(comp))] = True
                if comp == "bstar1":
                    vals[G.cid_f(ent(comp))] = "2"
                if e["id"] == "c_observed":
                    net = "undm"
                vals["cb_net"] = net
            if e["kind"] == "cons" and var == "cons" and e["id"] == "c_observed":
                vals["cb_net"] = net = "undm"
                vals[G.cid_f(ent("method"))] = "mcmle"
                for kk, vv in MCMC_SMALL.items():
                    vals[G.cid_f(ent(kk))] = vv
            try:
                cmd = K.build_command(dlg, vals)
                err = None
            except Exception as ex:  # noqa: BLE001
                cmd, err = "", str(ex)
            cases.append(dict(id=cid, net=net, cmd=cmd, err=err))
    return cases


def sim_cases():
    dlg = K.Dlg(os.path.join(ROOT, "nwergm_simulate.dlg"))
    init = K.initial_values(dlg)
    cases = []

    def mk(cid, net, edits, ticks=()):
        vals = dict(init)
        for k, v in edits.items():
            vals[k] = v
        for t in ticks:
            vals[t] = True
        try:
            cmd = K.build_command(dlg, vals)
            err = None
        except Exception as ex:  # noqa: BLE001
            cmd, err = "", str(ex)
        cases.append(dict(id="sim:" + cid, net=net, cmd=cmd, err=err))

    nodes = G.cid_f(ent("sim_nodes"))
    th = G.cid_f(ent("theta"))
    mk("base", "und", {nodes: "20", th: "-2", G.cid_f(ent("seed")): "5"})
    mk("nsim_generate", "und", {nodes: "20", th: "-2", G.cid_f(ent("nsim")): "2", G.cid_f(ent("generate")): "simnet"})
    mk("directed", "dir", {nodes: "20", th: "-2 0.2"}, [G.cid_cx(ent("mutual")), G.cid_f(ent("sim_directed"))])
    mk("bipartite", "bip", {nodes: "14", th: "-1", G.cid_f(ent("bipartite")): "4"})
    mk("basis", "und", {nodes: "24", th: "-2", G.cid_f(ent("basis")): "ucov"})
    mk("mcmc", "und", {nodes: "20", th: "-2", G.cid_f(ent("mcmcburnin")): "500", G.cid_f(ent("mcmcinterval")): "20", G.cid_f(ent("proposal")): "uniform"}, [G.cid_f(ent("spcache"))])
    mk("constraints_typed", "und", {nodes: "24", th: "-2", G.cid_f(ent("constraints_extra")): "edges", G.cid_f(ent("basis")): "ucov"})
    mk("triangle", "und", {nodes: "20", th: "-2 0.1"}, [G.cid_cx(ent("triangle"))])
    mk("gwesp", "und", {nodes: "20", th: "-2 0.1", G.cid_f(ent("gwesp")): "0.5"}, [G.cid_cx(ent("gwesp"))])
    mk("structural_twopath", "und", {nodes: "20", th: "-2 0.01"}, [G.cid_cx(ent("twopath"))])
    mk("constraints_observed", "und", {nodes: "24", th: "-2", G.cid_f(ent("constraints_extra")): "observed", G.cid_f(ent("basis")): "undm"})
    mk("fromfit", "und", {G.cid_f(ent("nsim")): "2", G.cid_f(ent("seed")): "5", G.cid_f(ent("mcmcburnin")): "500", G.cid_f(ent("mcmcinterval")): "20"}, ["cx_fit"])
    cases[-1]["pre"] = "quietly nwergm und, edges method(mple)"
    mk("nodecov", "und", {nodes: "24", th: "-2 0.01", G.cid_f(ent("nodecov")): "age"}, [G.cid_cx(ent("nodecov"))])
    cases[-1]["pre"] = "nwclear\nclear\nset obs 24\ngen age = 20 + mod(_n*7, 31)"
    return cases


def estat_cases():
    dlg = K.Dlg(os.path.join(ROOT, "nwergm_estat.dlg"))
    init = K.initial_values(dlg)
    cases = []

    def mk(cid, net, which, edits, ticks=()):
        vals = dict(init)
        vals["cb_which"] = which
        vals.update(edits)
        for t in ticks:
            vals[t] = True
        try:
            cmd = K.build_command(dlg, vals)
            err = None
        except Exception as ex:  # noqa: BLE001
            cmd, err = "", str(ex)
        cases.append(dict(id="estat:" + cid, net=net, cmd=cmd, err=err))

    tabs = {"gof": "gof", "mcmcdiag": "mcmcdiag", "simfit": "simfit"}
    for (cid, tabk, opt_, w, lab, ch, hint, smoke) in S.ESTAT:
        edits, ticks = {}, []
        if w == "check":
            ticks = ["f_" + cid]
        else:
            edits = {"f_" + cid: smoke}
        net = "und"
        mk(cid, net, tabs[tabk], edits, ticks)
    mk("ic", "und", "ic", {})
    mk("gof_all_off", "und", "gof", {})
    for st in S.GOF_STATS:
        net = "und"
        if st in ("idegree", "odegree"):
            net = "dir"
        if st in ("b1degree", "b2degree", "dspartners"):
            net = "bip"
        mk("gof_" + st, net, "gof", {}, ["cx_gof_" + st])
    mk("gof_dropmodel", "und", "gof", {}, ["cx_gof_degree", "cx_gof_dropmodel"])
    return cases


PRE = '''capture program drop nwinstall
set more off
set graphics off
sysdir set PLUS "{plus}"
adopath ++ "{root}"
adopath ++ "{root}/lib"
adopath ++ "{root}/lib/plugins/macos"
adopath ++ "{nwcore}"
cd "{root}"
quietly do "{nwcore}/unw_core.do"
do unw_ergm.do
nwclear
clear
set seed 20261024
'''

SETUP = {
 "und": '''
mata: n = 24; rseed(11); R = runiform(n,n) :< 0.18; R = R :* (1 :- I(n)); A = ((R + R') :> 0); st_matrix("Aund", A)
mata: C = runiform(n,n) :< 0.15; C = C :* (1 :- I(n)); C = ((C + C') :> 0); st_matrix("Mcov", C)
mata: Am = A; M = (runiform(n,n) :< 0.12); M = M :* (1 :- I(n)); M = ((M + M') :> 0); Am = A; for (i=1;i<=n;i++) for (j=1;j<=n;j++) if (M[i,j]) Am[i,j] = .; st_matrix("Amiss", Am)
nwset, mat(Aund) undirected name(und) nooutput
nwset, mat(Mcov) undirected name(ucov) nooutput
nwset, mat(Amiss) undirected name(undm) nooutput
gen sex = 1 + (_n > 12)
gen grp = 1 + mod(_n, 3)
gen age = 20 + mod(_n*7, 31)
gen pos = (mod(_n, 4) == 0)
matrix Mattr = (0.1, 0.2, 0.3 \\ 0.2, 0.1, 0.2 \\ 0.3, 0.2, 0.1)
''',
 "dir": '''
mata: n = 24; rseed(12); R = runiform(n,n) :< 0.15; R = R :* (1 :- I(n)); st_matrix("Adir", R)
mata: C = runiform(n,n) :< 0.15; C = C :* (1 :- I(n)); st_matrix("Mcov", C)
nwset, mat(Adir) directed name(dir) nooutput
nwset, mat(Mcov) directed name(dcov) nooutput
gen sex = 1 + (_n > 12)
gen grp = 1 + mod(_n, 3)
gen age = 20 + mod(_n*7, 31)
gen pos = (mod(_n, 4) == 0)
''',
 "bip": '''
mata: rseed(13); B = runiform(8,10) :< 0.3; st_matrix("Bbip", B)
nwset, mat(Bbip) bipartite name(bip) nooutput
gen sex = 1 + (_n > 9)
gen grp = 1 + mod(_n, 3)
gen age = 20 + mod(_n*7, 31)
''',
}


def write_files(workdir, nwcore):
    os.makedirs(workdir, exist_ok=True)
    plus = os.path.join(workdir, "plus_empty")
    os.makedirs(plus, exist_ok=True)
    cases = main_cases() + sim_cases() + estat_cases()
    # cases known to be able to stop Stata (plugin crash) run last in their do-file
    cases.sort(key=lambda c: 1 if (c["id"].startswith("ergm:c_b") and c["id"].endswith(":obs")) else 0)
    groups = {}
    for c in cases:
        nm = c["net"]
        key = {"undm": "und", "none": "und"}.get(nm, nm)
        if c["id"].startswith("estat:"):
            key = "estat_" + nm
        elif c["id"].startswith("sim:"):
            key = "sim_" + nm
        groups.setdefault(key, []).append(c)
    files = []
    for key, cs in groups.items():
        netbase = key.split("_")[-1]
        txt = PRE.format(plus=plus, root=ROOT, nwcore=nwcore)
        txt += SETUP[netbase] + "\n"
        if key.startswith("estat_"):
            # fit the model the estat commands work on
            fit = {"und": "nwergm und, edges triangle mcmcsamplesize(300) mcmcburnin(500) mcmcinterval(20) mcmleiterations(3)",
                   "dir": "nwergm dir, edges mutual method(mple)",
                   "bip": "nwergm bip, edges bstar1(2) mcmcsamplesize(300) mcmcburnin(500) mcmcinterval(20) mcmleiterations(3)"}[netbase]
            txt += fit + "\nmatrix Bcoef = e(b)\n"
        for c in cs:
            txt += 'di "@@@BEGIN|%s"\n' % c["id"]
            if c.get("pre"):
                txt += c["pre"] + "\n"
            if c["err"]:
                txt += 'di "@@@BUILD_ERROR|%s|%s"\ndi "@@@END|%s|-1"\n' % (c["id"], c["err"], c["id"])
                continue
            txt += "capture noisily %s\n" % c["cmd"]
            if c["id"].startswith("estat:s_") and "edgelist" in c["cmd"]:
                pass
            txt += 'di "@@@END|%s|" _rc\n' % c["id"]
        txt += "exit, clear\n"
        fn = os.path.join(workdir, "smoke_%s.do" % key)
        open(fn, "w").write(txt)
        files.append(fn)
    json.dump(cases, open(os.path.join(workdir, "cases.json"), "w"), indent=1)
    print("wrote", len(cases), "cases in", len(files), "do-files:")
    for f in files:
        print(f)


def report(workdir):
    cases = json.load(open(os.path.join(workdir, "cases.json")))
    res = {}
    for fn in sorted(os.listdir(workdir)):
        if not (fn.startswith("smoke_") and fn.endswith(".log")):
            continue
        cur = None
        buf = []
        for ln in open(os.path.join(workdir, fn), errors="replace"):
            ln = ln.rstrip("\n")
            m = re.match(r"@@@BEGIN\|(.*)$", ln)
            if m:
                cur, buf = m.group(1), []
                continue
            m = re.match(r"@@@END\|(.*)\|\s*(-?\d+)$", ln)
            if m:
                res[m.group(1)] = (int(m.group(2)), buf[-4:])
                cur = None
                continue
            if cur:
                buf.append(ln)
    ok, bad, notrun = [], [], []
    for c in cases:
        r = res.get(c["id"])
        if r is None:
            notrun.append(c)
        elif r[0] == 0:
            ok.append(c)
        else:
            bad.append((c, r))
    print("cases: %d   OK: %d   FAILED: %d   NOT RUN (no log entry): %d" % (len(cases), len(ok), len(bad), len(notrun)))
    for (c, r) in bad:
        print("FAIL rc=%s %s\n    cmd: %s\n    msg: %s" % (r[0], c["id"], c["cmd"], " / ".join(x.strip() for x in r[1] if x.strip())))
    for c in notrun:
        print("NOT RUN %s: %s" % (c["id"], c["cmd"]))


if __name__ == "__main__":
    if sys.argv[1] == "gen":
        write_files(sys.argv[2], sys.argv[3])
    else:
        report(sys.argv[2])

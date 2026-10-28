#!/usr/bin/env python3
"""Static checker for the generated nwergm dialogs, and coverage check of the spec.

Usage:  python3 dlg/check_dialogs.py        (exit status 1 if any check fails)

Checks (per .dlg file):
  1. BEGIN/END balanced, every SCRIPT/DIALOG/LIST/PROGRAM block opens with BEGIN, braces balanced in programs
  2. control ids unique (across all tabs of the file) and different from dialog/list names
  3. every id referenced in the PROGRAM blocks exists in the named tab; every contents()/values() list exists
  4. every option written by PROGRAM command is in the spec, and every spec option of the dialog is written
  5. no duplicate tab names (DIALOG names and tab titles)
  6. control positions inside the dialog area
Coverage (spec versus the sources):
  7. every option of the `syntax` lines of nwergm, nwergm simulate, estat gof / mcmcdiag and nwergm simulate (from a fit)
     is in the spec (or listed as excluded with a reason)
  8. every IMPLEMENTED/PARTIAL term of docs/ERGM_TERMS_INVENTORY.csv is selectable; the others are listed with their status

The parsing and interpreting helpers (parse_dlg, build_command) are also used by smoke_dialogs.py.
"""
import csv
import time
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import nwergm_dialog_spec as S  # noqa: E402
import gen_dialogs as G  # noqa: E402

FAILS = []
WARNS = []


def fail(msg):
    FAILS.append(msg)


def warn(msg):
    WARNS.append(msg)


# ---------------------------------------------------------------------------------------
# parsing
# ---------------------------------------------------------------------------------------

CTRL_RE = re.compile(r"^\s+([A-Z]+)\s+(\w+)\s+(-?\d+)\s+(-?\d+)\s+(\d+)\s+(\S+),\s*(.*)$")


class Dlg:
    def __init__(self, path):
        self.path = path
        self.text = open(path, encoding="utf-8").read()
        self.lines = self.text.split("\n")
        self.defines = {}
        self.dialogs = {}      # name -> dict(title, ctrls: id -> dict)
        self.order = []        # dialog names in order
        self.lists = {}        # name -> items
        self.programs = {}     # name -> list of lines
        self.blocks = []       # (kind, name, line)
        self.parse()

    def parse(self):
        i = 0
        L = self.lines
        n = len(L)
        while i < n:
            ln = L[i]
            m = re.match(r"DEFINE\s+(\w+)\s+(\S+)", ln)
            if m:
                self.defines[m.group(1)] = m.group(2)
            m = re.match(r"(SCRIPT|DIALOG|LIST|PROGRAM)\s+(\w+)(.*)$", ln)
            if m:
                kind, name, rest = m.groups()
                # BEGIN must follow
                j = i + 1
                if j >= n or L[j].strip() != "BEGIN":
                    fail("%s: %s %s is not followed by BEGIN (line %d)" % (os.path.basename(self.path), kind, name, i + 1))
                    i += 1
                    continue
                k = j + 1
                body = []
                while k < n and L[k].strip() != "END":
                    body.append((k + 1, L[k]))
                    k += 1
                if k >= n:
                    fail("%s: %s %s has no END" % (os.path.basename(self.path), kind, name))
                self.blocks.append((kind, name, i + 1))
                if kind == "DIALOG":
                    tt = re.search(r'tabtitle\("([^"]*)"\)', rest)
                    d = dict(title=tt.group(1) if tt else None, ctrls={}, line=i + 1)
                    for (lno, bl) in body:
                        cm = CTRL_RE.match(bl)
                        if cm:
                            kd, cid, x, y, w, h, opts = cm.groups()
                            if cid in d["ctrls"]:
                                fail("%s: duplicate control id %s in tab %s" % (os.path.basename(self.path), cid, name))
                            d["ctrls"][cid] = dict(kind=kd, x=int(x), y=int(y), w=int(w), h=h, opts=opts, line=lno)
                        elif bl.strip():
                            fail("%s: unparsed line in DIALOG %s: %s" % (os.path.basename(self.path), name, bl.strip()))
                    if name in self.dialogs:
                        fail("%s: duplicate DIALOG name %s" % (os.path.basename(self.path), name))
                    self.dialogs[name] = d
                    self.order.append(name)
                elif kind == "LIST":
                    self.lists[name] = [b.strip() for (_, b) in body if b.strip() and not b.strip().startswith("//")]
                else:
                    self.programs[name] = body
                i = k + 1
                continue
            i += 1

    def all_ids(self):
        out = {}
        for dn, d in self.dialogs.items():
            for cid, c in d["ctrls"].items():
                out.setdefault(cid, []).append(dn)
        return out


# ---------------------------------------------------------------------------------------
# interpreter of the PROGRAM command block
# ---------------------------------------------------------------------------------------

TOK_RE = re.compile(r'"[^"]*"|[A-Za-z_]\w*\.[A-Za-z_]\w*(?:\.\w+\([^)]*\))?|\S+')


def _logical_lines(body):
    out = []
    cur = ""
    for (_, ln) in body:
        s = ln.strip()
        if not s or s.startswith("//"):
            continue
        if s.endswith("///"):
            cur += " " + s[:-3].strip()
            continue
        out.append((cur + " " + s).strip())
        cur = ""
    return out


class CondParser:
    def __init__(self, text, val):
        self.t = re.findall(r'"[^"]*"|[A-Za-z_]\w*\.[A-Za-z_]\w*|\.\w+|[()!&|,]|\w+', text)
        self.i = 0
        self.val = val

    def peek(self):
        return self.t[self.i] if self.i < len(self.t) else None

    def eat(self):
        x = self.t[self.i]
        self.i += 1
        return x

    def expr(self):
        v = self.term()
        while self.peek() in ("|", "&"):
            op = self.eat()
            r = self.term()
            v = (v or r) if op == "|" else (v and r)
        return v

    def term(self):
        p = self.peek()
        if p == "!":
            self.eat()
            return not self.term()
        if p == "(":
            self.eat()
            v = self.expr()
            assert self.eat() == ")"
            return v
        ref = self.eat()
        cid = ref.split(".")[1]
        v = self.val(cid)
        # method calls: .isneq("x") .iseq("x") .startswith("x")
        if self.peek() and self.peek().startswith(".") and len(self.peek()) > 1:
            fn = self.eat()[1:]
            assert self.eat() == "("
            arg = self.eat().strip('"')
            assert self.eat() == ")"
            s = "" if v in (None, False) else str(v)
            if fn == "iseq":
                return s == arg
            if fn == "isneq":
                return s != arg
            if fn == "startswith":
                return s.startswith(arg)
            raise ValueError("unsupported function " + fn)
        return bool(v) if not isinstance(v, str) else v != ""


def build_command(dlg, values):
    """Run the PROGRAM command block of a parsed dialog (and the sub-programs it calls with `put /program`)
    with the given control values; returns the command text.
    values: control id -> value (True/False for tick boxes, string for others)."""
    out = []
    nopt = [0]

    def val(cid):
        return values.get(cid)

    def run(lines, depth=0):
        skipdepth = 0
        for ln in lines:
            if ln == "}":
                if skipdepth > 0:
                    skipdepth -= 1
                continue
            m = re.match(r"if (.*) \{$", ln)
            if m:
                if skipdepth > 0:
                    skipdepth += 1
                elif not CondParser(m.group(1), val).expr():
                    skipdepth = 1
                continue
            if skipdepth > 0:
                continue
            if ln == "beginoptions":
                nopt[0] = len(out)
                out.append(" ,")
                continue
            if ln == "endoptions":
                if len(out) == nopt[0] + 1:
                    out.pop()
                continue
            if ln == "stata":
                return True
            m = re.match(r"require (\S+)$", ln)
            if m:
                v = val(m.group(1).split(".")[1])
                if v in (None, "", False):
                    raise ValueError("required field empty: " + m.group(1))
                continue
            m = re.match(r"put /program (\w+)$", ln)
            if m:
                run(_logical_lines(dlg.programs[m.group(1)]), depth + 1)
                continue
            m = re.match(r"put (.*)$", ln)
            if m:
                for t in re.findall(r'"[^"]*"|\S+', m.group(1)):
                    if t.startswith('"'):
                        out.append(t[1:-1])
                    else:
                        v = val(t.split(".")[1])
                        out.append("" if v in (None, False) else ("1" if v is True else str(v)))
                continue
            raise ValueError("unsupported statement: " + ln)
        return False

    run(_logical_lines(dlg.programs["command"]))
    return re.sub(r"\s+", " ", "".join(out)).replace(" ,", ",", 1).strip()


def initial_values(dlg):
    """Control values when the dialog opens: tick boxes default(0/1), edits default(...), others empty."""
    vals = {}
    for dn, d in dlg.dialogs.items():
        for cid, c in d["ctrls"].items():
            m = re.search(r'default\(("?)([^")]*)\1\)', c["opts"])
            if c["kind"] == "CHECKBOX":
                vals[cid] = bool(m and m.group(2) == "1")
            elif c["kind"] in ("EDIT", "VARLIST", "VARNAME", "COMBOBOX"):
                vals[cid] = m.group(2) if m else ""
    return vals


# ---------------------------------------------------------------------------------------
# checks
# ---------------------------------------------------------------------------------------

def check_file(fname, which):
    path = os.path.join(ROOT, fname)
    base = fname
    d = Dlg(path)
    # 1 balance
    nb = sum(1 for ln in d.lines if ln.strip() == "BEGIN")
    ne = sum(1 for ln in d.lines if ln.strip() == "END")
    if nb != ne:
        fail("%s: BEGIN (%d) / END (%d) not balanced" % (base, nb, ne))
    nblocks = len(d.blocks)
    if nb != nblocks:
        fail("%s: %d BEGIN lines but %d recognised blocks" % (base, nb, nblocks))
    for name, body in d.programs.items():
        txt = "\n".join(b for (_, b) in body)
        if txt.count("{") != txt.count("}"):
            fail("%s: braces unbalanced in PROGRAM %s" % (base, name))
    # 2 unique ids
    ids = d.all_ids()
    for cid, where in ids.items():
        if len(where) > 1:
            fail("%s: control id %s used in tabs %s" % (base, cid, where))
        if cid in d.dialogs or cid in d.lists:
            fail("%s: control id %s clashes with a dialog or list name" % (base, cid))
        if len(cid) > 32:
            fail("%s: control id %s longer than 32 characters" % (base, cid))
    # 3 references
    refs = set()
    for name, body in d.programs.items():
        for (lno, bl) in body:
            for m in re.finditer(r"\b([a-z][a-z0-9_]*)\.((?:cx|f|cb|ed|tx)_\w+)", bl):
                refs.add((m.group(1), m.group(2)))
    for (dn, cid) in refs:
        if dn not in d.dialogs:
            fail("%s: reference to unknown dialog %s.%s" % (base, dn, cid))
        elif cid not in d.dialogs[dn]["ctrls"]:
            fail("%s: reference to unknown control %s.%s" % (base, dn, cid))
    for dn, dd in d.dialogs.items():
        for cid, c in dd["ctrls"].items():
            for m in re.finditer(r"(?:contents|values)\((\w+)\)", c["opts"]):
                if m.group(1) not in d.lists:
                    fail("%s: control %s refers to missing list %s" % (base, cid, m.group(1)))
    # 5 tab names
    titles = [d.dialogs[n]["title"] for n in d.order]
    if len(set(titles)) != len(titles) or None in titles:
        fail("%s: duplicate or missing tab titles" % base)
    # tab rules: at most 9 tabs, titles of at most 10 characters, at least 90 px per tab
    wd0 = int(d.defines.get("_dlgwd", "0"))
    if len(d.order) > 9:
        fail("%s: %d tabs (maximum 9)" % (base, len(d.order)))
    if wd0 < 90 * len(d.order):
        fail("%s: %d tabs need %d px but the dialog is %d px wide" % (base, len(d.order), 90 * len(d.order), wd0))
    for t_ in titles:
        if t_ and len(t_) > 10:
            fail("%s: tab title %r is longer than 10 characters" % (base, t_))
    # show/hide scripts refer to existing controls
    for kind, nm, ln_ in d.blocks:
        if kind == "SCRIPT" and nm != "PREINIT":
            pass
    for m in re.finditer(r"^\s+(\w+)\.(\w+)\.(?:show|hide)\s*$", d.text, re.M):
        if m.group(1) not in d.dialogs or m.group(2) not in d.dialogs[m.group(1)]["ctrls"]:
            fail("%s: script refers to unknown control %s.%s" % (base, m.group(1), m.group(2)))
    has_sel = any(c.startswith("cb_sec_") for dd in d.dialogs.values() for c in dd["ctrls"])
    # 6 positions
    wd = int(d.defines.get("_dlgwd", "0"))
    ht = int(d.defines.get("_dlght", "0"))
    maxbottom = ht - 70
    for dn, dd in d.dialogs.items():
        for cid, c in dd["ctrls"].items():
            hh = 21 if c["h"] == "." else int(c["h"])
            if c["x"] < 0 or c["y"] < 0 or c["x"] + c["w"] > wd - 10 or c["y"] + hh > maxbottom:
                fail("%s: control %s.%s outside the dialog area (x=%d y=%d w=%d h=%s; area %dx%d)" % (base, dn, cid, c["x"], c["y"], c["w"], c["h"], wd - 10, maxbottom))
            lab = re.search(r'label\("([^"]*)"\)', c["opts"])
            if lab and c["kind"] in ("TEXT", "CHECKBOX"):
                need = len(lab.group(1)) * G.CHARW + (20 if c["kind"] == "CHECKBOX" else 0)
                if need > c["w"] + 25:
                    warn("%s: label of %s may be clipped (%d px needed, %d available): %s" % (base, cid, need, c["w"], lab.group(1)))
    # overlapping controls on the same tab (tabs with a section selector hold overlapping sections by design;
    # the generator checks those section by section)
    for dn, dd in d.dialogs.items():
        if any(c.startswith("cb_sec_") for c in dd["ctrls"]):
            continue
        cs = list(dd["ctrls"].items())
        for i in range(len(cs)):
            for j in range(i + 1, len(cs)):
                a, b = cs[i][1], cs[j][1]
                ha = 21 if a["h"] == "." else int(a["h"])
                hb = 21 if b["h"] == "." else int(b["h"])
                if a["x"] < b["x"] + b["w"] and b["x"] < a["x"] + a["w"] and a["y"] < b["y"] + hb - 4 and b["y"] < a["y"] + ha - 4:
                    # TEXT labels sit 2px lower than edits in the same row; only report real overlaps of different kinds of widgets
                    fail("%s: controls %s and %s overlap in tab %s" % (base, cs[i][0], cs[j][0], dn))
    # 4 options in command program
    prog = "\n".join(b for nm, body in d.programs.items() if nm != "initialize" and not nm.startswith("open_") for (_, b) in body)
    lits = re.findall(r'put\s+(.*)', prog)
    words = set()
    for l in lits:
        for s in re.findall(r'"([^"]*)"', l):
            m = re.match(r"\s*([A-Za-z][A-Za-z0-9_.]*)", s)
            if m:
                words.add(m.group(1))
            if " " in s.strip() and not s.startswith(" "):
                for w2 in re.findall(r"[A-Za-z][A-Za-z0-9_]*", s):
                    words.add(w2)
    return d, words


def spec_words(which):
    """All words the command program of a dialog is expected to write."""
    words = set()
    keys = set()
    ents = G.entries_for(which)
    for e in ents:
        if e["id"] == "sim_nodes":
            continue
        k = e["kind"]
        if k in ("flag", "opt", "ctl"):
            for (oname, _) in e["options"]:
                words.add(oname)
        elif k == "struct":
            words.add("structural")
            words.add(e["name"])
        elif k == "oper":
            words.add("operators")
            words.add(e["name"])
        elif k == "cons":
            words.add("constraints")
            words.add("obsconstraints")
            words.add(e["name"])
        for f in e["fields"]:
            if f.get("key"):
                keys.add(f["key"])
    return words, keys


def check_options(fname, which, words):
    exp, keys = spec_words(which)
    extra_ok = {"nwergm", "simulate"} | keys
    # words written but not in the spec
    for w in sorted(words - exp - extra_ok):
        fail("%s: command writes %r which is not in the spec" % (fname, w))
    for w in sorted(exp - words):
        fail("%s: spec option %r is never written by the command program" % (fname, w))


def check_estat(fname):
    d, words = check_file(fname, "estat")
    exp = {"estat", "gof", "mcmcdiag", "ic", "nwergm", "simulate", "-model"}
    for (cid, tabk, opt_, w, lab, ch, hint, sm) in S.ESTAT:
        exp.add(opt_)
    exp |= set(S.GOF_STATS)
    for w in sorted(words - exp):
        fail("%s: command writes %r which is not in the spec" % (fname, w))
    for w in sorted(exp - words - {"-model"}):
        fail("%s: spec word %r is never written by the command program" % (fname, w))
    if "model" in words and "-model" not in "".join(d.text.split()):
        pass
    return d


# ---------------------------------------------------------------------------------------
# coverage
# ---------------------------------------------------------------------------------------

def coverage():
    rep = {}
    # --- options of nwergm
    syn = set(G.syntax_options("nwergm.ado", "nwergm"))
    spec_main = set()
    for e in S.ENTRIES:
        if e["tab"] == "simctl":
            continue
        for (oname, _) in e["options"]:
            spec_main.add(oname)
    excl = set(S.EXCLUDED_OPTIONS)
    miss = sorted(syn - spec_main - excl)
    for m in miss:
        fail("coverage: nwergm option %s is not in the spec" % m)
    for m in sorted(excl - syn):
        fail("coverage: excluded option %s is not in the syntax line (stale exclusion)" % m)
    rep["syntax_options"] = len(syn)
    rep["options_in_dialog"] = len(syn - excl)
    rep["excluded_options"] = {k: v for k, v in S.EXCLUDED_OPTIONS.items()}
    # --- simulate
    simsyn = set(G.syntax_options("nwergm.ado", "nwergm_simulate"))
    sim_entries = G.entries_for("sim")
    sim_spec = set()
    for e in sim_entries:
        if e["id"] == "sim_nodes":
            continue
        for (oname, _) in e["options"]:
            sim_spec.add(oname)
    for m in sorted(simsyn - sim_spec):
        fail("coverage: nwergm simulate option %s is not in the simulate dialog" % m)
    rep["sim_options"] = len(simsyn)
    # --- estat
    est = {"mcmcdiag": set(G.syntax_options("nwergm_estat.ado", "nwergm_estat_mcmcdiag")),
           "gof": set(G.syntax_options("_nwergm_gof.ado", "_nwergm_gof")),
           "simfit": set(G.syntax_options("_nwergm_simfit.ado", "_nwergm_simfit"))}
    for tabk, o in est.items():
        have = {r[2] for r in S.ESTAT if r[1] == tabk}
        if tabk == "gof":
            have |= {"gof"}
        for m in sorted(o - have):
            fail("coverage: estat %s option %s is not in nwergm_estat.dlg" % (tabk, m))
        for m in sorted(have - o):
            fail("coverage: spec has estat %s option %s that the ado file does not have" % (tabk, m))
    rep["estat_options"] = {k: len(v) for k, v in est.items()}
    # --- terms
    inv = list(csv.DictReader(open(os.path.join(ROOT, "docs", "ERGM_TERMS_INVENTORY.csv"), encoding="utf-8")))
    impl = [r["term"] for r in inv if r["nwergm_status"] in ("IMPLEMENTED", "PARTIAL")]
    covered = set()
    for e in S.ENTRIES:
        covered.update(e["ergm"])
    for t in impl:
        if t not in covered:
            fail("coverage: implemented ergm term %s is not selectable in the dialog" % t)
    rep["terms_implemented"] = len(impl)
    rep["terms_covered"] = len([t for t in impl if t in covered])
    notsel = {}
    for r in inv:
        if r["nwergm_status"] not in ("IMPLEMENTED", "PARTIAL"):
            notsel.setdefault(r["nwergm_status"], []).append(r["term"])
    rep["excluded_terms"] = notsel
    allterms = {r["term"] for r in inv}
    for t in sorted(covered - allterms):
        warn("spec lists ergm term %s which is not in the inventory" % t)
    # --- option names written in the inventory syntax column
    for r in inv:
        if r["nwergm_status"] in ("IMPLEMENTED", "PARTIAL"):
            for m in re.finditer(r"\b([a-z][a-z0-9]*)\(", r["nwergm_syntax"]):
                nm = m.group(1)
                if nm in syn and nm not in spec_main:
                    fail("coverage: inventory syntax of %s uses option %s which is not in the spec" % (r["term"], nm))
    # --- entry counts
    rep["entries"] = len(S.ENTRIES)
    rep["entries_by_kind"] = {}
    for e in S.ENTRIES:
        rep["entries_by_kind"][e["kind"]] = rep["entries_by_kind"].get(e["kind"], 0) + 1
    return rep


def oracle(work, nwcore, stata):
    """Mandatory check: `db <name>` in Stata -e must return rc 0 for every dialog (rc 1001 = Stata rejects the
    dialog file; a valid dialog without SYNCHRONOUS_ONLY would block, so a missing return code also fails)."""
    import subprocess
    os.makedirs(work, exist_ok=True)
    for name in ("nwergm", "nwergm_simulate", "nwergm_estat"):
        do = os.path.join(work, "oracle_%s.do" % name)
        with open(do, "w") as f:
            f.write('adopath ++ "%s"\nadopath ++ "%s"\ndiscard\ncapture db %s\ndi "ORACLE %s rc=" _rc\nexit, clear\n' % (ROOT, nwcore, name, name))
        logf = os.path.join(work, "oracle_%s.log" % name)
        rc = None
        for attempt in range(3):      # Stata -e sometimes exits at once without a log when other Stata runs start together
            if os.path.exists(logf):
                os.remove(logf)
            try:
                subprocess.run(["perl", "-e", "alarm 90; exec @ARGV", stata, "-e", "do", os.path.basename(do)], cwd=work, env=dict(os.environ, PWD=os.path.abspath(work)),
                               stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)
            except Exception as ex:  # noqa: BLE001
                fail("oracle: could not run Stata for %s: %s" % (name, ex))
                break
            if os.path.exists(logf):
                m = re.search(r"ORACLE %s rc=(\d+)" % name, open(logf, errors="replace").read())
                rc = int(m.group(1)) if m else None
                if rc is not None:
                    break
            time.sleep(3)
        print("oracle: db %-16s rc=%s" % (name, rc))
        if rc != 0:
            fail("oracle: `db %s` returned %s (must be 0)" % (name, rc))


def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", help="scratch directory for the Stata oracle run (required)")
    ap.add_argument("--nwcore", default=os.environ.get("NWCORE"), help="directory of the core nwcommands package (or env NWCORE)")
    ap.add_argument("--stata", default="/Applications/Stata/StataBE.app/Contents/MacOS/StataBE")
    args = ap.parse_args()
    G.WARN.clear()
    b, ents = G.build_main("ergm")
    d1, w1 = check_file("nwergm.dlg", "ergm")
    check_options("nwergm.dlg", "ergm", w1)
    d2, w2 = check_file("nwergm_simulate.dlg", "sim")
    check_options("nwergm_simulate.dlg", "sim", w2)
    check_estat("nwergm_estat.dlg")
    rep = coverage()
    if not args.work or not args.nwcore:
        fail("oracle: the Stata check `db <dialog>` is mandatory: pass --work <scratch dir> and --nwcore <core dir> (or set NWCORE)")
    else:
        oracle(args.work, args.nwcore, args.stata)
    for k, v in rep.items():
        print("coverage %-22s %s" % (k, v))
    for w in WARNS:
        print("WARNING:", w)
    if FAILS:
        for f in FAILS:
            print("FAIL:", f)
        print("%d checks FAILED" % len(FAILS))
        return 1
    print("all static and coverage checks passed (%d warnings)" % len(WARNS))
    return 0


if __name__ == "__main__":
    sys.exit(main())

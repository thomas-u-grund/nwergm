#!/usr/bin/env python3
"""Generate nwergm.dlg, nwergm_simulate.dlg and nwergm_estat.dlg from nwergm_dialog_spec.py.

Usage:  python3 dlg/gen_dialogs.py            (writes the three .dlg files into the package root)
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import nwergm_dialog_spec as S  # noqa: E402

W = 1000            # dialog width
H = 540            # dialog height
RH = 21            # row height
MAXROWS = 19       # rows per tab page
X0 = 10
Y0 = 10
CHARW = 6.3        # pixels per character (estimate for the dialog font)

WARN = []


def tw(s):
    return int(len(s) * CHARW) + 6


# ---------------------------------------------------------------------------------------
# syntax lines of the ado files
# ---------------------------------------------------------------------------------------

def _syntax_block(path, program, which=0):
    """Return the text of the n-th `syntax` statement (continuation lines joined) of an ado program."""
    lines = open(os.path.join(ROOT, path), encoding="utf-8", errors="replace").read().split("\n")
    start = None
    for i, ln in enumerate(lines):
        if re.match(r"\s*program\s+(define\s+)?" + re.escape(program) + r"\b", ln):
            start = i
            break
    if start is None:
        raise SystemExit("program %s not found in %s" % (program, path))
    for i in range(start, len(lines)):
        if re.match(r"\s*syntax\b", lines[i]):
            txt = lines[i]
            j = i
            while txt.rstrip().endswith("///"):
                j += 1
                txt = txt.rstrip()[:-3] + " " + lines[j]
            return txt
    raise SystemExit("no syntax line for %s" % program)


def syntax_options(path, program):
    """Names (lower case, unabbreviated) of the options of the syntax statement of a program."""
    txt = _syntax_block(path, program)
    # drop the positional part before the first comma that opens the option list
    txt = re.sub(r"^\s*syntax\s*", "", txt)
    txt = re.sub(r"//.*$", "", txt)
    # strip nested parenthesised arguments
    prev = None
    while prev != txt:
        prev = txt
        txt = re.sub(r"\([^()]*\)", "", txt)
    txt = txt.replace("[", " ").replace("]", " ")
    head, _, rest = txt.partition(",")
    toks = re.findall(r"[A-Za-z][A-Za-z0-9_]*", rest)
    # the first positional keyword (anything) is in head, edges (required) is in rest for simulate
    return [t.lower() for t in toks]


def sim_option_set():
    return set(syntax_options("nwergm.ado", "nwergm_simulate"))


# ---------------------------------------------------------------------------------------
# control model
# ---------------------------------------------------------------------------------------

class C:
    def __init__(self, kind, cid, x, y, w, h=None, **kw):
        self.kind, self.id, self.x, self.y, self.w, self.h = kind, cid, x, y, w, h
        self.kw = kw

    def dlg(self):
        h = "." if self.h is None else str(self.h)
        k = self.kw
        base = "  %-9s %s %d %d %d %s" % (self.kind, self.id, self.x, self.y, self.w, h)
        parts = []
        if self.kind in ("TEXT", "CHECKBOX", "GROUPBOX"):
            parts.append('label("%s")' % k["label"].replace('"', "'"))
        if self.kind in ("VARLIST", "VARNAME"):
            parts.append('label("%s")' % k.get("label", "vars"))
        if self.kind == "CHECKBOX":
            parts.append("default(%d)" % (1 if k.get("default") else 0))
        if self.kind in ("EDIT", "COMBOBOX", "VARLIST", "VARNAME"):
            if k.get("default") not in (None, ""):
                parts.append('default("%s")' % k["default"])
        if self.kind == "COMBOBOX":
            if k.get("choices"):
                if k.get("onsel"):
                    parts.append("dropdownlist contents(%s) onselchangelist(%s)" % (k["lst"], k["onsel"]))
                else:
                    parts.append("dropdownlist contents(%s) values(%s)" % (k["lst"], k["lst"] + "_v"))
            else:
                parts.append("dropdown contents(netlist)")
        if self.kind != "TEXT" and self.kind != "GROUPBOX":
            parts.append("nomem")
        return base + ", " + " ".join(parts)


def cid_cx(e):
    return "cx_" + e["id"]


def cid_f(e, fname="main"):
    return "f_" + e["id"] + ("" if fname == "main" else "_" + fname)


def field_width(f):
    if f.get("width"):
        return f["width"]
    return dict(varlist=200, edit=170, net=170, combo=100, varname=140, check=0).get(f["w"], 150)


class Builder:
    """Collects the controls of one dialog (tabs/pages), the lists and the command program."""

    def __init__(self, which):
        self.which = which          # 'ergm' | 'sim'
        self.pages = []             # dicts: name, title, ctls
        self.lists = {}             # name -> [labels], name_v -> [values]
        self.dlgof = {}             # control id -> dialog name
        self.scripts = []           # (name, [lines]) show/hide scripts of the section selectors
        self.hidden_at_start = []   # script names to call in POSTINIT
        self.ent = {}               # control id -> (entry, fieldname)

    # -- lists ---------------------------------------------------------------------------
    def combolist(self, cid, choices):
        name = "l_" + cid
        labels = ['"(default)"' if c == "" else c for c in choices]
        self.lists[name] = labels
        self.lists[name + "_v"] = ['""' if c == "" else c for c in choices]
        return name

    # -- widgets -------------------------------------------------------------------------
    def widget(self, e, f, cid, x, y, w=None):
        w = w or field_width(f)
        kind = f["w"]
        if kind == "combo":
            lst = self.combolist(cid, f["choices"])
            return C("COMBOBOX", cid, x, y, w, choices=f["choices"], lst=lst, default=None)
        if kind == "net":
            return C("COMBOBOX", cid, x, y, w)
        if kind == "varlist":
            return C("VARLIST", cid, x, y, w, label=f.get("text") or "vars")
        if kind == "varname":
            return C("VARNAME", cid, x, y, w, label="var")
        return C("EDIT", cid, x, y, w, default=f.get("default"))

    def hint(self, ctls, x, y, text):
        if not text:
            return
        avail = W - 15 - x
        need = int(len(text) * CHARW)
        if need > avail:
            WARN.append("hint too long (%d > %d px): %s" % (need, avail, text))
        self.n = getattr(self, "n", 0) + 1
        ctls.append(C("TEXT", "tx_h%d" % self.n, x, y + 2, max(avail, 20), label=text))

    # -- rows ----------------------------------------------------------------------------
    def row_entry(self, e, y, cbw):
        ctls = []
        x = X0
        k = e["kind"]
        if k == "flag":
            ctls.append(C("CHECKBOX", cid_cx(e), x, y, cbw, label=e["label"], default=e.get("default")))
            self.hint(ctls, x + cbw + 8, y, e["hint"])
            return ctls
        if k == "ctl":
            f = e["fields"][0]
            if f["w"] == "check":
                ctls.append(C("CHECKBOX", cid_f(e), x, y, 200, label=e["label"], default=False))
                self.hint(ctls, 220, y, e["hint"])
            else:
                ctls.append(C("TEXT", "tx_" + e["id"], x, y + 2, 200, label=e["label"]))
                ctls.append(self.widget(e, f, cid_f(e), 215, y))
                self.hint(ctls, 215 + field_width(f) + 10, y, e["hint"])
            return ctls
        # tick box + fields
        ctls.append(C("CHECKBOX", cid_cx(e), x, y, cbw, label=e["label"], default=False))
        x += cbw + 8
        for f in e["fields"]:
            nm = f["name"]
            cid = cid_f(e, nm)
            if k == "opt":
                if nm == "sub":
                    ctls.append(C("TEXT", "tx_%s_c" % e["id"], x, y + 2, 8, label=","))
                    x += 12
                    ctls.append(self.widget(e, f, cid, x, y))
                    x += field_width(f) + 8
                    continue
                if nm != "main":
                    lab = (f.get("text") or nm) + ":"
                    ctls.append(C("TEXT", "tx_%s_%s" % (e["id"], nm), x, y + 2, tw(lab), label=lab))
                    x += tw(lab)
                    ctls.append(self.widget(e, f, cid, x, y))
                    x += field_width(f) + 8
                    continue
                ctls.append(self.widget(e, f, cid, x, y))
                x += field_width(f) + 8
                continue
            # struct / oper fields
            if f["w"] == "check":
                lab = f["key"] or nm
                ww = tw(lab) + 18
                ctls.append(C("CHECKBOX", cid, x, y, ww, label=lab, default=False))
                x += ww + 4
                continue
            lab = ((f["key"] + "=") if k == "struct" and f.get("key") else ((f.get("text") or f.get("key") or nm) + ":"))
            ctls.append(C("TEXT", "tx_%s_%s" % (e["id"], nm), x, y + 2, tw(lab), label=lab))
            x += tw(lab)
            ctls.append(self.widget(e, f, cid, x, y))
            x += field_width(f) + 8
        self.hint(ctls, x, y, e["hint"])
        return ctls

    def row_cons(self, e, y):
        ctls = []
        for (pref, x0) in (("", 10), ("o_", 290)):
            cb = C("CHECKBOX", pref + cid_cx(e), x0, y, 120, label=e["name"], default=False)
            ctls.append(cb)
            if e.get("has_arg"):
                ctls.append(C("EDIT", pref + cid_f(e), x0 + 125, y, 130))
        self.hint(ctls, 570, y, e["hint"])
        return ctls

    # -- pages ---------------------------------------------------------------------------
    def build_tab(self, tab, rows, first):
        """rows: list of ('section', text) | ('note', text) | ('entry', e) | ('cons', e) | ('consheader',)"""
        pages = []
        cur = []
        for r in rows:
            cur.append(r)
            if len(cur) >= MAXROWS:
                # do not end a page with a section header
                if cur[-1][0] == "section":
                    hold = cur.pop()
                    pages.append(cur)
                    cur = [hold]
                else:
                    pages.append(cur)
                    cur = []
        if cur:
            pages.append(cur)
        entries = [r[1] for r in rows if r[0] == "entry"]
        cbw = 190
        for e in entries:
            if e["kind"] in ("opt", "struct", "oper", "flag"):
                cbw = max(cbw, tw(e["label"]) + 22)
        cbw = min(cbw, 300)
        for pi, pg in enumerate(pages):
            name = "main" if (first and pi == 0) else (tab["key"] + ("" if pi == 0 else str(pi + 1)))
            title = tab["title"] + ("" if len(pages) == 1 else " (%d/%d)" % (pi + 1, len(pages)))
            ctls = []
            y = Y0
            for r in pg:
                if r[0] == "section":
                    ctls.append(C("TEXT", "tx_s%d_%s" % (y, name), X0, y + 2, W - 40, label="== " + r[1] + " =="))
                elif r[0] == "note":
                    ctls.append(C("TEXT", "tx_n%d_%s" % (y, name), X0, y + 2, W - 40, label=r[1]))
                elif r[0] == "consheader":
                    ctls.append(C("TEXT", "tx_ch1_" + name, 10, y + 2, 270, label="constraints()  (tick the constraint terms)"))
                    ctls.append(C("TEXT", "tx_ch2_" + name, 290, y + 2, 270, label="obsconstraints()  (observation process)"))
                elif r[0] == "cons":
                    ctls += self.row_cons(r[1], y)
                elif r[0] == "raw":
                    ctls += r[1](y)
                else:
                    ctls += self.row_entry(r[1], y, cbw)
                y += RH
            self.pages.append(dict(name=name, title=title, ctls=ctls, key=tab["key"]))
        return pages

    def register(self):
        for pg in self.pages:
            for c in pg["ctls"]:
                self.dlgof[c.id] = pg["name"]


# ---------------------------------------------------------------------------------------
# the estimation / simulation dialogs
# ---------------------------------------------------------------------------------------

NOTES = {
    ("space", "ergm"): [
        "Missing ties: dyads that are missing in the network are detected automatically. They are left out of the",
        "(pseudo)likelihood and, in a dyad-dependent model, handled by the missing-data MCMLE as in R. Nothing to set here.",
        "Missing values in node covariates are refused (as in R): drop or impute them first.",
    ],
    ("basic", "sim"): [
        "nwergm simulate draws networks from a model with fixed coefficients (theta). The node variables used by a term must",
        "already be in the data (one row per node). The number of nodes, theta() and the other settings are on the last tab.",
    ],
    ("deg", "ergm"): [],
}


def entries_for(which):
    simset = sim_option_set() if which == "sim" else None
    out = []
    for e in S.ENTRIES:
        if e["id"] == "sim_nodes" or e["tab"] == "simctl":
            if which == "sim":
                out.append(e)
            continue
        if which == "sim":
            names = [o[0] for o in e["options"]]
            if e["kind"] == "cons":
                continue
            if not any(n in simset for n in names):
                continue
        out.append(e)
    return out


def tabs_for(which):
    return [t for t in S.TABS if which in t["dialogs"]]


def sim_filter_fields(e, simset):
    """Fields of an entry whose option (extra) is not in the simulate syntax are dropped (e.g. nothing today)."""
    return e


TAB_PLAN = {
    # at most 9 tabs, titles of at most 10 characters; a tab made of several pages gets a "Section" selector
    "ergm": [("Basic", ["basic"]), ("Degree", ["deg"]), ("Triads", ["tri"]), ("Covariate", ["cov"]), ("Two-mode", ["two"]),
             ("Curved", ["curved"]), ("Operators", ["oper"]), ("Constraint", ["cons", "space"]), ("Estimate", ["est", "mcmc", "out"])],
    "sim": [("Basic", ["basic"]), ("Degree", ["deg"]), ("Triads", ["tri"]), ("Covariate", ["cov"]), ("Two-mode", ["two"]),
            ("Curved", ["curved"]), ("Sample", ["space"]), ("MCMC", ["mcmc"]), ("Simulate", ["simctl"])],
}
SCRIPT_CHUNK = 40     # statements per SCRIPT (Stata rejects very long programs)


def check_no_overlap(ctls, where):
    for i in range(len(ctls)):
        for j in range(i + 1, len(ctls)):
            a, c = ctls[i], ctls[j]
            ha = 21 if a.h is None else a.h
            hc = 21 if c.h is None else c.h
            if a.x < c.x + c.w and c.x < a.x + a.w and a.y < c.y + hc - 4 and c.y < a.y + ha - 4:
                raise SystemExit("overlap in %s: %s and %s" % (where, a.id, c.id))


def assemble(b, plan):
    """Merge pages into tabs; pages of one tab become sections chosen with a drop-down that shows/hides their controls."""
    newpages = []
    nsel = 0
    for ti, (title, keys) in enumerate(plan):
        groups = [p for k in keys for p in b.pages if p["key"] == k]
        if not groups:
            continue
        name = "main" if not newpages else keys[0]
        if len(groups) == 1:
            ctls = groups[0]["ctls"]
            check_no_overlap(ctls, name)
        else:
            nsel += 1
            labels = [g["title"] for g in groups]
            lst = "l_sec_" + name
            b.lists[lst] = ["\"%s\"" % x for x in labels]
            b.lists[lst + "_a"] = ["script sel_%s_%d" % (name, gi) for gi in range(len(groups))]
            shift = RH + 12
            ctls = [C("TEXT", "tx_sec_" + name, X0, 12, 70, label="Section:"),
                    C("COMBOBOX", "cb_sec_" + name, 85, 10, 380, choices=labels, lst=lst, onsel=lst + "_a")]
            for gi, g in enumerate(groups):
                for c in g["ctls"]:
                    c.y += shift
                check_no_overlap(g["ctls"], name + " section " + str(gi))
                ctls += g["ctls"]
                ids = ["%s.%s" % (name, c.id) for c in g["ctls"]]
                for verb in ("show", "hide"):
                    chunks = [ids[i:i + SCRIPT_CHUNK] for i in range(0, len(ids), SCRIPT_CHUNK)]
                    for k, ch in enumerate(chunks):
                        b.scripts.append(("%s_%s_%d_%d" % (verb[:2], name, gi, k), ["%s.%s" % (x, verb) for x in ch]))
                    b.scripts.append(("%s_%s_%d" % (verb[:2], name, gi),
                                      ["script %s_%s_%d_%d" % (verb[:2], name, gi, k) for k in range(len(chunks))]))
            for gi in range(len(groups)):
                lines = ["script hi_%s_%d" % (name, gj) for gj in range(len(groups)) if gj != gi] + ["script sh_%s_%d" % (name, gi)]
                b.scripts.append(("sel_%s_%d" % (name, gi), lines))
            for gi in range(1, len(groups)):
                b.hidden_at_start.append("hi_%s_%d" % (name, gi))
        newpages.append(dict(name=name, title=title, ctls=ctls, key=keys[0]))
    b.pages = newpages


def build_main(which):
    b = Builder(which)
    ents = entries_for(which)
    first = True
    for t in tabs_for(which):
        es = [e for e in ents if e["tab"] == t["key"]]
        rows = []
        if first and which == "ergm":
            def netrow(y, b=b):
                return [C("TEXT", "tx_net", X0, y + 2, 120, label="Network:"),
                        C("COMBOBOX", "cb_net", 140, y, 220)]
            rows.append(("raw", netrow))
        for n in NOTES.get((t["key"], which), []):
            rows.append(("note", n))
        if t["key"] == "cons":
            rows.append(("consheader",))
        last_sec = None
        for e in es:
            if e.get("section") and e["section"] != last_sec:
                rows.append(("section", e["section"]))
                last_sec = e["section"]
            rows.append(("cons", e) if e["kind"] == "cons" else ("entry", e))
        if not es and not rows:
            continue
        if not es:
            continue
        b.build_tab(t, rows, first)
        first = False
    assemble(b, TAB_PLAN[which])
    b.register()
    return b, ents


# ---------------------------------------------------------------------------------------
# command program
# ---------------------------------------------------------------------------------------

def ref(b, cid):
    return "%s.%s" % (b.dlgof[cid], cid)


def cond_field(b, e, f):
    """DLG condition meaning 'this field is filled'."""
    cid = cid_f(e, f["name"])
    r = ref(b, cid)
    if f["w"] == "combo":
        return '%s.isneq("")' % r
    return r


def or_join(conds):
    return " | ".join(conds)


def wrap_cond(conds, indent="\t\t"):
    """Join conditions with | over several lines (/// continuation)."""
    lines = []
    cur = ""
    for c in conds:
        add = (" | " if cur else "") + c
        if len(cur) + len(add) > 120:
            lines.append(cur + " | ///")
            cur = c
        else:
            cur += add
    lines.append(cur)
    return ("\n" + indent + "\t").join(lines)


class Out:
    def __init__(self):
        self.lines = []
        self.ind = 1

    def w(self, s):
        self.lines.append("\t" * self.ind + s)

    def open(self, cond):
        self.w("if %s {" % cond)
        self.ind += 1

    def close(self):
        self.ind -= 1
        self.w("}")

    def text(self):
        return "\n".join(self.lines)


def put(out, *items):
    out.w("put " + " ".join(items))


def q(s):
    return '"%s"' % s


def gen_flag(b, out, e):
    out.open(ref(b, cid_cx(e)))
    put(out, q(" " + e["name"]))
    out.close()


def gen_opt(b, out, e):
    cx = ref(b, cid_cx(e))
    out.open(cx)
    fm = e["fields"][0]
    out.w("require " + ref(b, cid_f(e, "main")))
    put(out, q(" %s(" % e["name"]), ref(b, cid_f(e, "main")))
    for f in e["fields"][1:]:
        if f["name"] == "sub":
            if e.get("subreq"):
                out.w("require " + ref(b, cid_f(e, "sub")))
            out.open(ref(b, cid_f(e, "sub")))
            put(out, q(", "), ref(b, cid_f(e, "sub")))
            out.close()
    put(out, q(")"))
    for f in e["fields"][1:]:
        if f["name"] != "sub":
            oname = [o for o in e["options"] if o[1] == f["name"]][0][0]
            out.open(ref(b, cid_f(e, f["name"])))
            put(out, q(" %s(" % oname), ref(b, cid_f(e, f["name"])), q(")"))
            out.close()
    out.close()


def gen_ctl(b, out, e):
    f = e["fields"][0]
    name = e["name"]
    r = ref(b, cid_f(e))
    if f["w"] == "check":
        out.open(r)
        put(out, q(" " + name))
        out.close()
    elif f["w"] == "combo":
        out.open('%s.isneq("")' % r)
        put(out, q(" %s(" % name), r, q(")"))
        out.close()
    else:
        out.open(r)
        put(out, q(" %s(" % name), r, q(")"))
        out.close()


def token_conds(b, e):
    """Per field: (condition, emit-function) for tokens within a struct term."""
    res = []
    for f in e["fields"]:
        cid = cid_f(e, f["name"])
        if f["w"] == "check":
            res.append((ref(b, cid), [q(f["key"])], f))
        elif f["w"] == "combo":
            res.append(('%s.isneq("")' % ref(b, cid), [q((f["key"] + "=") if f.get("key") else ""), ref(b, cid)], f))
        else:
            pre = (f["key"] + "=") if f.get("key") else ""
            res.append((ref(b, cid), ([q(pre)] if pre else []) + [ref(b, cid)], f))
    return res


def gen_struct(b, out, e):
    out.open(ref(b, cid_cx(e)))
    put(out, q(" " + e["name"]))
    toks = token_conds(b, e)
    for (c, _, f) in toks:
        if f.get("req"):
            out.w("require " + c)
    if toks:
        out.open(or_join([c for (c, _, _) in toks]))
        put(out, q("("))
        for i, (c, items, f) in enumerate(toks):
            out.open(c)
            if i > 0:
                out.open(or_join([c2 for (c2, _, _) in toks[:i]]))
                put(out, q(" "))
                out.close()
            put(out, *items)
            out.close()
        put(out, q(")"))
        out.close()
    out.close()


def gen_oper_one(b, out, e, first):
    out.open(ref(b, cid_cx(e)))
    flds = e["fields"]
    for f in flds:
        if f.get("req"):
            out.w("require " + cond_field(b, e, f))
    if not first:
        pass
    if e.get("mode") == "for":
        put(out, q("%s(" % e["name"]), ref(b, cid_f(e, "loops")), q(", "), ref(b, cid_f(e, "terms")), q(")"))
    else:
        put(out, q("%s(" % e["name"]), ref(b, cid_f(e, "terms")))
        subs = [f for f in flds if f["name"] != "terms"]
        for i, f in enumerate(subs):
            c = cond_field(b, e, f)
            val = ref(b, cid_f(e, f["name"]))
            out.open(c)
            if i == 0:
                put(out, q(", %s(" % f["key"]), val, q(")"))
            else:
                earlier = [cond_field(b, e, g) for g in subs[:i]]
                out.open(or_join(earlier))
                put(out, q(" %s(" % f["key"]), val, q(")"))
                out.close()
                out.open("!(%s)" % or_join(earlier))
                put(out, q(", %s(" % f["key"]), val, q(")"))
                out.close()
            out.close()
        put(out, q(")"))
    out.close()


def gen_block_list(b, out, ents, opener, closer, gen_one, extra_ctl=None, sep_items=None):
    pass


PROGS = {}
CHUNK_LINES = 100   # Stata rejects a dialog PROGRAM with too many statements, so long blocks go into sub-programs


def chunk_emit(out, prefix, fns):
    """Run the generator functions into sub-programs of at most about CHUNK_LINES lines; the caller's program
    gets one `put /program name` for each."""
    cur = Out()
    k = 0

    def flush():
        nonlocal cur, k
        if cur.lines:
            k += 1
            name = "%s%d" % (prefix, k)
            PROGS[name] = cur.text()
            out.w("put /program " + name)
            cur = Out()
    for fn in fns:
        fn(cur)
        if len(cur.lines) >= CHUNK_LINES:
            flush()
    flush()


def command_program(b, ents, which):
    PROGS.clear()
    out = Out()
    byk = lambda k: [e for e in ents if e["kind"] == k]  # noqa: E731
    if which == "ergm":
        out.w('put "nwergm " %s' % ref(b, "cb_net"))
    else:
        out.w("require %s" % ref(b, cid_f(S_by_id("sim_nodes"))))
        out.w('put "nwergm simulate " %s' % ref(b, cid_f(S_by_id("sim_nodes"))))
    out.w("beginoptions")
    out.ind += 1
    structs = []
    ops = []
    plain = []
    for e in ents:
        k = e["kind"]
        if e["id"] == "sim_nodes":
            continue
        if k == "flag":
            plain.append(lambda o, e=e: gen_flag(b, o, e))
        elif k == "opt":
            plain.append(lambda o, e=e: gen_opt(b, o, e))
        elif k == "ctl":
            if e["id"] in ("operators_extra", "constraints_extra", "obsconstraints_extra"):
                continue
            plain.append(lambda o, e=e: gen_ctl(b, o, e))
        elif k == "struct":
            structs.append(e)
        elif k == "oper":
            ops.append(e)
    chunk_emit(out, "o_plain", plain)
    if structs:
        conds = [ref(b, cid_cx(e)) for e in structs]
        out.open(wrap_cond(conds))
        put(out, q(" structural("))
        chunk_emit(out, "o_struct", [lambda o, e=e: gen_struct(b, o, e) for e in structs])
        put(out, q(")"))
        out.close()
    extra = [e for e in ents if e["id"] == "operators_extra"]
    if ops or extra:
        conds = [ref(b, cid_cx(e)) for e in ops] + [ref(b, cid_f(e)) for e in extra]
        out.open(wrap_cond(conds))
        put(out, q(" operators("))

        def one_op(o, i, e):
            o.open(ref(b, cid_cx(e)))
            if i > 0:
                o.open(or_join([ref(b, cid_cx(x)) for x in ops[:i]]))
                put(o, q(" "))
                o.close()
            o.close()
            gen_oper_one(b, o, e, i == 0)

        def one_extra(o, e):
            o.open(ref(b, cid_f(e)))
            if ops:
                o.open(or_join([ref(b, cid_cx(x)) for x in ops]))
                put(o, q(" "))
                o.close()
            put(o, ref(b, cid_f(e)))
            o.close()
        fns = [lambda o, i=i, e=e: one_op(o, i, e) for i, e in enumerate(ops)] + [lambda o, e=e: one_extra(o, e) for e in extra]
        chunk_emit(out, "o_oper", fns)
        put(out, q(")"))
        out.close()
    cons = byk("cons")
    for (pref, opt_name, extra_id) in (("", "constraints", "constraints_extra"), ("o_", "obsconstraints", "obsconstraints_extra")):
        ex = [e for e in ents if e["id"] == extra_id]
        if not cons and not ex:
            continue
        conds = [ref(b, pref + cid_cx(e)) for e in cons] + [ref(b, cid_f(e)) for e in ex]
        if not conds:
            continue
        out.open(wrap_cond(conds))
        put(out, q(" %s(" % opt_name))

        def one_cons(o, i, e, pref=pref):
            o.open(ref(b, pref + cid_cx(e)))
            if i > 0:
                o.open(or_join([ref(b, pref + cid_cx(x)) for x in cons[:i]]))
                put(o, q(" + "))
                o.close()
            put(o, q(e["name"]))
            if e.get("has_arg"):
                o.open(ref(b, pref + cid_f(e)))
                put(o, q("("), ref(b, pref + cid_f(e)), q(")"))
                o.close()
            o.close()

        def one_cextra(o, e, pref=pref):
            r = ref(b, cid_f(e))
            o.open(r)
            if cons:
                allc = or_join([ref(b, pref + cid_cx(x)) for x in cons])
                o.open("(%s) & (%s.startswith(\"+\") | %s.startswith(\"-\"))" % (allc, r, r))
                put(o, q(" "))
                o.close()
                o.open("(%s) & !(%s.startswith(\"+\") | %s.startswith(\"-\"))" % (allc, r, r))
                put(o, q(" + "))
                o.close()
            put(o, r)
            o.close()
        fns = [lambda o, i=i, e=e: one_cons(o, i, e) for i, e in enumerate(cons)] + [lambda o, e=e: one_cextra(o, e) for e in ex]
        chunk_emit(out, "o_" + opt_name[:3] + "_", fns)
        put(out, q(")"))
        out.close()
    out.ind -= 1
    out.w("endoptions")
    out.w("stata")
    return out.text()


def S_by_id(i):
    for e in S.ENTRIES:
        if e["id"] == i:
            return e
    raise KeyError(i)


# ---------------------------------------------------------------------------------------
# file assembly
# ---------------------------------------------------------------------------------------

def emit_file(b, ents, which, fname, label, help_cmd, dlgname, cmdprog):
    L = []
    L.append("/* %s - generated by dlg/gen_dialogs.py from dlg/nwergm_dialog_spec.py; do not edit by hand. */" % fname)
    L.append("VERSION 14.0")
    L.append("SYNCHRONOUS_ONLY")
    L.append("")
    L.append("INCLUDE _std_xxwide")
    L.append("DEFINE _dlgwd %d" % W)
    L.append("DEFINE _dlght %d" % H)
    L.append("INCLUDE header")
    L.append("")
    L.append('HELP hlp1, view("%s")' % help_cmd)
    L.append("RESET res1")
    L.append("")
    L.append("SCRIPT PREINIT")
    L.append("BEGIN")
    L.append("\tprogram initialize")
    L.append("END")
    L.append("")
    if b.scripts:
        L.append("SCRIPT POSTINIT")
        L.append("BEGIN")
        for s_ in b.hidden_at_start:
            L.append("\tscript " + s_)
        L.append("END")
        L.append("")
        for sname, lines in b.scripts:
            L.append("SCRIPT %s" % sname)
            L.append("BEGIN")
            for ln in lines:
                L.append("\t" + ln)
            L.append("END")
            L.append("")
    for i, pg in enumerate(b.pages):
        if i == 0:
            L.append('DIALOG %s, label("%s") tabtitle("%s")' % (pg["name"], label, pg["title"]))
        else:
            L.append('DIALOG %s, tabtitle("%s")' % (pg["name"], pg["title"]))
        L.append("BEGIN")
        for c in pg["ctls"]:
            L.append(c.dlg())
        L.append("END")
        L.append("")
    L.append("LIST netlist")
    L.append("BEGIN")
    L.append("\t// filled in when the dialog opens (see PROGRAM initialize)")
    L.append("END")
    L.append("")
    for name, items in b.lists.items():
        L.append("LIST %s" % name)
        L.append("BEGIN")
        for it in items:
            L.append("\t" + it)
        L.append("END")
        L.append("")
    L.append("PROGRAM initialize")
    L.append("BEGIN")
    L.append('\tput "_nwdialog %s"' % dlgname)
    L.append("\tstata hidden immediate")
    L.append("END")
    L.append("")
    for pname, ptxt in list(PROGS.items()):
        L.append("PROGRAM %s" % pname)
        L.append("BEGIN")
        L.append(ptxt)
        L.append("END")
        L.append("")
    L.append("PROGRAM command")
    L.append("BEGIN")
    L.append(cmdprog)
    L.append("END")
    L.append("")
    return "\n".join(L)


# ---------------------------------------------------------------------------------------
# estat dialog
# ---------------------------------------------------------------------------------------

def build_estat():
    b = Builder("estat")
    ents = []
    for (cid, tabk, opt_, w, lab, choices, hint, smoke) in S.ESTAT:
        e = dict(id=cid, tab=tabk, kind="ctl", name=opt_, label=lab, ergm=[], nets="UDB",
                 fields=[S.F("main", w, choices=choices, width=110 if w == "edit" else None)], options=[(opt_, "main")],
                 hint=hint, smoke=dict(use=dict(main=smoke)))
        ents.append(e)
    # which-command selector (first tab)
    which_choices = ["gof", "mcmcdiag", "ic", "simfit"]
    which_labels = ["estat gof - goodness of fit", "estat mcmcdiag - MCMC diagnostics", "estat ic - information criteria",
                    "nwergm simulate - draw networks from the fitted model"]
    b.lists["l_which"] = which_labels
    b.lists["l_which_v"] = which_choices

    def r_which(y):
        return [C("TEXT", "tx_which", X0, y + 2, 120, label="Run:"),
                C("COMBOBOX", "cb_which", 140, y, 380, choices=which_choices, lst="l_which")]
    rows = [("raw", r_which),
            ("note", "These commands work on the last model fitted with nwergm (they need the fitted model in memory)."),
            ("note", "Choose the command above, then set its options on the tab with the same name and press OK."),
            ("note", "estat gof / mcmcdiag / ic are postestimation commands; the last choice draws networks from the fit."),
            ]
    tabs = S.ESTAT_TABS
    for i, t in enumerate(tabs):
        es = [e for e in ents if e["tab"] == t["key"]]
        r = list(rows) if i == 0 else []
        if t["key"] == "gof":
            for e in es:
                r.append(("entry", e))
            r.append(("section", "gof(): statistics to compare (none ticked = the default for the network type)"))

            def gofrow(y, k=0):
                ctls = []
                for j, nm in enumerate(S.GOF_STATS):
                    pass
                return ctls
            # two columns of checkboxes
            half = (len(S.GOF_STATS) + 1) // 2
            for j in range(half):
                def mk(y, j=j):
                    ctls = []
                    for col, idx in ((0, j), (1, j + half)):
                        if idx < len(S.GOF_STATS):
                            nm = S.GOF_STATS[idx]
                            ctls.append(C("CHECKBOX", "cx_gof_" + nm, 10 + col * 300, y, 280, label=nm, default=False))
                    return ctls
                r.append(("raw", mk))
            r.append(("raw", lambda y: [C("CHECKBOX", "cx_gof_dropmodel", 10, y, 560, label="drop the model statistics (writes -model; use with 'model' unticked)", default=False)]))
        elif t["key"] == "ic":
            r.append(("note", "estat ic reports the log-likelihood, AIC and BIC of the last nwergm fit. It has no options."))
        else:
            for e in es:
                r.append(("entry", e))
        b.build_tab(t, r, i == 0)
    b.register()
    return b, ents


def estat_command(b, ents):
    PROGS.clear()
    out = Out()
    sel = ref(b, "cb_which")
    for (val, head, tabk) in (("gof", "estat gof", "gof"), ("mcmcdiag", "estat mcmcdiag", "mcmcdiag"), ("simfit", "nwergm simulate", "simfit")):
        out.open('%s.iseq("%s")' % (sel, val))
        put(out, q(head))
        out.w("beginoptions")
        out.ind += 1
        for e in [x for x in ents if x["tab"] == tabk]:
            gen_ctl(b, out, e)
        if val == "gof":
            toks = ["cx_gof_" + n for n in S.GOF_STATS] + ["cx_gof_dropmodel"]
            conds = [ref(b, c) for c in toks]
            out.open(wrap_cond(conds))
            put(out, q(" gof("))
            for i, c in enumerate(toks):
                out.open(ref(b, c))
                if i > 0:
                    out.open(or_join([ref(b, c2) for c2 in toks[:i]]))
                    put(out, q(" "))
                    out.close()
                put(out, q("-model" if c == "cx_gof_dropmodel" else c[len("cx_gof_"):]))
                out.close()
            put(out, q(")"))
            out.close()
        out.ind -= 1
        out.w("endoptions")
        out.close()
    out.open('%s.iseq("ic")' % sel)
    put(out, q("estat ic"))
    out.close()
    out.w("stata")
    return out.text()


# ---------------------------------------------------------------------------------------

def main():
    outdir = ROOT
    # nwergm.dlg
    b, ents = build_main("ergm")
    cp = command_program(b, ents, "ergm")
    txt = emit_file(b, ents, "ergm", "nwergm.dlg", "nwergm - Exponential random graph models (ERGM)", "help nwergm", "nwergm", cp)
    open(os.path.join(outdir, "nwergm.dlg"), "w").write(txt)
    print("nwergm.dlg: %d tabs, %d controls" % (len(b.pages), sum(len(p["ctls"]) for p in b.pages)))
    # nwergm_simulate.dlg
    b2, ents2 = build_main("sim")
    cp2 = command_program(b2, ents2, "sim")
    txt2 = emit_file(b2, ents2, "sim", "nwergm_simulate.dlg", "nwergm simulate - draw networks from an ERGM", "help nwergm", "nwergm_simulate", cp2)
    open(os.path.join(outdir, "nwergm_simulate.dlg"), "w").write(txt2)
    print("nwergm_simulate.dlg: %d tabs, %d controls" % (len(b2.pages), sum(len(p["ctls"]) for p in b2.pages)))
    # nwergm_estat.dlg
    b3, ents3 = build_estat()
    cp3 = estat_command(b3, ents3)
    txt3 = emit_file(b3, ents3, "estat", "nwergm_estat.dlg", "nwergm - postestimation (gof, MCMC diagnostics, information criteria, simulation)", "help nwergm_estat", "nwergm_estat", cp3)
    open(os.path.join(outdir, "nwergm_estat.dlg"), "w").write(txt3)
    print("nwergm_estat.dlg: %d tabs, %d controls" % (len(b3.pages), sum(len(p["ctls"]) for p in b3.pages)))
    for w in sorted(set(WARN)):
        print("WARNING:", w)


if __name__ == "__main__":
    main()

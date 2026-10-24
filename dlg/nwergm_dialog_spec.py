"""
Specification of the nwergm dialog boxes (single source of truth).

gen_dialogs.py turns this into nwergm.dlg, nwergm_simulate.dlg and nwergm_estat.dlg;
check_dialogs.py checks the generated files and that the spec covers 100% of the options of
the syntax lines of the ado files and of the implemented terms in docs/ERGM_TERMS_INVENTORY.csv;
smoke_dialogs.py builds the command text of every entry exactly as the dialog would and runs it.

An ENTRY is one row of a dialog tab:

  id      unique short id (control ids are derived: cx_<id> for the tick box, f_<id>[_<field>])
  tab     tab key (see TABS)
  kind    flag      option without argument                    ->  " name"
          opt       option with one or more arguments          ->  " name(main[, sub])"
          struct    term inside structural(...)                ->  "name(key=value flag ...)"
          oper      operator inside operators(...)             ->  "Name(terms[, sub(value) ...])"
          ctl       option with a single control (edit, combo, tick box), no tick box in front
          cons      constraint term (appears in constraints() and obsconstraints())
  label   the nwergm syntax shown in the dialog
  ergm    list of R ergm term names that the entry realises (inventory column "term")
  nets    network types the entry works on: U undirected, D directed, B two-mode
  fields  list of fields (see F())
  options for kind opt: list of (option name, field name) emitted when the field is not empty
  hint    short text shown at the right of the row (allowed sub-options, restrictions)
  sim     True if the option is accepted by `nwergm simulate` (filled in from the ado syntax)
  smoke   dict used by smoke_dialogs.py: net (und/dir/bip), use {field: value}, also {entry: value}
"""

# --------------------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------------------

def F(name="main", w="edit", width=None, key=None, text=None, default=None, choices=None, req=False, flag=False):
    """A field (input widget) of an entry.
    w: edit | varlist | net | combo | check
    key: for struct entries, the R argument name written as key=value (a check field writes just the key)
    text: label printed in front of the widget (default: key)
    choices: for combo, list of values (the first, '', means "leave out")
    """
    return dict(name=name, w=("check" if flag else w), width=width, key=key, text=text, default=default,
                choices=choices, req=req)


ENTRIES = []
TABS = []          # (key, title, dialogs)  dialogs = set of 'ergm', 'sim'
SECTIONS = {}      # entry id -> section header printed before it


def tab(key, title, dialogs=("ergm", "sim")):
    TABS.append(dict(key=key, title=title, dialogs=set(dialogs)))


def _add(e):
    assert e["id"] not in [x["id"] for x in ENTRIES], e["id"]
    e.setdefault("ergm", [])
    e.setdefault("nets", "UDB")
    e.setdefault("fields", [])
    e.setdefault("hint", "")
    e.setdefault("smoke", {})
    e.setdefault("section", None)
    e.setdefault("sim", None)
    ENTRIES.append(e)
    return e


def flag(id, tabkey, name, ergm=None, nets="UD", hint="", smoke=None, label=None, default=False, section=None):
    ergm = [name] if ergm is None else ergm
    return _add(dict(id=id, tab=tabkey, kind="flag", name=name, label=label or name, ergm=ergm, nets=nets,
                     hint=hint, smoke=smoke or {}, default=default, section=section,
                     options=[(name, None)]))


def opt(id, tabkey, name, ergm=None, main="varlist", sub=False, nets="UD", hint="", smoke=None, label=None,
        default=None, section=None, mainwidth=None, extra=None, subreq=False, subtext=None):
    """option name(main[, sub]); extra = list of extra (option, field) pairs written when ticked."""
    ergm = [name] if ergm is None else ergm
    fields = [F("main", main, width=mainwidth, default=default, req=True)]
    options = [(name, "main")]
    if sub:
        fields.append(F("sub", "edit", width=150, text=subtext))
    if extra:
        for (oname, fname, wt) in extra:
            fields.append(F(fname, "edit", width=wt, text=oname, key=oname))
            options.append((oname, fname))
    return _add(dict(id=id, tab=tabkey, kind="opt", name=name, label=label or (name + "()"), ergm=ergm, nets=nets,
                     fields=fields, options=options, hint=hint, smoke=smoke or {}, section=section,
                     has_sub=sub, subreq=subreq))


def struct(id, tabkey, name, ergm=None, fields=None, nets="UD", hint="", smoke=None, label=None, section=None):
    ergm = [name] if ergm is None else ergm
    return _add(dict(id=id, tab=tabkey, kind="struct", name=name, label=label or name, ergm=ergm, nets=nets,
                     fields=fields or [], hint=hint, smoke=smoke or {}, section=section, options=[("structural", None)]))


def oper(id, tabkey, name, fields, hint="", smoke=None, nets="UDB", mode="std"):
    return _add(dict(id=id, tab=tabkey, kind="oper", name=name, label=name + "()", ergm=[name], nets=nets,
                     fields=fields, hint=hint, smoke=smoke or {}, mode=mode, options=[("operators", None)]))


def ctl(id, tabkey, name, w, label, choices=None, hint="", smoke=None, default=None, nets="UDB", width=None, ergm=None,
        simonly=False, cmdonly=None, key=None):
    """Option with a single control and no tick box in front of it (w: edit | combo | check | net | varname)."""
    return _add(dict(id=id, tab=tabkey, kind="ctl", name=name, label=label, ergm=ergm or [], nets=nets,
                     fields=[F("main", w, choices=choices, default=default, width=width)],
                     options=[(name, "main")], hint=hint, smoke=smoke or {}))


def cons(id, name, hint="", smoke=None, arg=True, nets="UDB"):
    return _add(dict(id=id, tab="cons", kind="cons", name=name, label=name, ergm=[], nets=nets,
                     fields=[F("main", "edit", width=150)] if arg else [], hint=hint, smoke=smoke or {},
                     options=[("constraints", None), ("obsconstraints", None)], has_arg=arg))


# --------------------------------------------------------------------------------------
# tabs (in the order shown)
# --------------------------------------------------------------------------------------

tab("basic", "Network and basic terms")
tab("deg", "Degree terms")
tab("tri", "Triad terms")
tab("cov", "Covariate terms")
tab("two", "Two-mode terms")
tab("curved", "Curved terms")
tab("oper", "Operators")
tab("cons", "Constraints", ("ergm",))
tab("space", "Missing data and sample space", ("ergm", "sim"))
tab("est", "Estimation", ("ergm",))
tab("mcmc", "MCMC settings", ("ergm", "sim"))
tab("out", "Output and bridge sampling", ("ergm",))
tab("simctl", "Simulation settings", ("sim",))

# --------------------------------------------------------------------------------------
# BASIC
# --------------------------------------------------------------------------------------
# edges is the one required term; the network drop-down is built into the generator.
flag("edges", "basic", "edges", nets="UDB", default=True,
     hint="required (intercept); may be omitted only with density or meandeg",
     smoke=dict(net="und"), section="Required term")
flag("mutual", "basic", "mutual", nets="D", hint="directed only", smoke=dict(net="dir"), section="Reciprocity, triangles, concurrency")
flag("triangle", "basic", "triangle", nets="U", hint="undirected only (R: triangle)", smoke=dict(net="und"))
flag("ctriple", "basic", "ctriple", nets="D", hint="directed only (cyclic triples)", smoke=dict(net="dir"))
flag("transitiveties", "basic", "transitiveties", nets="D", hint="directed only", smoke=dict(net="dir"))
flag("cyclicalties", "basic", "cyclicalties", nets="D", hint="directed only", smoke=dict(net="dir"))
flag("concurrent", "basic", "concurrent", nets="U", hint="undirected only (degree 2 or more)", smoke=dict(net="und"))
flag("sender", "basic", "sender", nets="D", hint="directed only; one coefficient per node (out-degree)", smoke=dict(net="dir"), section="Node-level effects")
flag("receiver", "basic", "receiver", nets="D", hint="directed only; one coefficient per node (in-degree)", smoke=dict(net="dir"))

struct("density", "basic", "density", nets="UD", hint="structural(); collinear with edges", smoke=dict(net="und"), section="Simple structural() terms (need the native plugin)")
struct("meandeg", "basic", "meandeg", nets="UD", hint="structural(); collinear with edges", smoke=dict(net="und"))
struct("twopath", "basic", "twopath", nets="UD", hint="structural(): two-paths", smoke=dict(net="und"))
struct("isolates", "basic", "isolates", nets="UD", hint="structural(): isolated nodes", smoke=dict(net="und"))
struct("isolatededges", "basic", "isolatededges", nets="U", hint="structural(), undirected only", smoke=dict(net="und"))

# --------------------------------------------------------------------------------------
# DEGREE
# --------------------------------------------------------------------------------------
opt("degree", "deg", "degree", main="edit", nets="U", hint="numlist, e.g. 1 2 3; undirected only", smoke=dict(net="und", use=dict(main="1 2 3")), section="Degree distribution (native options)")
opt("odegree", "deg", "odegree", main="edit", nets="D", hint="numlist; directed only", smoke=dict(net="dir", use=dict(main="1 2")))
opt("idegree", "deg", "idegree", main="edit", nets="D", hint="numlist; directed only", smoke=dict(net="dir", use=dict(main="1 2")))
opt("kstar", "deg", "kstar", main="edit", nets="U", hint="numlist of k; undirected only", smoke=dict(net="und", use=dict(main="2")))
opt("ostar", "deg", "ostar", main="edit", nets="D", hint="numlist of k; directed only", smoke=dict(net="dir", use=dict(main="2")))
opt("istar", "deg", "istar", main="edit", nets="D", hint="numlist of k; directed only", smoke=dict(net="dir", use=dict(main="2")))
opt("degrange", "deg", "degrange", ergm=["degrange"], main="edit", nets="U", label="degrange() + degrangeto()",
    extra=[("degrangeto", "to", 90)], hint="from-values, then to-values; undirected only",
    smoke=dict(net="und", use=dict(main="1 3", to="3 .")))
opt("odegrange", "deg", "odegrange", ergm=["odegrange"], main="edit", nets="D", label="odegrange() + odegrangeto()",
    extra=[("odegrangeto", "to", 90)], hint="from-values, then to-values; directed only",
    smoke=dict(net="dir", use=dict(main="1 3", to="3 .")))
opt("idegrange", "deg", "idegrange", ergm=["idegrange"], main="edit", nets="D", label="idegrange() + idegrangeto()",
    extra=[("idegrangeto", "to", 90)], hint="from-values, then to-values; directed only",
    smoke=dict(net="dir", use=dict(main="1 3", to="3 .")))

S1 = "Degree terms with by= / homophily (structural())"
struct("s_degree", "deg", "degree", fields=[F("d", key="d", width=60), F("by", key="by", width=60), F("homophily", flag=True, key="homophily")],
       nets="U", label="degree(d= by= homophily)", hint="undirected only", smoke=dict(net="und", use=dict(d="1 2", by="sex", homophily=True)), section=S1)
struct("s_odegree", "deg", "odegree", fields=[F("d", key="d", width=60), F("by", key="by", width=60), F("homophily", flag=True, key="homophily")],
       nets="D", label="odegree(d= by= homophily)", hint="directed only", smoke=dict(net="dir", use=dict(d="1 2", by="sex")))
struct("s_idegree", "deg", "idegree", fields=[F("d", key="d", width=60), F("by", key="by", width=60), F("homophily", flag=True, key="homophily")],
       nets="D", label="idegree(d= by= homophily)", hint="directed only", smoke=dict(net="dir", use=dict(d="1 2", by="sex")))
struct("s_degrange", "deg", "degrange", fields=[F("from", key="from", width=50), F("to", key="to", width=50), F("by", key="by", width=50), F("homophily", flag=True, key="homophily")],
       nets="U", label="degrange(from= to= by= homophily)", hint="undirected", smoke=dict(net="und", use={"from": "1 3", "to": "3 .", "by": "sex"}))
struct("s_odegrange", "deg", "odegrange", fields=[F("from", key="from", width=50), F("to", key="to", width=50), F("by", key="by", width=50), F("homophily", flag=True, key="homophily")],
       nets="D", label="odegrange(from= to= by=)", hint="directed", smoke=dict(net="dir", use={"from": "1 3", "to": "3 .", "by": "sex"}))
struct("s_idegrange", "deg", "idegrange", fields=[F("from", key="from", width=50), F("to", key="to", width=50), F("by", key="by", width=50), F("homophily", flag=True, key="homophily")],
       nets="D", label="idegrange(from= to= by=)", hint="directed", smoke=dict(net="dir", use={"from": "1 3", "to": "3 .", "by": "sex"}))
struct("s_kstar", "deg", "kstar", fields=[F("k", key="k", width=60), F("attr", key="attr", width=70)],
       nets="U", label="kstar(k= attr=)", hint="undirected", smoke=dict(net="und", use=dict(k="2", attr="sex")))
struct("s_ostar", "deg", "ostar", fields=[F("k", key="k", width=60), F("attr", key="attr", width=70)],
       nets="D", label="ostar(k= attr=)", hint="directed", smoke=dict(net="dir", use=dict(k="2", attr="sex")))
struct("s_istar", "deg", "istar", fields=[F("k", key="k", width=60), F("attr", key="attr", width=70)],
       nets="D", label="istar(k= attr=)", hint="directed", smoke=dict(net="dir", use=dict(k="2", attr="sex")))
struct("s_concurrent", "deg", "concurrent", fields=[F("by", key="by", width=70)], nets="U", label="concurrent(by=)",
       hint="structural form of concurrent; undirected", smoke=dict(net="und", use=dict(by="sex")))
struct("concurrentties", "deg", "concurrentties", fields=[F("by", key="by", width=70)], nets="U", label="concurrentties(by=)",
       hint="undirected", smoke=dict(net="und", use=dict(by="sex")))

S2 = "Other degree terms (structural())"
struct("degree1_5", "deg", "degree1.5", nets="U", label="degree1.5", hint="undirected", smoke=dict(net="und"), section=S2)
struct("odegree1_5", "deg", "odegree1.5", nets="D", label="odegree1.5", hint="directed", smoke=dict(net="dir"))
struct("idegree1_5", "deg", "idegree1.5", nets="D", label="idegree1.5", hint="directed", smoke=dict(net="dir"))
struct("degcrossprod", "deg", "degcrossprod", nets="U", hint="undirected; not in nwergm simulate", smoke=dict(net="und"))
struct("degcor", "deg", "degcor", nets="U", hint="undirected; not in nwergm simulate", smoke=dict(net="und"))
struct("m2star", "deg", "m2star", nets="D", hint="structural(), directed only", smoke=dict(net="dir"))

# --------------------------------------------------------------------------------------
# TRIAD and shared partners
# --------------------------------------------------------------------------------------
opt("esp", "tri", "esp", main="edit", nets="UD", hint="numlist of d; see type() on the Curved tab", smoke=dict(net="und", use=dict(main="1 2")), section="Shared partners (native options)")
opt("dsp", "tri", "dsp", main="edit", nets="UD", hint="numlist of d; see type() on the Curved tab", smoke=dict(net="und", use=dict(main="1 2")))

S3 = "Triad terms (structural())"
struct("s_triangle", "tri", "triangle", ergm=["triangle"], fields=[F("attr", key="attr", width=70), F("diff", flag=True, key="diff")],
       nets="UD", label="triangle(attr= diff)", hint="triangle by attribute", smoke=dict(net="und", use=dict(attr="sex", diff=True)), section=S3)
struct("transitive", "tri", "transitive", nets="D", hint="directed", smoke=dict(net="dir"))
struct("intransitive", "tri", "intransitive", nets="D", hint="directed", smoke=dict(net="dir"))
struct("ttriple", "tri", "ttriple", fields=[F("attr", key="attr", width=70), F("diff", flag=True, key="diff")],
       nets="D", label="ttriple(attr= diff)", hint="directed", smoke=dict(net="dir", use=dict(attr="sex", diff=True)))
struct("s_ctriple", "tri", "ctriple", ergm=["ctriple"], fields=[F("attr", key="attr", width=70), F("diff", flag=True, key="diff")],
       nets="D", label="ctriple(attr= diff)", hint="directed; plain form is on the first tab", smoke=dict(net="dir", use=dict(attr="sex", diff=True)))
struct("cycle", "tri", "cycle", fields=[F("k", key="k", width=60), F("semi", flag=True, key="semi")],
       nets="UD", label="cycle(k= semi)", hint="k = cycle lengths, e.g. 3 4", smoke=dict(net="und", use=dict(k="3 4")))
struct("threetrail", "tri", "threetrail", fields=[F("keep", key="keep", width=70)], nets="UD", label="threetrail(keep=)",
       hint="four types RRR RRL LRR LRL if directed", smoke=dict(net="und"))
struct("balance", "tri", "balance", nets="UD", hint="balanced triads", smoke=dict(net="und"))
struct("triadcensus", "tri", "triadcensus", fields=[F("levels", key="levels", width=70)], nets="UD", label="triadcensus(levels=)",
       hint="triad census", smoke=dict(net="und", use=dict(levels="1 2")))
struct("tripercent", "tri", "tripercent", fields=[F("attr", key="attr", width=70), F("diff", flag=True, key="diff")],
       nets="U", label="tripercent(attr= diff)", hint="undirected", smoke=dict(net="und", use=dict(attr="sex")))
struct("nearsimmelian", "tri", "nearsimmelian", nets="D", hint="directed", smoke=dict(net="dir"))
struct("simmelian", "tri", "simmelian", nets="D", hint="directed", smoke=dict(net="dir"))
struct("simmelianties", "tri", "simmelianties", nets="D", hint="directed", smoke=dict(net="dir"))
struct("asymmetric", "tri", "asymmetric", fields=[F("attr", key="attr", width=70), F("diff", flag=True, key="diff")],
       nets="D", label="asymmetric(attr= diff)", hint="directed", smoke=dict(net="dir", use=dict(attr="sex")))
struct("s_mutual", "tri", "mutual", ergm=["mutual"], fields=[F("same", key="same", width=60), F("diff", flag=True, key="diff"), F("by", key="by", width=60)],
       nets="D", label="mutual(same= diff by=)", hint="directed; use instead of plain mutual", smoke=dict(net="dir", use=dict(same="sex", diff=True)))
struct("localtriangle", "tri", "localtriangle", fields=[F("x", "net", key="x", width=90, req=True)], nets="UD", label="localtriangle(x=)",
       hint="x = network with the same nodes", smoke=dict(net="und", use=dict(x="ucov")))
struct("opentriad", "tri", "opentriad", nets="UD", hint="structural()", smoke=dict(net="und"))
struct("nsp", "tri", "nsp", fields=[F("d", key="d", width=60), F("type", "combo", key="type", width=70, choices=["", "OTP", "ITP", "OSP", "ISP", "RTP"])],
       nets="UD", label="nsp(d= type=)", hint="non-shared partner counts", smoke=dict(net="und", use=dict(d="1 2")))
struct("s_altkstar", "tri", "altkstar", ergm=["altkstar"], fields=[F("lambda", key="lambda", width=60, default="0.8"), F("fixed", flag=True, key="fixed")],
       nets="U", label="altkstar(lambda= fixed)", hint="fixed: lambda held; else curved, needs init(), method(mple)",
       smoke=dict(net="und", use={"lambda": "0.8", "fixed": True}))

# --------------------------------------------------------------------------------------
# COVARIATES (node attributes)
# --------------------------------------------------------------------------------------
SUBH = "[, "
SECN = "Node attribute terms (variables; the part after the comma is passed on as suboptions)"
opt("nodecov", "cov", "nodecov", sub=True, nets="UD", hint=SUBH + "expressions allowed]", smoke=dict(net="und", use=dict(main="age")), section=SECN)
opt("nodeicov", "cov", "nodeicov", sub=True, nets="D", hint="directed only", smoke=dict(net="dir", use=dict(main="age")))
opt("nodeocov", "cov", "nodeocov", sub=True, nets="D", hint="directed only", smoke=dict(net="dir", use=dict(main="age")))
opt("nodefactor", "cov", "nodefactor", sub=True, nets="UD", hint="[, levels() levelvalues() base()]", smoke=dict(net="und", use=dict(main="grp")))
opt("nodeofactor", "cov", "nodeofactor", sub=True, nets="D", hint="directed; [, levels() base()]", smoke=dict(net="dir", use=dict(main="grp")))
opt("nodeifactor", "cov", "nodeifactor", sub=True, nets="D", hint="directed; [, levels() base()]", smoke=dict(net="dir", use=dict(main="grp")))
opt("nodematch", "cov", "nodematch", sub=True, nets="UD", hint="[, diff keep() levels() levelvalues()]", smoke=dict(net="und", use=dict(main="sex", sub="diff")))
opt("nodematchdiff", "cov", "nodematchdiff", ergm=["nodematch"], sub=True, nets="UD", hint="same as nodematch(vars, diff)", smoke=dict(net="und", use=dict(main="grp")))
opt("nodemix", "cov", "nodemix", sub=True, nets="UDB", hint="[, levels() levels2() base()]; also two-mode", smoke=dict(net="und", use=dict(main="grp")))
opt("mm", "cov", "mm", sub=True, nets="UD", hint="[, levels() levels2()]; one attribute", smoke=dict(net="und", use=dict(main="grp")))
opt("absdist", "cov", "absdist", ergm=["absdiff"], sub=True, nets="UD", label="absdist()  [absdiff]", hint="[, pow(#)]", smoke=dict(net="und", use=dict(main="age", sub="pow(2)")))
opt("absdiffcat", "cov", "absdiffcat", sub=True, nets="UD", hint="[, levels() levelvalues() base()]", smoke=dict(net="und", use=dict(main="grp")))
opt("diff", "cov", "diff", sub=True, nets="UD", hint="[, pow() dir() signaction()]", smoke=dict(net="dir", use=dict(main="age")))
opt("smalldiff", "cov", "smalldiff", sub=True, nets="UD", hint="needs , cutoff(#)", smoke=dict(net="und", use=dict(main="age", sub="cutoff(5)")), subreq=True)
opt("sociality", "cov", "sociality", sub=True, nets="U", hint="[, nodes() levels()]; . = none; undirected", smoke=dict(net="und", use=dict(main=".")))
opt("nodecovrange", "cov", "nodecovrange", sub=True, nets="UD", hint="dyad-dependent", smoke=dict(net="und", use=dict(main="age")))
opt("nodeocovrange", "cov", "nodeocovrange", sub=True, nets="D", hint="directed; dyad-dependent", smoke=dict(net="dir", use=dict(main="age")))
opt("nodeicovrange", "cov", "nodeicovrange", sub=True, nets="D", hint="directed; dyad-dependent", smoke=dict(net="dir", use=dict(main="age")))
opt("nodefactordistinct", "cov", "nodefactordistinct", sub=True, nets="UD", hint="[, levels() levelvalues()]; dyad-dependent", smoke=dict(net="und", use=dict(main="grp")))
opt("nodeofactordistinct", "cov", "nodeofactordistinct", sub=True, nets="D", hint="directed; dyad-dependent", smoke=dict(net="dir", use=dict(main="grp")))
opt("nodeifactordistinct", "cov", "nodeifactordistinct", sub=True, nets="D", hint="directed; dyad-dependent", smoke=dict(net="dir", use=dict(main="grp")))

# --------------------------------------------------------------------------------------
# DYADIC covariates
# --------------------------------------------------------------------------------------
opt("edgecov", "cov", "edgecov", main="net", nets="UDB", hint="a network or an n x n Stata matrix; also two-mode", smoke=dict(net="und", use=dict(main="ucov")), section="Dyadic covariates (networks or matrices)")
opt("dyadcov", "cov", "dyadcov", main="net", nets="UD", hint="directed: 3 coefficients (mutual utri ltri)", smoke=dict(net="dir", use=dict(main="dcov")))
opt("hamming", "cov", "hamming", main="net", nets="UD", hint="Hamming distance to a reference network", smoke=dict(net="und", use=dict(main="ucov")))
opt("attrcov", "cov", "attrcov", sub=True, nets="UD", subreq=True, label="attrcov(vars, mat())",
    hint="matrix per level", smoke=dict(net="und", use=dict(main="grp", sub="mat(Mattr)")),
    subtext="mat(matname)")

# --------------------------------------------------------------------------------------
# TWO-MODE
# --------------------------------------------------------------------------------------
BIP = "two-mode only"
SB = "Two-mode terms (mode-1 / mode-2)"
for m in "12":
    opt("bcov" + m, "two", "bcov" + m, ergm=["b%scov" % m], nets="B", label="bcov%s()  [b%scov]" % (m, m), hint=BIP + "; node covariate",
        smoke=dict(net="bip", use=dict(main="age")), section=SB if m == "1" else None)
    opt("bfactor" + m, "two", "bfactor" + m, ergm=["b%sfactor" % m], nets="B", label="bfactor%s()  [b%sfactor]" % (m, m), hint=BIP,
        smoke=dict(net="bip", use=dict(main="grp")))
    opt("bdegree" + m, "two", "bdegree" + m, ergm=["b%sdegree" % m], main="edit", sub=True, nets="B", label="bdegree%s()  [b%sdegree]" % (m, m),
        hint=BIP + "; [, by() levels()]", smoke=dict(net="bip", use=dict(main="1 2")))
    opt("bstar" + m, "two", "bstar" + m, ergm=["b%sstar" % m], main="edit", sub=True, nets="B", label="bstar%s()  [b%sstar]" % (m, m),
        hint=BIP + "; [, attr() levels()]", smoke=dict(net="bip", use=dict(main="2")))
    opt("bnodematch" + m, "two", "bnodematch" + m, ergm=["b%snodematch" % m], sub=True, nets="B", label="bnodematch%s()  [b%snodematch]" % (m, m),
        hint=BIP + "; [, diff alpha()]", smoke=dict(net="bip", use=dict(main="sex")))
    opt("bgwdegree" + m, "two", "bgwdegree" + m, ergm=["gwb%sdegree" % m], main="edit", sub=True, nets="B", label="bgwdegree%s()  [gwb%sdegree]" % (m, m),
        hint=BIP + "; decay [, attr() levels()]", smoke=dict(net="bip", use=dict(main="0.5")), default="0.5")
    opt("bconcurrent" + m, "two", "bconcurrent" + m, ergm=["b%sconcurrent" % m], main="edit", nets="B", label="bconcurrent%s()  [b%sconcurrent]" % (m, m),
        hint=BIP + "; all  or  by(var) [levels()]", smoke=dict(net="bip", use=dict(main="all")), default="all")
    opt("bmindegree" + m, "two", "bmindegree" + m, ergm=["b%smindegree" % m], main="edit", nets="B", label="bmindegree%s()  [b%smindegree]" % (m, m),
        hint=BIP + "; numlist of d", smoke=dict(net="bip", use=dict(main="1 2")))
    opt("bdegrange" + m, "two", "bdegrange" + m, ergm=["b%sdegrange" % m], main="edit", sub=True, nets="B", label="bdegrange%s()  [b%sdegrange]" % (m, m),
        hint=BIP + "; [, to() by()]", smoke=dict(net="bip", use=dict(main="1 3", sub="to(3 .)")))
    opt("bcovrange" + m, "two", "bcovrange" + m, ergm=["b%scovrange" % m], nets="B", label="bcovrange%s()  [b%scovrange]" % (m, m),
        hint=BIP + "; one variable", smoke=dict(net="bip", use=dict(main="age")))
    opt("bfactordistinct" + m, "two", "bfactordistinct" + m, ergm=["b%sfactordistinct" % m], sub=True, nets="B",
        label="bfactordistinct%s()  [b%sfactordistinct]" % (m, m), hint=BIP + "; [, levels()]", smoke=dict(net="bip", use=dict(main="grp")))
    opt("bsociality" + m, "two", "bsociality" + m, ergm=["b%ssociality" % m], main="edit", nets="B", label="bsociality%s()  [b%ssociality]" % (m, m),
        hint=BIP + "; node positions, -1 drops the first", smoke=dict(net="bip", use=dict(main="-1")), default="-1")
    opt("bstarmix" + m, "two", "bstarmix" + m, ergm=["b%sstarmix" % m], main="edit", sub=True, nets="B", label="bstarmix%s()  [b%sstarmix]" % (m, m),
        hint=BIP + "; k [, attr() base()]", smoke=dict(net="bip", use=dict(main="2", sub="attr(grp)")))
    opt("btwostar" + m, "two", "btwostar" + m, ergm=["b%stwostar" % m], sub=True, nets="B", label="btwostar%s()  [b%stwostar]" % (m, m),
        hint=BIP + "; [, attr2()]", smoke=dict(net="bip", use=dict(main="grp")))
    opt("bdsp" + m, "two", "bdsp" + m, ergm=["b%sdsp" % m], main="edit", nets="B", label="bdsp%s()  [b%sdsp]" % (m, m),
        hint=BIP + "; numlist of d", smoke=dict(net="bip", use=dict(main="1 2")))
    opt("bgwdsp" + m, "two", "bgwdsp" + m, ergm=["gwb%sdsp" % m], main="edit", nets="B", label="bgwdsp%s()  [gwb%sdsp]" % (m, m),
        hint=BIP + "; fixed decay", smoke=dict(net="bip", use=dict(main="0.5")), default="0.5")
opt("coincidence", "two", "coincidence", main="edit", nets="B", hint=BIP + "; all  or  active(#)", smoke=dict(net="bip", use=dict(main="all")), default="all")
for m in "12":
    opt("bgwdegreefree" + m, "two", "bgwdegreefree" + m, ergm=[], main="edit", nets="B", label="bgwdegreefree%s()  [gwb%sdegree, curved]" % (m, m),
        hint=BIP + "; start value of the decay (estimated)", smoke=dict(net="bip", use=dict(main="0.5")), default="0.5",
        section="Two-mode curved terms (estimated decay)" if m == "1" else None)
    opt("bgwdspfree" + m, "two", "bgwdspfree" + m, ergm=[], main="edit", nets="B", label="bgwdspfree%s()  [gwb%sdsp, curved]" % (m, m),
        hint=BIP + "; start value of the decay (estimated)", smoke=dict(net="bip", use=dict(main="0.5")), default="0.5")

# --------------------------------------------------------------------------------------
# CURVED / geometrically weighted
# --------------------------------------------------------------------------------------
SC = "Geometrically weighted terms, fixed decay"
for (nm, nets, h) in [("gwesp", "UD", "edgewise shared partners"), ("gwdsp", "UD", "dyadwise shared partners"),
                      ("gwnsp", "UD", "non-edgewise shared partners"), ("gwdegree", "U", "undirected only"),
                      ("gwodegree", "D", "directed only"), ("gwidegree", "D", "directed only")]:
    opt(nm, "curved", nm, main="edit", nets=nets, default="0.5", hint="decay; " + h, smoke=dict(net="und" if "U" in nets else "dir", use=dict(main="0.5")),
        section=SC if nm == "gwesp" else None)
SC2 = "Curved terms: decay is estimated (the value is the starting value)"
for (nm, nets, h) in [("gwespfree", "UD", "gwesp"), ("gwdspfree", "U", "gwdsp"), ("gwnspfree", "U", "gwnsp"),
                      ("gwdegreefree", "U", "gwdegree"), ("gwodegreefree", "D", "gwodegree"), ("gwidegreefree", "D", "gwidegree")]:
    opt(nm, "curved", nm, ergm=[], main="edit", nets=nets, default="0.5", label=nm + "()  [" + h + ", curved]",
        hint="start value; method(mple) or mcmle", smoke=dict(net="und" if "U" in nets else "dir", use=dict(main="0.5")),
        section=SC2 if nm == "gwespfree" else None)
ctl("type", "curved", "type", "combo", "type()  - directed shared partners", choices=["", "OTP", "ITP", "OSP", "ISP", "RTP"],
    hint="applies to gwesp gwdsp gwnsp esp dsp (directed networks)", nets="D", smoke=dict(net="dir", use=dict(main="ITP"), also={"gwesp": "0.5"}))

# --------------------------------------------------------------------------------------
# OPERATORS
# --------------------------------------------------------------------------------------
TT = F("terms", "edit", width=300, req=True, text="terms")
tmaster = "terms are written as nwergm options, e.g. triangle kstar(2) structural(twopath)"
oper("op_sum", "oper", "Sum", [F("terms", "edit", width=250, req=True, text="formulas"), F("label", "edit", width=100, key="label", req=True)],
     hint="f1 | f2 ; label needed", smoke=dict(net="und", use=dict(terms="triangle", label="tri")))
oper("op_prod", "oper", "Prod", [F("terms", "edit", width=250, req=True, text="formulas"), F("label", "edit", width=100, key="label", req=True)],
     hint="f1 | f2 ; label needed", smoke=dict(net="und", use=dict(terms="triangle", label="tri")))
oper("op_s", "oper", "S", [F("terms", "edit", width=250, req=True, text="terms"), F("attrs", "edit", width=100, key="attrs", req=True)],
     hint="e.g. age>30", nets="UD", smoke=dict(net="und", use=dict(terms="triangle", attrs="sex==1")))
oper("op_f", "oper", "F", [F("terms", "edit", width=250, req=True, text="terms"), F("filter", "edit", width=130, key="filter", req=True)],
     hint="one dyad-independent term", smoke=dict(net="und", use=dict(terms="triangle", filter="nodematch(sex)")))
oper("op_nmf", "oper", "NodematchFilter", [F("terms", "edit", width=250, req=True, text="terms"), F("attrname", "edit", width=100, key="attrname", req=True)],
     hint="attrname: variables", smoke=dict(net="und", use=dict(terms="triangle", attrname="sex")))
oper("op_sym", "oper", "Symmetrize", [F("terms", "edit", width=250, req=True, text="terms"), F("rule", "combo", width=90, key="rule", choices=["", "weak", "strong", "upper", "lower"])],
     hint="directed networks only", nets="D", smoke=dict(net="dir", use=dict(terms="triangle", rule="strong")))
oper("op_proj", "oper", "Project", [F("terms", "edit", width=250, req=True, text="terms"), F("mode", "combo", width=60, key="mode", choices=["1", "2"], req=True)],
     hint="two-mode networks only", nets="B", smoke=dict(net="bip", use=dict(terms="edges", mode="1")))
oper("op_i", "oper", "I", [F("terms", "edit", width=300, req=True, text="terms")], hint="the terms themselves", smoke=dict(net="und", use=dict(terms="triangle")))
oper("op_for", "oper", "For", [F("loops", "edit", width=130, req=True, text="loops"), F("terms", "edit", width=200, req=True, text="terms")],
     hint="loops: v = sex grp", mode="for", smoke=dict(net="und", use=dict(loops="v = sex grp", terms="nodematch({v})")))
oper("op_label", "oper", "Label", [F("terms", "edit", width=200, req=True, text="terms"), F("label", "edit", width=90, key="label", req=True), F("pos", "combo", width=80, key="pos", choices=["", "paren", "prepend", "append", "replace"])],
     hint="", smoke=dict(net="und", use=dict(terms="triangle", label="tri2", pos="replace")))
oper("op_log", "oper", "Log", [F("terms", "edit", width=250, req=True, text="terms"), F("log0", "edit", width=70, key="log0")],
     hint="", smoke=dict(net="und", use=dict(terms="kstar(2)")))
oper("op_exp", "oper", "Exp", [F("terms", "edit", width=300, req=True, text="terms")], hint="", smoke=dict(net="und", use=dict(terms="triangle")))
oper("op_curve", "oper", "Curve", [F("terms", "edit", width=180, req=True, text="terms"), F("params", "edit", width=80, key="params", req=True), F("map", "edit", width=80, key="map", req=True)],
     hint="map: rep | matrix(L)", smoke=dict(net="und", use=dict(terms="triangle kstar(2)", params="p", map="rep")))
oper("op_offset", "oper", "Offset", [F("terms", "edit", width=200, req=True, text="terms"), F("coef", "edit", width=80, key="coef"), F("which", "edit", width=80, key="which")],
     hint="held at coef (default 0)", smoke=dict(net="und", use=dict(terms="triangle", coef="0.1")))
ctl("operators_extra", "oper", "operators", "edit", "Other operator calls (typed)", width=330, ergm=[],
    hint="added to operators(); blank-separated", smoke=dict(net="und", use=dict(main="I(triangle)")))

# --------------------------------------------------------------------------------------
# CONSTRAINTS (dual column: constraints() and obsconstraints())
# --------------------------------------------------------------------------------------
cons("c_edges", "edges", hint="keep the number of ties", smoke=dict(net="und"), arg=False)
cons("c_degrees", "degrees", hint="keep node degrees (nodedegrees)", smoke=dict(net="und"), arg=False)
cons("c_odegrees", "odegrees", hint="directed", smoke=dict(net="dir"), arg=False, nets="D")
cons("c_idegrees", "idegrees", hint="directed", smoke=dict(net="dir"), arg=False, nets="D")
cons("c_b1degrees", "b1degrees", hint="two-mode", smoke=dict(net="bip"), arg=False, nets="B")
cons("c_b2degrees", "b2degrees", hint="two-mode", smoke=dict(net="bip"), arg=False, nets="B")
cons("c_degreedist", "degreedist", hint="degree distribution", smoke=dict(net="und"), arg=False)
cons("c_idegreedist", "idegreedist", hint="in-degree distribution", smoke=dict(net="dir"), arg=False, nets="D")
cons("c_bd", "bd", hint="attribs, maxout=, maxin=, minout=, minin=", smoke=dict(net="und", use=dict(main="maxout=12")))
cons("c_blocks", "blocks", hint="attr, b1levels, b2levels, levels, levels2", smoke=dict(net="und", use=dict(main="grp, levels2=1")))
cons("c_blockdiag", "blockdiag", hint="attr, noncontig", smoke=dict(net="und", use=dict(main="sex")))
cons("c_fixedas", "fixedas", hint="fixed.dyads, present, absent", smoke=dict(net="und", use=dict(main="ucov")))
cons("c_fixallbut", "fixallbut", hint="free.dyads (network)", smoke=dict(net="und", use=dict(main="ucov")))
cons("c_observed", "observed", hint="only missing dyads vary", smoke=dict(net="und"), arg=False)
cons("c_egocentric", "egocentric", hint="attr (0/1 variable), direction", smoke=dict(net="und", use=dict(main="pos")))
cons("c_dyadnoise", "dyadnoise", hint="p01, p10", smoke=dict(net="und", use=dict(main="0.05, 0.05")))

# --------------------------------------------------------------------------------------
# SAMPLE SPACE and missing data
# --------------------------------------------------------------------------------------
ctl("constraints_extra", "space", "constraints", "edit", "constraints()  typed terms", width=330,
    hint="e.g. blockdiag(g) + bd(maxout=5)", smoke=dict(net="und", use=dict(main="edges"), also={"triangle": True}))
ctl("obsconstraints_extra", "space", "obsconstraints", "edit", "obsconstraints()  typed terms", width=330,
    hint="e.g. fixallbut(unobserved); mcmle", smoke=dict(net="und", use=dict(main="fixallbut(ucov)"), also={"triangle": True, "method": "mcmle", "mcmc_small": True}))
ctl("freedyads", "space", "freedyads", "net", "freedyads()", width=150, hint="network: its ties mark the free dyads", smoke=dict(net="und", use=dict(main="ucov")))
ctl("blockdiag", "space", "blockdiag", "varname", "blockdiag()", width=150, hint="variable: only within-value dyads vary", smoke=dict(net="und", use=dict(main="grp")))
ctl("fixdensity", "space", "fixdensity", "check", "fixdensity", hint="hold the tie count fixed; method(mcmle)", smoke=dict(net="und", also={"triangle": True, "method": "mcmle", "mcmc_small": True}))
ctl("mcmcprop", "space", "mcmcprop", "edit", "mcmcprop()", width=150, hint="MCMC.prop hint formula, e.g. sparse", smoke=dict(net="und", use=dict(main="sparse")))
ctl("mcmcmaxedges", "space", "mcmcmaxedges", "edit", "mcmcmaxedges()", width=150, hint="stop sampling above this many ties", smoke=dict(net="und", use=dict(main="1000")))
ctl("proposal", "mcmc", "proposal", "combo", "proposal()", choices=["", "uniform", "random", "tnt"], hint="Metropolis-Hastings proposal (default tnt)", smoke=dict(net="und", use=dict(main="uniform")))

# --------------------------------------------------------------------------------------
# ESTIMATION
# --------------------------------------------------------------------------------------
ctl("method", "est", "method", "combo", "method()", choices=["", "mple", "mcmle", "cd"], hint="older spelling of estimate()", smoke=dict(net="und", use=dict(main="mple")))
ctl("estimate", "est", "estimate", "combo", "estimate()", choices=["", "mle", "mple", "cd"], hint="mle (default), mple, cd", smoke=dict(net="und", use=dict(main="mple")))
ctl("mainmethod", "est", "mainmethod", "combo", "mainmethod()", choices=["", "mcmle", "sa"], hint="Monte Carlo algorithm", smoke=dict(net="und", use=dict(main="mcmle"), also={"mcmc_small": True, "triangle": True}))
ctl("mpletype", "est", "mpletype", "combo", "mpletype()", choices=["", "glm", "penalized"], hint="penalized = Firth", smoke=dict(net="und", use=dict(main="penalized"), also={"method": "mple"}))
ctl("mplecheck", "est", "mplecheck", "combo", "mplecheck()", choices=["", "on", "off"], hint="test whether the MPLE exists", smoke=dict(net="und", use=dict(main="off"), also={"method": "mple"}))
ctl("mplecovariance", "est", "mplecovariance", "combo", "mplecovariance()", choices=["", "invhess", "godambe", "bootstrap"], hint="dyad-dependent MPLE", smoke=dict(net="und", use=dict(main="godambe"), also={"method": "mple", "triangle": True}))
ctl("init", "est", "init", "edit", "init()", width=180, hint="one value per coefficient; . leaves one free", smoke=dict(net="und", use=dict(main=". ."), also={"method": "mple", "nodecov": "age"}))
ctl("mcmleiterations", "est", "mcmleiterations", "edit", "mcmleiterations()", width=80, hint="default 60", smoke=dict(net="und", use=dict(main="3"), also={"mcmc_small": True, "triangle": True}))
ctl("mcmleconfidence", "est", "mcmleconfidence", "edit", "mcmleconfidence()", width=80, hint="default 0.99", smoke=dict(net="und", use=dict(main="0.95"), also={"mcmc_small": True, "triangle": True}))
ctl("mcmletermination", "est", "mcmletermination", "combo", "mcmletermination()", choices=["", "confidence", "hummel", "hotelling", "none"], hint="stopping rule", smoke=dict(net="und", use=dict(main="none"), also={"mcmc_small": True, "triangle": True, "seed": "1"}))
ctl("mcmlesteplength", "est", "mcmlesteplength", "edit", "mcmlesteplength()", width=80, hint="default 1", smoke=dict(net="und", use=dict(main="1"), also={"mcmc_small": True, "triangle": True}))
ctl("mcmlestepmargin", "est", "mcmlestepmargin", "edit", "mcmlestepmargin()", width=80, hint="default 0.05; . switches Hummel steps off", smoke=dict(net="und", use=dict(main="0.05"), also={"mcmc_small": True, "triangle": True}))
ctl("mcmleeffectivesize", "est", "mcmleeffectivesize", "edit", "mcmleeffectivesize()", width=80, hint="MCMLE.effectiveSize", smoke=dict(net="und", use=dict(main="50"), also={"mcmc_small": True, "triangle": True}))
ctl("cdnsteps", "mcmc", "cdnsteps", "edit", "cdnsteps()", width=80, hint="contrastive divergence; default 8", smoke=dict(net="und", use=dict(main="8"), also={"estimate": "cd", "triangle": True, "mcmc_small": True}))
ctl("cdsamplesize", "mcmc", "cdsamplesize", "edit", "cdsamplesize()", width=80, hint="CD draws; default 128 per coefficient", smoke=dict(net="und", use=dict(main="100"), also={"estimate": "cd", "triangle": True, "mcmc_small": True}))
ctl("saburnin", "mcmc", "saburnin", "edit", "saburnin()", width=80, hint="stochastic approximation; default 16384", smoke=dict(net="und", use=dict(main="2000"), also={"mainmethod": "sa", "triangle": True}))
ctl("sainterval", "mcmc", "sainterval", "edit", "sainterval()", width=80, hint="default 1024", smoke=dict(net="und", use=dict(main="100"), also={"mainmethod": "sa", "triangle": True}))
ctl("saphase3", "mcmc", "saphase3", "edit", "saphase3()", width=80, hint="default 1000", smoke=dict(net="und", use=dict(main="200"), also={"mainmethod": "sa", "triangle": True}))
ctl("sagain", "mcmc", "sagain", "edit", "sagain()", width=80, hint="initial gain; default 0.1", smoke=dict(net="und", use=dict(main="0.1"), also={"mainmethod": "sa", "triangle": True}))
ctl("sansub", "mcmc", "sansub", "edit", "sansub()", width=80, hint="phase-2 sub-phases; default 4", smoke=dict(net="und", use=dict(main="2"), also={"mainmethod": "sa", "triangle": True}))

# --------------------------------------------------------------------------------------
# MCMC and bridge sampling (also used by nwergm simulate where accepted)
# --------------------------------------------------------------------------------------
ctl("mcmcburnin", "mcmc", "mcmcburnin", "edit", "mcmcburnin()", width=80, hint="default 3000", smoke=dict(net="und", use=dict(main="500"), also={"mcmc_small": True, "triangle": True}))
ctl("mcmcinterval", "mcmc", "mcmcinterval", "edit", "mcmcinterval()", width=80, hint="default 50", smoke=dict(net="und", use=dict(main="20"), also={"mcmc_small": True, "triangle": True}))
ctl("mcmcsamplesize", "mcmc", "mcmcsamplesize", "edit", "mcmcsamplesize()", width=80, hint="default 3000", smoke=dict(net="und", use=dict(main="300"), also={"mcmc_small": True, "triangle": True}))
ctl("seed", "mcmc", "seed", "edit", "seed()", width=80, hint="random-number seed", smoke=dict(net="und", use=dict(main="1234"), also={"method": "mple"}))
ctl("spcache", "mcmc", "spcache", "check", "spcache", hint="shared-partner cache for dense undirected networks", smoke=dict(net="und", also={"method": "mple"}))
ctl("nonative", "mcmc", "nonative", "check", "nonative", hint="force the Mata backend (testing only)", smoke=dict(net="und", also={"method": "mple"}))
ctl("bridgesteps", "out", "bridgesteps", "edit", "bridgesteps()", width=80, hint="bridges for the log-likelihood; default 16", smoke=dict(net="und", use=dict(main="4"), also={"mcmc_small": True, "triangle": True}))
ctl("bridgesamplesize", "out", "bridgesamplesize", "edit", "bridgesamplesize()", width=80, hint="draws per bridge; default mcmcsamplesize()", smoke=dict(net="und", use=dict(main="100"), also={"mcmc_small": True, "triangle": True}))
ctl("bridgeinterval", "out", "bridgeinterval", "edit", "bridgeinterval()", width=80, hint="thinning within bridges", smoke=dict(net="und", use=dict(main="10"), also={"mcmc_small": True, "triangle": True}))
ctl("nologlik", "out", "nologlik", "check", "nologlik", hint="skip the bridge-sampling log-likelihood", smoke=dict(net="und", also={"mcmc_small": True, "triangle": True}))
ctl("nomcmcsample", "out", "nomcmcsample", "check", "nomcmcsample", hint="do not post e(mcmcsample)", smoke=dict(net="und", also={"mcmc_small": True, "triangle": True}))
ctl("verbose", "out", "verbose", "check", "verbose", hint="show iteration detail", smoke=dict(net="und", also={"method": "mple"}))

# --------------------------------------------------------------------------------------
# OUTPUT and offsets
# --------------------------------------------------------------------------------------
ctl("offset", "out", "offset", "edit", "offset()", width=250, hint="coefname # [coefname # ...]: hold coefficients fixed", smoke=dict(net="und", use=dict(main="nodecov_age 0.01"), also={"method": "mple", "nodecov": "age"}))
ctl("coeflabel", "out", "coeflabel", "edit", "coeflabel()", width=250, hint="old new [old new ...]: rename coefficients", smoke=dict(net="und", use=dict(main="edges density"), also={"method": "mple"}))
ctl("logstat", "out", "logstat", "edit", "logstat()", width=250, hint="coefficient names whose statistic is logged [, log0(#)]", smoke=dict(net="und", use=dict(main="nodecov_age"), also={"method": "mple", "nodecov": "age"}))
ctl("expstat", "out", "expstat", "edit", "expstat()", width=250, hint="coefficient names whose statistic is exponentiated", smoke=dict(net="und", use=dict(main="nodecov_age"), also={"method": "mple", "nodecov": "age"}))

# --------------------------------------------------------------------------------------
# SIMULATION (nwergm simulate #nodes, ...): options that exist only there
# --------------------------------------------------------------------------------------
ctl("sim_nodes", "simctl", "__nodes__", "edit", "Number of nodes", width=80, hint="positional argument", smoke=dict(net="none"))
ctl("theta", "simctl", "theta", "edit", "theta()", width=250, hint="one coefficient per model term, in estimation order", smoke=dict(net="none", use=dict(main="-2")))
ctl("nsim", "simctl", "nsim", "edit", "nsim()", width=80, hint="number of networks to draw (default 1)", smoke=dict(net="none", use=dict(main="2")))
ctl("generate", "simctl", "generate", "edit", "generate()", width=120, hint="stub name of the simulated networks", smoke=dict(net="none", use=dict(main="simnet")))
ctl("sim_directed", "simctl", "directed", "check", "directed", hint="simulate a directed network", smoke=dict(net="none"))
ctl("bipartite", "simctl", "bipartite", "edit", "bipartite()", width=80, hint="number of mode-1 nodes (two-mode network)", smoke=dict(net="none", use=dict(main="4")))
ctl("basis", "simctl", "basis", "net", "basis()", width=150, hint="start from (and take constraints from) this network", smoke=dict(net="none", use=dict(main="ucov")))

# --------------------------------------------------------------------------------------
# estat dialog (nwergm_estat.dlg)
# --------------------------------------------------------------------------------------
ESTAT_TABS = [
    dict(key="which", title="Command"),
    dict(key="gof", title="GOF"),
    dict(key="mcmcdiag", title="MCMC"),
    dict(key="ic", title="IC"),
    dict(key="simfit", title="Simulate"),
]
GOF_STATS = ["degree", "idegree", "odegree", "b1degree", "b2degree", "espartners", "dspartners", "distance", "triadcensus", "model"]
# estat controls: (id, tab, option, widget, label, choices, hint, smoke value)
ESTAT = [
    ("g_nsim", "gof", "nsim", "edit", "nsim()", None, "simulated networks; default 100", "20"),
    ("g_seed", "gof", "seed", "edit", "seed()", None, "random-number seed", "7"),
    ("g_burnin", "gof", "gofburnin", "edit", "gofburnin()", None, "default: burn-in of the fit", "500"),
    ("g_interval", "gof", "gofinterval", "edit", "gofinterval()", None, "default: interval of the fit", "20"),
    ("g_maxdeg", "gof", "maxdeg", "edit", "maxdeg()", None, "largest degree plotted; default 15", "10"),
    ("g_maxdist", "gof", "maxdist", "edit", "maxdist()", None, "largest distance plotted; default 6", "5"),
    ("g_name", "gof", "name", "edit", "name()", None, "name of the graph", "gofgr"),
    ("g_plot", "gof", "plot", "check", "plot", None, "draw the comparison graphs", True),
    ("m_pvalue", "mcmcdiag", "pvalue", "combo", "pvalue()", ["", "0.10", "0.05", "0.025", "0.01"], "level of the stationarity test", "0.05"),
    ("m_eps", "mcmcdiag", "eps", "edit", "eps()", None, "half-width tolerance; default 0.1", "0.1"),
    ("m_name", "mcmcdiag", "name", "edit", "name()", None, "name of the combined graph", "mcgr"),
    ("m_plot", "mcmcdiag", "plot", "check", "plot", None, "trace and density plots", True),
    ("s_nsim", "simfit", "nsim", "edit", "nsim()", None, "default 1", "2"),
    ("s_seed", "simfit", "seed", "edit", "seed()", None, "", "3"),
    ("s_output", "simfit", "output", "combo", "output()", ["", "network", "stats", "edgelist"], "what to produce (default network)", "stats"),
    ("s_basis", "simfit", "basis", "net", "basis()", None, "start network (default: last network of the fit)", "und"),
    ("s_coef", "simfit", "coef", "edit", "coef()", None, "name of a Stata matrix with the coefficients", "Bcoef"),
    ("s_nosequential", "simfit", "nosequential", "check", "nosequential", None, "restart every draw from the start network", True),
    ("s_burnin", "simfit", "burnin", "edit", "burnin()", None, "", "200"),
    ("s_interval", "simfit", "interval", "edit", "interval()", None, "", "20"),
    ("s_generate", "simfit", "generate", "edit", "generate()", None, "stub for the simulated networks", "fsim"),
    ("s_clear", "simfit", "clear", "check", "clear", None, "needed with output(edgelist)", True),
]

# --------------------------------------------------------------------------------------
# Coverage declarations used by check_dialogs.py
# --------------------------------------------------------------------------------------
# options of the syntax lines that are deliberately not in the dialogs
EXCLUDED_OPTIONS = {
    "submodel": "internal option used by the operator machinery to build the model of an operator term; never typed by a user",
}
# inventory terms that cannot be selected, by reason (the inventory status is not IMPLEMENTED/PARTIAL)
EXCLUDED_TERM_REASON = {
    "NOT PLANNED": "not planned in nwergm (valued/count ERGM, temporal tergm, ergm.count terms)",
    "NOT IMPLEMENTED": "not implemented in nwergm (multilayer terms of ergm.multi)",
}

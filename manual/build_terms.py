#!/usr/bin/env python3
"""Generates gen_terms.tex (the term reference), gen_notimpl.tex (the terms that nwergm does not implement) and gen_counts.tex
from the inventory of the terms of R's ergm (docs/ERGM_TERMS_INVENTORY.csv, one row per documented term of ergm 4.12.0 and of
the packages built on it).  Usage:  python3 build_terms.py [path to ERGM_TERMS_INVENTORY.csv]

The inventory holds the status and the validation text of every term; this script turns them into LaTeX tables, grouped into
families.  Where the free text of the inventory is out of date or too terse, the dictionaries SYNTAX and REMARK below give the
text from the help files of the package (they are the only place where the table differs from the inventory)."""
import csv, math, os, re, sys, collections

here = os.path.dirname(os.path.abspath(__file__))
src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "docs", "ERGM_TERMS_INVENTORY.csv")
allrows = list(csv.DictReader(open(src, encoding="utf-8")))
rows = [x for x in allrows if x["package"] == "ergm"]
others = [x for x in allrows if x["package"] != "ergm"]
ERGM_VERSION = "4.12.0"


def tex(s):
    s = s or ""
    s = s.replace("\\", "\\textbackslash{}")
    for a, b in (("&", "\\&"), ("%", "\\%"), ("$", "\\$"), ("#", "\\#"), ("_", "\\_"), ("{", "\\{"), ("}", "\\}"), ("~", "\\~{}"), ("^", "\\^{}")):
        s = s.replace(a, b)
    return s.replace("\\textbackslash\\{\\}", "\\textbackslash{}")


def tt(s):
    return "\\opt{" + tex(s) + "}" if s else ""


# ---------------------------------------------------------------- syntax (from the help files)
SYNTAX = {
    "absdiff": "absdist(varlist [, pow(#)])",
    "absdiffcat": "absdiffcat(varlist [, levels() levelvalues() base()])",
    "attrcov": "attrcov(varlist, mat(matname))",
    "b1concurrent": "bconcurrent1(all) | bconcurrent1(by(var) [levels(numlist)])",
    "b2concurrent": "bconcurrent2(all) | bconcurrent2(by(var) [levels(numlist)])",
    "b1covrange": "bcovrange1(varname)", "b2covrange": "bcovrange2(varname)",
    "b1degrange": "bdegrange1(numlist, to(numlist) [by() levels() homophily])",
    "b2degrange": "bdegrange2(numlist, to(numlist) [by() levels() homophily])",
    "b1degree": "bdegree1(numlist [, by() levels() homophily])",
    "b2degree": "bdegree2(numlist [, by() levels() homophily])",
    "b1dsp": "bdsp1(numlist)", "b2dsp": "bdsp2(numlist)",
    "b1factordistinct": "bfactordistinct1(var [, levels()])", "b2factordistinct": "bfactordistinct2(var [, levels()])",
    "b1mindegree": "bmindegree1(numlist)", "b2mindegree": "bmindegree2(numlist)",
    "b1nodematch": "bnodematch1(var [, diff alpha(#) beta(#) byattr(var) keep() levels()])",
    "b2nodematch": "bnodematch2(var [, diff alpha(#) beta(#) byattr(var) keep() levels()])",
    "b1sociality": "bsociality1(numlist)", "b2sociality": "bsociality2(numlist)",
    "b1star": "bstar1(numlist [, attr() levels()])", "b2star": "bstar2(numlist [, attr() levels()])",
    "b1starmix": "bstarmix1(k [, attr(var) nodiff base()])", "b2starmix": "bstarmix2(k [, attr(var) nodiff base()])",
    "b1twostar": "btwostar1(var [, attr2(var) levels1() levels2() levels3() base()])",
    "b2twostar": "btwostar2(var [, attr2(var) levels1() levels2() levels3() base()])",
    "coincidence": "coincidence(all) | coincidence(active(#))",
    "diff": "diff(varlist [, pow() dir() signaction()])",
    "dyadcov": "dyadcov(netname | matname)",
    "edgecov": "edgecov(netname | matname)",
    "mm": "mm(var [, levels() levels2()])",
    "nodecovrange": "nodecovrange(varlist)", "nodeicovrange": "nodeicovrange(varlist)", "nodeocovrange": "nodeocovrange(varlist)",
    "nodefactordistinct": "nodefactordistinct(varlist [, levels() levelvalues()])",
    "nodeifactordistinct": "nodeifactordistinct(varlist [, levels() levelvalues()])",
    "nodeofactordistinct": "nodeofactordistinct(varlist [, levels() levelvalues()])",
    "nodefactor": "nodefactor(varlist [, levels() levelvalues() base()])",
    "nodeofactor": "nodeofactor(varlist [, levels() levelvalues() base()])",
    "nodeifactor": "nodeifactor(varlist [, levels() levelvalues() base()])",
    "nodematch": "nodematch(varlist [, diff keep() levels() levelvalues()]); nodematchdiff(varlist)",
    "nodemix": "nodemix(varlist [, levels() levelvalues() levels2() base()])",
    "smalldiff": "smalldiff(varlist, cutoff(#))",
    "sociality": "sociality(varlist [, nodes() levels()])",
    # structural(): the argument forms of the help file nwergm_structural
    "edges": "edges",
    "gwesp": "gwesp(#); gwespfree(#); type(OTP|ITP|OSP|ISP|RTP)",
    "gwdsp": "gwdsp(#); gwdspfree(#); type()", "gwnsp": "gwnsp(#); gwnspfree(#); type()",
    "gwdegree": "gwdegree(#); gwdegreefree(#)", "gwodegree": "gwodegree(#); gwodegreefree(#)", "gwidegree": "gwidegree(#); gwidegreefree(#)",
    "gwb1degree": "bgwdegree1(# [, attr() levels()]); bgwdegreefree1(#)", "gwb2degree": "bgwdegree2(# [, attr() levels()]); bgwdegreefree2(#)",
    "gwb1dsp": "bgwdsp1(#); bgwdspfree1(#)", "gwb2dsp": "bgwdsp2(#); bgwdspfree2(#)",
    "isolatededges": "structural(isolatededges)",
    "degree1.5": "structural(degree1.5)", "odegree1.5": "structural(odegree1.5)", "idegree1.5": "structural(idegree1.5)",
    "concurrentties": "structural(concurrentties[(by=attr)])",
    "altkstar": "structural(altkstar(lambda=# fixed)); structural(altkstar) with init()",
    "tripercent": "structural(tripercent[(attr=attr [diff])])",
    "asymmetric": "structural(asymmetric[(attr=attr [diff])])",
    "ttriple": "structural(ttriple[(attr=attr [diff])])",
    "cycle": "structural(cycle(k=numlist [semi]))",
    "threetrail": "structural(threetrail[(keep=numlist)])",
    "triadcensus": "structural(triadcensus[(levels=numlist)])",
    "localtriangle": "structural(localtriangle(x=netname))",
    "nsp": "structural(nsp(d=numlist [type=OTP|ITP|OSP|ISP|RTP]))",
    "triangle": "triangle; structural(triangle[(attr=attr [diff])])",
    "ctriple": "ctriple; structural(ctriple[(attr=attr [diff])])",
    "mutual": "mutual; structural(mutual[(same=attr [diff])]), structural(mutual(by=attr))",
    "concurrent": "concurrent; structural(concurrent[(by=attr)])",
    "degree": "degree(numlist); structural(degree(d=numlist [by=attr] [homophily]))",
    "odegree": "odegree(numlist); structural(odegree(d=numlist [by=attr] [homophily]))",
    "idegree": "idegree(numlist); structural(idegree(d=numlist [by=attr] [homophily]))",
    "degrange": "degrange(numlist) degrangeto(numlist); structural(degrange(from=numlist [to=numlist] [by=attr] [homophily]))",
    "odegrange": "odegrange(numlist) odegrangeto(numlist); structural(odegrange(...))",
    "idegrange": "idegrange(numlist) idegrangeto(numlist); structural(idegrange(...))",
    "kstar": "kstar(numlist); structural(kstar(k=numlist [attr=attr]))",
    "ostar": "ostar(numlist); structural(ostar(k=numlist [attr=attr]))",
    "istar": "istar(numlist); structural(istar(k=numlist [attr=attr]))",
}

# remarks: replace the free text of the inventory where that is out of date
REMARK = {
    "absdiff": "R's name is absdiff; the exponent is pow().",
    "b1cov": "", "b2cov": "", "b1factor": "", "b2factor": "",
    "b1degree": "R's by=, levels=, homophily= are suboptions.",
    "b2degree": "R's by=, levels=, homophily= are suboptions.",
    "b1star": "R's attr= and levels= are suboptions.", "b2star": "R's attr= and levels= are suboptions.",
    "edges": "Required in every model, unless density or meandeg (collinear with it) stands in for it.",
    "concurrent": "Undirected networks only.",
    "ctriple": "Directed networks only.",
    "degrange": "Undirected networks only.",
    "degree": "Undirected networks only, as in R.",
    "edgecov": "The covariate is a network in memory (possibly valued) or an n by n Stata matrix.",
    "idegree": "Directed networks only. A level with no node that R reports as -Inf or NA is reported as 0.",
    "kstar": "Undirected networks only.",
    "mutual": "Directed networks only. R's keep= and levels= are not available.",
    "nodefactor": "The lowest level is omitted (R's default base=1).",
    "nodeofactor": "Directed networks only.", "nodeifactor": "Directed networks only.",
    "nodematch": "Exact match on a numeric variable (encode strings first); one coefficient per variable, or per level with diff.",
    "odegree": "Directed networks only.",
    "gwesp": "R's default is fixed=FALSE; in nwergm gwesp() has a fixed decay and gwespfree() estimates it. RTP agrees with R 4.12.0 only when R is run with cache.sp=FALSE (a defect of that release). R's cutoff= is not available. The curved fit on a boundary solution (decay near 0) can end elsewhere than R.",
    "gwdsp": "Fixed decay gwdsp(), curved gwdspfree(). The curved fit on a boundary solution can end elsewhere than R.",
    "gwnsp": "Fixed decay gwnsp(), curved gwnspfree(). The curved fit on a boundary solution can end elsewhere than R.",
    "gwdegree": "Fixed decay gwdegree(), curved gwdegreefree() (undirected). nwergm also accepts gwdegree() on a directed network, which R refuses.",
    "gwidegree": "Directed networks only. Fixed decay gwidegree(), curved gwidegreefree(). The curved fit on a boundary solution can end elsewhere than R.",
    "gwodegree": "Directed networks only. Fixed decay gwodegree(), curved gwodegreefree().",
    "gwb1dsp": "Fixed decay bgwdsp1(), curved bgwdspfree1().", "gwb2dsp": "Fixed decay bgwdsp2(), curved bgwdspfree2().",
    "gwb1degree": "Fixed decay bgwdegree1(), curved bgwdegreefree1().", "gwb2degree": "Fixed decay bgwdegree2(), curved bgwdegreefree2().",
    "opentriad": "In ergm 4.12.0 the change statistic for removing a tie overflows an unsigned integer, so R's estimation with this term is wrong although its summary() is right; nwergm uses the correct change statistic.",
}
FORCE_DEP = {"cycle": "DD", "gwb1dsp": "DD", "gwb2dsp": "DD"}  # the inventory records R's answer for an example call; these terms are dyad-dependent

# ---------------------------------------------------------------- validation text
VAL = {}
names = {x["term"] for x in rows}
for line in open(os.path.join(os.path.dirname(src), "VALIDATED_AGAINST_R.md"), encoding="utf-8"):
    m = re.match(r"^\* ([A-Za-z][\w.]*)(?:\(.*?\))?(?: \([^|]*\))? \| IMPLEMENTED \|.*?\| summary\(\) (?:max \|diff\| ([\d.e+-]+)|equal)(?: on (\d+) nets)?(?:; MPLE coef diff ([\d.e+-]+))?", line)
    if m and m.group(1) in names:
        a = VAL.setdefault(m.group(1), {"s": 0.0, "m": 0.0})
        if m.group(2): a["s"] = max(a["s"], float(m.group(2)))
        if m.group(4): a["m"] = max(a["m"], float(m.group(4)))

MCMLE_STRUCT = {"degree1.5", "altkstar", "cycle", "triangle", "transitive", "m2star", "ttriple", "odegree1.5"}  # one or more MCMLE models checked in several seeds
MCMLE_BIP = {"b1concurrent", "b2concurrent", "b1dsp", "b2dsp", "b1degrange", "b2degrange", "b1degree", "b2degree", "b1star", "b2star", "b1nodematch", "b2nodematch", "b1starmix", "b2starmix", "b1covrange", "b2covrange", "b1factordistinct", "b2factordistinct", "b1sociality", "b2sociality", "b1twostar", "b2twostar"}
MCMLE_BIPCURVED = {"gwb1degree", "gwb2degree"}


def pw(x):
    """a power of ten that bounds x from above, as LaTeX"""
    if x <= 0: return "0"
    e = math.ceil(math.log10(x) - 1e-9)
    return "$10^{%d}$" % e


# comparisons that were run for the manual (ex/ex9e_extra_terms.do, ex/r/extra.R) for terms whose inventory entry has no comparison with R
EXTRA = {}
try:
    _S = collections.defaultdict(lambda: {"coef": [], "obs": []}); _R = collections.defaultdict(lambda: {"coef": [], "obs": []})
    for x in csv.DictReader(open(os.path.join(here, "ex", "r", "stata_extra.csv"))): _S[x["fit"]][x["kind"]].append(float(x["value"]))
    for x in csv.DictReader(open(os.path.join(here, "ex", "r", "r_extra.csv"))): _R[x["fit"]][x["kind"]].append(float(x["value"]))
    for k in _S:
        EXTRA[re.match(r"[a-z]+", k).group(0)] = (max(abs(a - b) for a, b in zip(_S[k]["obs"], _R[k]["obs"])), max(abs(a - b) for a, b in zip(_S[k]["coef"], _R[k]["coef"])))
except IOError:
    pass


def validation(x):
    t, v = x["term"], x["validated_against_ergm"]
    if t in EXTRA and v.startswith("n/a") and x["nwergm_status"] in ("IMPLEMENTED", "PARTIAL"):
        so, mc = EXTRA[t]
        return "statistic equals R's%s; MPLE to %s (compared for this manual)" % (" (to %s)" % pw(so) if so >= 1e-9 else "", pw(max(mc, 1e-12)))
    if x["nwergm_status"] not in ("IMPLEMENTED", "PARTIAL"): return ""
    if t == "opentriad": return "statistic equals R's; estimation deliberately differs (see remark)"
    if t == "localtriangle": return "statistic equals R's on two networks"
    if t == "Curve": return "statistics, MPLE (to $10^{-9}$), MCMLE"
    if v.startswith("yes | R ergm 4.12.0: observed statistics (summary), MPLE"): return "statistics, MPLE and MCMLE (several models)"
    if "test_nwergm_balance" in v: return "statistics, MPLE and MCMLE"
    if "test_nwergm_bipcurved" in v: return "MPLE to $10^{-6}$" if "dsp" in t else "MPLE to $10^{-6}$; MCMLE within noise"
    if "test_nwergm_altkstar" in v: return "fixed form: statistic and MPLE; curved form: map, gradient and MPLE from given starting values (to $10^{-5}$)"
    parts = []
    if t in VAL:
        a = VAL[t]
        parts.append("statistic equals R's" + (" (to %s)" % pw(a["s"]) if a["s"] >= 1e-9 else ""))
        parts.append("MPLE to %s" % pw(max(a["m"], 1e-12)))
        if t in MCMLE_STRUCT: parts.append("MCMLE within noise")
        return "; ".join(parts)
    if "test_nwergm_covterms" in v:
        return "statistic equals R's; MPLE to $10^{-4}$"
    if "agent check" in v:
        items = re.findall(r"(\w+): (match|close|DIFFERS|coef count differs)[^;|]*?(?:\(max \|dcoef\|=([\d.e+-]+)\))?\s*(?:;|\||$)", v)
        good = [float(z[2]) for z in items if z[1] in ("match", "close") and z[2]]
        d = max(good) if good else 0
        bad = any(z[1] in ("DIFFERS", "coef count differs") for z in items) or "count differs" in v
        s_ = []
        if "test_nwergm_statistics" in v: s_.append("statistic equals R's")
        s_.append("MPLE to %s" % pw(d) + (" except the cases named in the remark" if bad else ""))
        if "test_nwergm_mcmle" in v: s_.append("MCMLE within noise")
        return "; ".join(s_)
    if t in MCMLE_BIP or "test_nwergm_bip" in v:
        s = ["statistic and change statistics equal R's", "MPLE to $10^{-4}$"]
        if t in MCMLE_BIP: s.append("MCMLE within noise")
        return "; ".join(s)
    if v.startswith("repo tests"):
        return "compared with R in the test suite"
    return ""


# ---------------------------------------------------------------- families
def family(x):
    t, c = x["term"], x["category"]
    if c == "operator": return "ops"
    if re.match(r"^(b[12]|gwb[12])", t) or t == "coincidence": return "two"
    if c.startswith("structural: curved"): return "curved"
    if c.startswith("covariate"): return "cov"
    if c == "structural: dyad-level / density": return "dyad"
    if c == "structural: degree / stars": return "deg"
    if c in ("structural: shared partners", "structural: triads / cycles / paths"): return "tri"
    return "other"


FAM = collections.OrderedDict([
    ("dyad", ("Dyad-level and basic terms", "Terms of single dyads and of the whole network: density, reciprocity, Hamming distance to another network.")),
    ("deg", ("Degree and star terms", "Terms of the degree distribution of the nodes and of the stars centred on them.")),
    ("tri", ("Triad, cycle, path and shared-partner terms", "Terms of triangles, cycles, two-paths and shared partners.")),
    ("curved", ("Curved terms: geometrically weighted and alternating statistics", "Terms with a decay parameter. The fixed-decay form (decay as a number in the option) is an ordinary term; the form with an estimated decay (option names ending in \\texttt{free}) is a curved exponential family and reports a weight and a decay.")),
    ("cov", ("Covariate terms", "Terms of node attributes and of dyadic covariates.")),
    ("two", ("Two-mode (bipartite) terms", "Terms for two-mode networks. R's mode digit moves to the end of the option name (\\texttt{b1degree} is \\texttt{bdegree1()}).")),
    ("ops", ("Operators", "Operators build a term from other terms or from a derived network; they are written inside \\opt{operators()} (Section~\\ref{sec:operators}).")),
])

TYPE = {"undirected": "u", "directed": "d", "bipartite": "b"}


def types(x):
    t, n = x["term"], x["notes"]
    s = x["network_types_R_tested"] or x["nwergm_network_types_tested"]
    L = [TYPE[k] for k in s.split(",") if k in TYPE]
    if family(x) == "two": return "b"
    if "Directed only" in n and t not in ("cyclicalties", "transitiveties"): L = ["d"]
    if t in ("cyclicalties", "transitiveties"): L = ["d"]
    if t == "mutual": L = ["d"]
    if t in ("degree", "kstar", "concurrent", "degrange", "isolates", "concurrentties"): L = [k for k in L if k != "d"]
    return " ".join(L)


def dep(x):
    t = x["term"]
    if x["category"] == "operator": return "op."
    if t in FORCE_DEP: return "DD"
    c = x["R_dyad_class"]
    if c == "dyad-independent": return "DI"
    if c.startswith("dyad-dependent (curved"): return "curved"
    if c == "dyad-dependent": return "DD"
    return "--"


def remark(x):
    t = x["term"]
    if t in REMARK: return REMARK[t]
    n = x["notes"]
    n = re.sub(r"\s*Stata option names avoid digit-letter sequence\.", "", n)
    n = re.sub(r"\s*R's (by|attr|levels|keep|same|diff|pow)=[^.]*not supported\.", "", n)
    n = n.replace("(see CSV notes)", "")
    return n.strip()


def status(x):
    return {"IMPLEMENTED": "", "PARTIAL": "partial"}.get(x["nwergm_status"], x["nwergm_status"].lower())


impl = [x for x in rows if x["nwergm_status"] in ("IMPLEMENTED", "PARTIAL")]
cnt = collections.Counter(x["nwergm_status"] for x in rows)
valued = [x for x in rows if x["category"] == "valued only"]  # the 13 terms that ergm itself refuses on a binary network (B, the wrapper, is an operator)
nvalued = len(valued)
ncovered = cnt["IMPLEMENTED"] + cnt["PARTIAL"]
nbinary = len(rows) - nvalued
with open(os.path.join(here, "gen_counts.tex"), "w") as f:
    f.write("\\newcommand{\\ergmver}{%s}\\newcommand{\\nErgm}{%d}\\newcommand{\\nImpl}{%d}\\newcommand{\\nPartial}{%d}\\newcommand{\\nCovered}{%d}"
            "\\newcommand{\\nNotPlanned}{%d}\\newcommand{\\nValued}{%d}\\newcommand{\\nBinary}{%d}\\newcommand{\\pctCovered}{%.1f}"
            "\\newcommand{\\nOther}{%d}\\newcommand{\\nTergm}{%d}\\newcommand{\\nMulti}{%d}\\newcommand{\\nCount}{%d}\\newcommand{\\nAllDoc}{%d}\n"
            % (ERGM_VERSION, len(rows), cnt["IMPLEMENTED"], cnt["PARTIAL"], ncovered, cnt["NOT PLANNED"] + cnt["NOT IMPLEMENTED"], nvalued, nbinary,
               100.0 * ncovered / len(rows), len(others), sum(1 for x in others if x["package"] == "tergm"),
               sum(1 for x in others if x["package"] == "ergm.multi"), sum(1 for x in others if x["package"] == "ergm.count"), len(allrows)))

# ---------------------------------------------------------------- the reference tables
fams = collections.OrderedDict((k, []) for k in FAM)
for x in impl:
    k = family(x)
    fams.setdefault(k, []).append(x)
with open(os.path.join(here, "gen_terms.tex"), "w") as f:
    for k, (title, intro) in FAM.items():
        xs = sorted(fams.get(k, []), key=lambda z: z["term"].lower())
        if not xs: continue
        f.write("\\section{%s}\\label{sec:terms-%s}\n%s (%d terms)\n\n" % (tex(title).replace("\\textbackslash{}", "\\"), k, intro, len(xs)))
        f.write("\\footnotesize\n\\begin{longtable}{@{}>{\\raggedright\\arraybackslash}p{3.3cm}>{\\raggedright\\arraybackslash}p{5.4cm}>{\\raggedright\\arraybackslash}p{1.4cm}>{\\raggedright\\arraybackslash}p{4.0cm}@{}}\n")
        f.write("\\toprule\nergm term & nwergm syntax and remarks & Types, class & Validation against ergm \\\\\n\\midrule\n\\endfirsthead\n")
        f.write("\\toprule\nergm term & nwergm syntax and remarks & Types, class & Validation against ergm \\\\\n\\midrule\n\\endhead\n")
        f.write("\\bottomrule\n\\endfoot\n")
        for x in xs:
            t = x["term"]
            syn = SYNTAX.get(t) or x["nwergm_syntax"]
            if syn.startswith("operators("): syn = syn
            parts = [p.strip() for p in re.split(r";\s+(?=[a-z])", syn)] if k != "ops" else [syn]
            cell = "\\newline ".join(tt(p) for p in parts)
            rm = remark(x)
            if status(x) == "partial": cell += "\\newline {\\itshape partial.} "
            elif rm: cell += "\\newline "
            if rm: cell += tex(rm)
            ty = (types(x) or "--") + ", " + dep(x)
            f.write("%s & %s & %s & %s\\\\\\addlinespace[3pt]\n" % (tt(t), cell, tex(ty), validation(x)))
        f.write("\\end{longtable}\n\\normalsize\n\n")

# ---------------------------------------------------------------- not implemented
def why(x):
    if x["category"] == "valued only": return "term for valued networks (ergm.count framework); nwergm models binary ties only"
    if x["term"] == "B": return "wraps binary terms for use in a valued model"
    return x["notes"]


nots = [x for x in rows if x["nwergm_status"] not in ("IMPLEMENTED", "PARTIAL")]
with open(os.path.join(here, "gen_notimpl.tex"), "w") as f:
    f.write("\\footnotesize\n\\begin{longtable}{@{}>{\\raggedright\\arraybackslash}p{3.0cm}>{\\raggedright\\arraybackslash}p{5.2cm}>{\\raggedright\\arraybackslash}p{6.7cm}@{}}\n")
    f.write("\\toprule\nergm term & What it does in ergm & Why nwergm has no counterpart\\\\\n\\midrule\n\\endhead\n\\bottomrule\n\\endfoot\n")
    for x in sorted(nots, key=lambda z: z["term"].lower()):
        f.write("%s & %s & %s\\\\\n" % (tt(x["term"]), tex(x["description"].replace("\n", " ")), tex(why(x))))
    f.write("\\end{longtable}\n\\normalsize\n")
with open(os.path.join(here, "gen_other.tex"), "w") as f:
    f.write("\\footnotesize\n\\begin{longtable}{@{}>{\\raggedright\\arraybackslash}p{3.2cm}>{\\raggedright\\arraybackslash}p{2.0cm}>{\\raggedright\\arraybackslash}p{9.6cm}@{}}\n")
    f.write("\\toprule\nTerm & Package & What it does\\\\\n\\midrule\n\\endhead\n\\bottomrule\n\\endfoot\n")
    for x in sorted(others, key=lambda z: (z["package"], z["term"].lower())):
        f.write("%s & %s & %s\\\\\n" % (tt(x["term"]), tex(x["package"]), tex(x["description"])))
    f.write("\\end{longtable}\n\\normalsize\n")
print("ergm terms %d: implemented %d, partial %d, not implemented %d; other packages %d" % (len(rows), cnt["IMPLEMENTED"], cnt["PARTIAL"], len(nots), len(others)))
print({k: len(v) for k, v in fams.items()})

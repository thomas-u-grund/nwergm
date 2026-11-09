# Run after gen_logs.do. The report of R's mcmc.diagnostics() that estat mcmcdiag prints after the numerical
# summary is long; the article shows only the first part of lazega_diag.log.tex and says so in the text.
p = "lazega_diag.log.tex"
lines = open(p).read().split("\n")
cut = None
for i, l in enumerate(lines):
    if l.startswith("Sample statistics summary"):
        cut = i
        break
if cut is not None:
    # drop the preceding {\smallskip} marker too
    while cut > 0 and lines[cut - 1].strip() in ("{\\smallskip}", ""):
        cut -= 1
    lines = lines[:cut] + ["{\\smallskip}", "(output of the R-style report of mcmc.diagnostics() omitted)"]
    open(p, "w").write("\n".join(lines) + "\n")
    print("trimmed", p, "to", len(lines), "lines")

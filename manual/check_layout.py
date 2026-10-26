#!/usr/bin/env python3
"""Checks the built manual: undefined references and citations, overfull boxes (with the chapter file in which they occur) and glued words in the text of the PDF
(a closing parenthesis directly followed by four or more lowercase letters, the symptom of two table columns running into each other).
Usage: python3 check_layout.py [min overfull in points, default 1]   (run in manual/ after the build)"""
import re, subprocess, sys, os
here = os.path.dirname(os.path.abspath(__file__))
lim = float(sys.argv[1]) if len(sys.argv) > 1 else 1.0
log = open(os.path.join(here, "nwergm_manual.log"), errors="replace").read().split("\n")
bad = 0
cur = "?"
for i, l in enumerate(log):
    if l.startswith(">>>"): cur = l[3:]
    m = re.match(r"Overfull \\hbox \(([\d.]+)pt too wide\)(.*)", l)
    if m and float(m.group(1)) >= lim:
        bad += 1
        print("overfull %spt in %s %s | %s" % (m.group(1), cur, m.group(2).strip(), " ".join(x.strip() for x in log[i + 1:i + 3])[:120]))
    if re.search(r"undefined|Citation .* undefined|Reference .* undefined|Label\(s\) may have changed|There were undefined", l):
        bad += 1
        print("log:", l)
txt = subprocess.run(["pdftotext", "-layout", os.path.join(here, "nwergm_manual.pdf"), "-"], capture_output=True, text=True).stdout
for n, line in enumerate(txt.split("\n")):
    for m in re.finditer(r"\)[a-z]{4,}", line):
        if line[m.start() - 1:m.start()] in ("", " "): continue
        if line[max(0, m.start() - 6):m.start() + 1] == "pseudo)": continue  # "(pseudo)likelihood"
        bad += 1
        print("glued word on a line of the PDF text:", line.strip()[:120])
        break
pages = re.search(r"Output written on .*\((\d+) pages", "\n".join(log))
print("pages:", pages.group(1) if pages else "?", "  problems:", bad)
sys.exit(1 if bad else 0)

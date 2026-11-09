#!/usr/bin/env python3
"""Cuts the Stata logs of the example do-files into the listings that the manual includes.
A do-file marks a piece with a line  *# name ; the log text between that marker and the next one is written to out/name.txt."""
import glob, os, re
here = os.path.dirname(os.path.abspath(__file__))
os.makedirs(os.path.join(here, "out"), exist_ok=True)
n = 0
for log in sorted(glob.glob(os.path.join(here, "ex*.log"))):
    cur, buf = None, []
    def flush():
        global n
        if cur and cur != "end":
            while buf and not buf[0].strip(): buf.pop(0)
            while buf and not buf[-1].strip(): buf.pop()
            with open(os.path.join(here, "out", cur + ".txt"), "w") as f:
                f.write("\n".join(buf) + "\n")
            n += 1
    for line in open(log, encoding="utf-8", errors="replace").read().split("\n"):
        m = re.match(r"^\. \*# (\w+)\s*$", line)
        if m:
            flush(); cur, buf = m.group(1), []
            continue
        if line.startswith("end of do-file") or line.startswith("r(") and False: continue
        buf.append(line)
    flush()
# the examples are run from a scratch checkout; show the usual place of an installed package where a listing prints a path
PLUGIN = "~/Library/Application Support/Stata/ado/plus/e/"
for f in glob.glob(os.path.join(here, "out", "*.txt")):
    t = open(f).read()
    t2 = re.sub(r"file\n\s+/[^\n]*\n\s+> [^\n]*?/manual/ex/(\.\./fig/\S+) saved as", r"file \1 saved as", t)
    if t2 != t: open(f, "w").write(t2)
fv = os.path.join(here, "out", "flo_version.txt")
if os.path.exists(fv):
    t = open(fv).read()
    t = re.sub(r"/private/tmp/[^\n]*\n> [^ ]*/lib/plugins/macos/", PLUGIN, t)
    t = t.replace("(ships with the package, no separate version number)", "(ships with \n> the package, no separate version number)")
    t = t.replace("(ships with the package, no separate version n\n> umber)", "(ships with \n> the package, no separate version number)")
    t = re.sub(r'r\(plugin\) : "/private/tmp/[^"]*"', 'r(plugin) : "' + PLUGIN + 'ergm_mcmc_macos.plugin (ships wit.."', t)
    open(fv, "w").write(t)
print("listings written:", n)

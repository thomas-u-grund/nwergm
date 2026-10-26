# Update of the manual to the 1.2 series (26 October 2026)

Starting point: the manual for 1.2.0 (99 pages, branch manual3). Result: "Manual for version 1.2", 101 pages, built with nwergm 1.2.3, nwcommands 3.9.1, Stata/BE 18 (macOS, native plugin), ergm 4.12.0 (R side re-run).

## What changed in the text
- Label: the manual is labelled by the series (`\manualseries` = 1.2: title page, citation, ch. 1 "How to cite", `ZENODO.md`). `\pkgversion` (1.2.3) and `\pkgdate` keep the exact version of the listings ("examples produced with nwergm 1.2.3"). `tools/set_version.py` still writes the last two.
- DOI: `\manualdoi` = 10.5281/zenodo.23661332, given by the owner. UNCONFIRMED: it may be the version DOI and not the all-versions DOI (the record is unpublished, the API answers 404). After publication send the "Cite all versions" DOI, replace `\manualdoi`, rebuild. Not entered in CITATION.cff or the website.
- Installation (ch. 1): `net install nwcommands, from(https://nwcommands.org/net/) replace`, `nwinstall, all`, `nwinstall, modelpkg(nwergm)`, `nwinstall, everything`; core 3.6.0 or later; Stata 17 or later, tested 17 and 18, older versions not claimed (the "Stata 14" sentence and the Stata 16 remark are gone); tag example v1.2.3; new paragraph "Changes within the series 1.2" (1.2.1, 1.2.2, 1.2.3).
- Network types (ch. 3, ch. 1, ch. 10): valued networks are no longer "rejected": fitted as the binary graph (tie = value not zero) with one note, no note when all values are 1; type flag fixed at creation (binary, valued, two-mode); `edgecov()` with a two-mode covariate network (only cells between the modes). New section in ch. 8 ("Network types") with new example `ex/ex0a_types.do` (listings typ_*). Temporal networks are still refused.
- Not added, because nothing in the manual shows them: nwplot defaults, nwdegree/nwclustering/nwmotifs two-mode dispatch, nw2motifs.
- Unchanged on purpose: the AI-disclosure paragraph; no internal files or protocol numbers are cited.

## Numbers: old (1.2.0, core 3.5.0) -> new (1.2.3, core 3.9.1)
- All seeded Stata listings (Florentine, Mesa, Lazega, Kapferer, missing dyads, constraints, two-mode) are identical to the 1.2.0 listings except the version strings (`e(version)`, `nwergm version`). Prose that cites them needed no change. The R comparison tables (observed statistics, MPLE, MCMLE, sampler, extra terms) are numerically identical (max MPLE coefficient difference 4e-8, max MCMLE difference 0.07 standard errors).
- Figures `fig/gof.pdf` and `fig/mcmcdiag.pdf` were regenerated (the checked-in `gr_mcmc` listing had been left from an older run with burn-in 20000; the figures now show the 16384/1024 chain, ESS 291 to 372 as the text says).
- Run times (machine load average 6 to 9, other jobs running; indications only):
  - Lazega, five seeds, median: nwergm default 13.5 s -> 11.4 s; old settings 1.2 -> 1.1 s; Mata sampler 1103 -> 973 s; R ergm 17.3 -> 11.1 s (5.8 to 17.0).
  - Random networks, MPLE: n=200 0.2 -> 0.1; 500 0.2 -> 0.2; 1000 1.0 -> 0.6; 2000 4.3 -> 2.6; 4000 19.2 -> 11.1; 8000 86.3 -> 47.4 s.
  - Random networks, MCMLE with gwesp: 200 2.8 -> 1.8; 500 3.5 -> 2.1; 1000 6.4 -> 3.4; 2000 16.8 -> 8.5; 5000 98.5 -> 52.0; 10000 286.0 -> 160.3 s.
  - `bd(maxout=30)` on Lazega 373 -> 191 s, unconstrained 1.4 -> 0.8 s.
  - Faster partly because of a less loaded machine; do not read it as a speed-up of the software.

## Decisions for the owner
1. Where the manual lives: it is on no public branch yet. Recommend `manual/` on `main` of nwergm (as the nwsaom manual); this branch (`manual4`, from origin/main 1.2.3, merged with manual3) can be merged to `main` as is (Makefile, sources, examples, PDF added with `git add -f`).
2. Zenodo: the record is the first for nwergm, so this is the first upload; steps in `ZENODO.md`. License mirrored from the nwsaom record: CC-BY-4.0, type Publication / Software documentation. The nwsaom record has an ORCID for the creator; none is entered here as instructed. Decide whether to add it.
3. DOI: confirm version vs all-versions DOI (see above); then CITATION.cff, NOTICE.md, README, website (list in `ZENODO.md`) and the master RELEASING.md B.10 sentence "nwergm manual (97 pages) waits for its own Zenodo record".
4. Stale text found but not part of the manual: the section "Limitations" of `nwergm.sthlp` still says that valued networks are rejected with an error (contradicts 1.2.3 and the same file's section "Supported network types"); worth a patch with the next release.
5. Patch releases of 1.2.x need no upload; the next Zenodo version is for 1.3 or 2.0 with changed documented behaviour.

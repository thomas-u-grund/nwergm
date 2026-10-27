# Zenodo record for the nwergm manual

Metadata ready to paste into a new Zenodo upload. Nothing has been uploaded.

**DOI (unconfirmed).** The owner reserved 10.5281/zenodo.23661332 for this manual; it is printed on the title page and in the citation (`\manualdoi` in `nwergm_manual.tex`). It is not known whether this is the version DOI of the first version or the all-versions ("Cite all versions") DOI, and the record is not yet published (the Zenodo API answers 404). The citation text must use the all-versions DOI (master RELEASING.md B.10). After publication, send the all-versions DOI to the maintainer, replace `\manualdoi`, rebuild and replace the PDF in the record if it differs.

**Labelling.** The manual is labelled by the minor series ("Manual for version 1.3", valid for 1.3.x). The package version it was built with (1.3.0) is the exact version of the examples. The Zenodo version field below holds 1.3.0 and is explained there as the series label: the record is the manual of the series 1.3, and a patch release of the package (1.3.1, ...) does not get a new record or version.

**Patch releases.** The manual of the series 1.3 holds for 1.3.x; a patch release changes no documented option or number. The label stays "Manual for version 1.3"; no new Zenodo version is needed for a patch.

## Metadata

**Title.** nwergm: Exponential random graph models in Stata. Manual for version 1.3

**Version.** 1.3.0 (the series label: the manual describes the series 1.3 of nwergm, and 1.3.0 is the first release of the series, the version the examples were produced with; it holds for all versions 1.3.x)

**Publication date.** 2026-10-26 (or the day of the upload)

**Authors.** Grund, Thomas U. (RWTH Aachen University), ORCID 0000-0001-6751-5429 (as on the nwsaom record; remove it in the form if the author does not want it).

**Description** (plain text, one paragraph):

> This is the user manual and reference of nwergm, series 1.3 (examples produced with version 1.3.0 and the nwcommands core 3.10.0), a Stata package for exponential random graph models (ERGMs) of a single binary network. nwergm builds on the nwcommands core package and follows the R package ergm (statnet project), version 4.12.0, in its model, the names of its terms and its estimation algorithms. The manual explains the model and the estimators (maximum pseudolikelihood, Monte Carlo maximum likelihood, contrastive divergence, stochastic approximation), gives the syntax of every option, lists the terms of ergm with the status of each in nwergm, describes goodness of fit and Markov chain diagnostics, documents that the Monte Carlo sampling of the default fit follows ergm (interval and burn-in as in ergm, an adaptive sample size with a target effective sample size of 64, ergm's convergence test, and compiled sampling kernels, which make nwergm faster than ergm on the benchmark models of the manual), explains how the type of a network (binary, valued, two-mode) is handled, shows worked examples with output, compares the results with ergm, states the limits of the package, and gives a translation table from ergm to nwergm. The do-files that produce every listing are in the repository. The package and the manual were prepared with the help of an AI coding assistant working under the author's direction, as stated in the manual.

**License.** Creative Commons Attribution 4.0 International (CC-BY-4.0), as on the nwsaom manual record (the record there) (checked read-only on zenodo.org, record 23626696 of the concept DOI 10.5281/zenodo.23623807, 2026-10-26; resource type there: Publication, sub-type Software documentation). The code stays under GPL-3.0-only.

**Resource type.** Publication, sub-type Software documentation (as the nwsaom record; this replaces the earlier proposal "Other").

**Creators.** As on the nwsaom record, with the ORCID (see Authors).

**Keywords.** Stata; nwcommands; nwergm; exponential random graph model; ERGM; social network analysis; statistical network models; Monte Carlo maximum likelihood; pseudolikelihood; ergm; statnet

**Language.** English

**Related identifiers.** (relation, identifier, type)

| Relation | Identifier | Type |
|---|---|---|
| Is supplement to | https://github.com/thomas-u-grund/nwergm/releases/tag/v1.3.0 | URL |
| Is supplement to | https://github.com/thomas-u-grund/nwergm | URL |
| Requires | https://github.com/thomas-u-grund/nwcommands | URL |
| Is related to (the manual of the sibling package) | 10.5281/zenodo.23623807 | DOI |

Confirm that the GitHub release v1.3.0 is published before the upload, because the first related identifier points to it. The nwsaom link is optional; it is sensible because both manuals describe packages of the same family.

**Other fields.** Funding: none. Communities: none. Access: open.

## Steps for the owner

0. This file describes the manual for the series 1.3 (the first manual of nwergm on Zenodo). The listings, comparison tables and run times were regenerated with nwergm 1.3.0 and nwcommands 3.10.0. The run-time tables were remeasured on 27 October 2026 on an idle machine (R and nwergm in turn, median of seven fits): nwergm is 2.9 to 9.4 times faster than ergm 4.12.0 on the eight benchmark models; the description above carries no timing numbers and needs no change.
1. For a later patch release (1.3.1, ...) nothing is uploaded: only `\pkgversion` and `\pkgdate` change (`tools/set_version.py`), the examples are rerun if their output changes, and the PDF is committed. A new Zenodo version only for 1.4 or 2.0 with changed documented behaviour: then change `\manualseries` too.
2. On zenodo.org upload `manual/nwergm_manual.pdf` to the reserved record (DOI above), fill the fields above, and publish.
3. Send the all-versions DOI to the maintainer (or put it into `\manualdoi`), rebuild, and replace the file in the draft if the DOI changed the PDF.
4. Commit the rebuilt PDF (`git add -f manual/nwergm_manual.pdf`) on the branch that carries the manual.

## Suggested edits after the DOI exists (not made)

Replace NNNNNNN by the DOI.

1. `README.md` (repository), section Manual: add "Archived at Zenodo: https://doi.org/10.5281/zenodo.NNNNNNN". The PDF now has 104 pages; "about 100 pages" in the README is still right.
2. `CITATION.cff`: add a `preferred-citation` as in nwsaom: type manual, title "nwergm: Exponential random graph models in Stata. Manual for version 1.3", author Grund, Thomas U., year 2026, publisher Zenodo, doi 10.5281/zenodo.NNNNNNN.
3. `NOTICE.md`, section How to cite: add the line "Grund, T. U. (2026). nwergm: Exponential random graph models in Stata. Manual for version 1.3. Zenodo. https://doi.org/10.5281/zenodo.NNNNNNN".
4. Website `nwergm/citation.md`: replace "There is no archived record with a DOI yet." by a sentence giving the manual's citation and the DOI, and change the block quote to the manual citation as above; the example "nwergm 1.1.1" and the text "(version 1.1.1)" become the current version (1.3.0).
5. Website `citing.md`: nwergm leaves the list "nwergm, nwdynam and nwrem. These have no DOI" and gets its own entry with the manual citation, as nwsaom has; the version in the nwergm entry becomes 1.3.0.
6. Website `index.md` (packages table) and `nwergm/index.md` (Version row): 1.1.1 becomes 1.3.0; add the "Manual" menu entry for nwergm (a copy of `website/nwsaom/manual.md` with the nwergm DOI, `nav_order` 10, permalink `/nwergm/manual/`); `news.md`: a dated entry "nwergm manual archived at Zenodo".
7. Website pages that give the term counts: check for "125 of 139" (confirmed for ergm 4.12.0).

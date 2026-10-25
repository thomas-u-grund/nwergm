# Zenodo record for the nwergm manual

Metadata ready to paste into a new Zenodo upload. Nothing has been uploaded.

## Metadata

**Resource type.** Publication, sub-type "Other" (the same as the nwsaom manual record if that record uses another type: copy its type). Zenodo has no "software documentation" type for publications.

**Title.** nwergm: Exponential random graph models in Stata. Manual for version 1.1.3

**Version.** 1.1.3

**Publication date.** 2026-10-25 (or the day of the upload)

**Authors.** Grund, Thomas U. (RWTH Aachen University). No ORCID: `CITATION.cff` of the repository does not give one. Add it in the Zenodo form if the author wants it.

**Description** (plain text, one paragraph):

> This is the user manual and reference of nwergm version 1.1.3, a Stata package for exponential random graph models (ERGMs) of a single binary network. nwergm builds on the nwcommands core package and follows the R package ergm (statnet project), version 4.12.0, in its model, the names of its terms and its estimation algorithms. The manual explains the model and the estimators (maximum pseudolikelihood, Monte Carlo maximum likelihood, contrastive divergence, stochastic approximation), gives the syntax of every option, lists the terms of ergm with the status of each in nwergm, describes goodness of fit and Markov chain diagnostics, shows worked examples with output, compares the results with ergm, states the limits of the package, and gives a translation table from ergm to nwergm. The do-files that produce every listing are in the repository. The package and the manual were prepared with the help of an AI coding assistant working under the author's direction, as stated in the manual.

**License.** Proposed: Creative Commons Attribution 4.0 International (CC-BY-4.0) for the manual. The repositories give no license for the nwsaom manual record (the CITATION.cff and NOTICE.md of nwsaom state only GPL-3.0 for the code), so I could not mirror it: open the nwsaom record 10.5281/zenodo.23623807 and use the same license field for this record. The code stays under GPL-3.0-only.

**Keywords.** Stata; nwcommands; nwergm; exponential random graph model; ERGM; social network analysis; statistical network models; Monte Carlo maximum likelihood; pseudolikelihood; ergm; statnet

**Language.** English

**Related identifiers.** (relation, identifier, type)

| Relation | Identifier | Type |
|---|---|---|
| Is supplement to | https://github.com/thomas-u-grund/nwergm/releases/tag/v1.1.3 | URL |
| Is supplement to | https://github.com/thomas-u-grund/nwergm | URL |
| Requires | https://github.com/thomas-u-grund/nwcommands | URL |
| Is related to (the manual of the sibling package) | 10.5281/zenodo.23623807 | DOI |

The tag v1.1.3 and its GitHub release exist (checked 2026-10-25). The nwsaom link is optional; it is sensible because both manuals describe packages of the same family.

**Other fields.** Funding: none. Communities: none. Access: open.

## Steps for the owner

1. Bump the version first if a release later than 1.1.3 is meant: change `\pkgversion` and `\pkgdate` in `nwergm_manual.tex` (see `README.md` of this folder), rebuild with `make -C manual pdf`, and change the version in the title above.
2. On zenodo.org choose New upload, upload `manual/nwergm_manual.pdf`, and fill in the fields above.
3. Click "Reserve DOI" (Digital Object Identifier section) and note the DOI. Do not publish yet.
4. Send the DOI to Claude (or put it into `\manualdoi` in `nwergm_manual.tex`, for example `10.5281/zenodo.NNNNNNN`), rebuild the PDF, and replace the file in the draft upload with the rebuilt PDF (the DOI is printed on the title page and in the citation).
5. Publish the record. Zenodo also creates an all-versions DOI (concept DOI): later versions of the manual are uploaded as new versions of this record, as for nwsaom.
6. Commit the rebuilt PDF (`git add -f manual/nwergm_manual.pdf`) on the branch that carries the manual.

## Suggested edits after the DOI exists (not made)

Replace NNNNNNN by the DOI.

1. `README.md` (repository), section Manual: add "Archived at Zenodo: https://doi.org/10.5281/zenodo.NNNNNNN". The PDF now has 98 pages; "about 100 pages" in the README is still right.
2. `CITATION.cff`: add a `preferred-citation` as in nwsaom: type manual, title "nwergm: Exponential random graph models in Stata. Manual for version 1.1.3", author Grund, Thomas U., year 2026, publisher Zenodo, doi 10.5281/zenodo.NNNNNNN.
3. `NOTICE.md`, section How to cite: add the line "Grund, T. U. (2026). nwergm: Exponential random graph models in Stata. Manual for version 1.1.3. Zenodo. https://doi.org/10.5281/zenodo.NNNNNNN".
4. Website `nwergm/citation.md`: replace "There is no archived record with a DOI yet." by a sentence giving the manual's citation and the DOI, and change the block quote to the manual citation as above; the example "nwergm 1.1.1" and the text "(version 1.1.1)" become the current version.
5. Website `citing.md`: nwergm leaves the list "nwergm, nwdynam and nwrem. These have no DOI" and gets its own entry with the manual citation, as nwsaom has; the version in the nwergm entry becomes 1.1.3.
6. Website `index.md` (packages table) and `nwergm/index.md` (Version row): 1.1.1 becomes 1.1.3; add the "Manual" menu entry for nwergm (a copy of `website/nwsaom/manual.md` with the nwergm DOI, `nav_order` 10, permalink `/nwergm/manual/`); `news.md`: a dated entry "nwergm manual archived at Zenodo".
7. Website pages that give the term counts: check for "125 of 139" (the number is confirmed for nwergm 1.1.3 and ergm 4.12.0).

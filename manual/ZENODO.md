# Zenodo record for the nwergm manual, series 1.11

Metadata ready to paste into a new version of the existing Zenodo record. Nothing has been uploaded.

**DOI.** The all-versions ("Cite all versions") DOI of this manual is 10.5281/zenodo.23661331 (concept record); it is printed in the citation of the manual (`\manualdoi` in `nwergm_manual.tex`, already set). The citation text always uses the all-versions DOI.

**What is on Zenodo now** (public API, checked 2026-11-20): the concept record 23661331 has three versions: 23661332 (2026-10-26, file `nwergm_manual_1.3d.pdf`), 23728328 (2026-10-28, `nwergm_manual_1.3.pdf`) and 24084283 (2026-11-09, version label "1.5.4", file `nwergm_manual_1.5.4.pdf`). The series 1.6, 1.7, 1.8, 1.9, 1.10 and 1.11 were never uploaded; this upload covers all of them. (The label "1.5.4" of the last version was a patch version, not a series; from now on the label is the series "X.Y".)

**File to upload.** `nwergm_manual_1.11.pdf` (124 pages).

## Metadata

**Title.** nwergm: Exponential random graph models in Stata. Manual

**Version.** 1.11 (the series label, internal to Zenodo: the manual describes nwergm 1.11.x; not part of the citation)

**Publication date.** Day of the upload.

**Authors.** Grund, Thomas U. (RWTH Aachen University), ORCID 0000-0001-6751-5429.

**Resource type.** Publication, sub-type Software documentation.

**License.** Creative Commons Attribution 4.0 International (CC-BY-4.0) for the manual; the code is GPL-3.0-only.

**Language.** English

**Keywords.** Stata; nwcommands; nwergm; exponential random graph model; ERGM; Bayesian ERGM; egocentric data; social network analysis; statistical network models; Monte Carlo maximum likelihood; pseudolikelihood; ergm; statnet

**Description** (plain text, one paragraph):

> This is the user manual and reference of nwergm, series 1.11 (examples produced with version 1.11.0 and the nwcommands core 3.29.0), a Stata package for exponential random graph models (ERGMs). nwergm builds on the nwcommands core package (version 3.29.0 or later) and follows the R packages ergm (statnet project, version 4.12.0), Bergm (version 6.0.0) and ergm.ego (version 1.1.4) in their models, the names of their terms and their estimation algorithms. The manual explains the model and the estimators (maximum pseudolikelihood, Monte Carlo maximum likelihood, contrastive divergence, stochastic approximation, Bayesian estimation by the exchange algorithm), gives the syntax of every option, lists the terms of ergm with the status of each in nwergm, and documents the Monte Carlo sampling of the default fit (ergm's default proposal SPDyad, adaptive sample size, ergm's convergence test, compiled sampling kernels), curved terms with an estimated decay and their cutoff, offsets and constraints, networks with missing dyads, valued and two-mode networks, and the coefficient tables and their display options. It describes the postestimation commands: goodness of fit with one panel for every statistic, Markov chain diagnostics and posterior summaries, each with plots that can be saved, exported and given graph options. It has chapters on Bayesian ERGMs (nwergm with estimate(bayes)) and on ERGMs for egocentrically sampled data (nwergm ego), shows worked examples with output, compares the results with ergm, states the limits of the package, and gives a translation table from ergm to nwergm. The do-files that produce every listing and figure are in the repository. Requirements: Stata 17 or later (tested with Stata 17, 18 and StataNow 19.5) and the nwcommands core 3.29.0 or later. The package and the manual were prepared with the help of an AI coding assistant working under the author's direction, as stated in the manual.

**Related identifiers.** (relation, identifier, type)

| Relation | Identifier | Type |
|---|---|---|
| Is supplement to | https://github.com/thomas-u-grund/nwergm/releases/tag/v1.11.0 | URL |
| Is supplement to | https://github.com/thomas-u-grund/nwergm | URL |
| Requires | https://github.com/thomas-u-grund/nwcommands | URL |
| Is new version of | 10.5281/zenodo.24084283 | DOI |

(The last row is set automatically when the upload is made with "New version" of the existing record.) Confirm that the GitHub release v1.11.0 is published before the upload.

**Other fields.** Funding: none. Communities: none. Access: open.

## Steps for the owner

1. Open https://zenodo.org/records/24084283 (or the record 23661331), click "New version", delete the old file, upload `nwergm_manual_1.11.pdf`.
2. Fill the fields above (version "1.11", publication date, description, related identifiers); keep title, authors, resource type and licence.
3. The DOI of the all-versions record is already in the manual (`\manualdoi`): no rebuild is needed. Publish.
4. Commit the PDF in the nwergm repository (`manual/nwergm_manual.pdf`, `git add -f`), together with the changed sources (`manual/ch*.tex`, `manual/ex/ex07_graphs.do`, `manual/ex/out/`, `manual/fig/`, `manual/README.md`, `manual/ZENODO.md`).
5. A patch release (1.11.1, ...) gets no new Zenodo version: change `\pkgversion` and `\pkgdate`, rerun the examples if their output changes, commit the PDF. A new Zenodo version only for 1.12 or 2.0 with changed documented behaviour (then also `\manualseries`).

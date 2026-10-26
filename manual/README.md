# The nwergm manual

`nwergm_manual.pdf` is the user manual and reference of nwergm. The LaTeX source is `nwergm_manual.tex` with one file per chapter (`ch*.tex`, `app_translation.tex`).

## Bumping the version (one-line change)

The manual is labelled by the minor series, "Manual for version 1.2" (`\manualseries`, valid for 1.2.x). The exact version and date of the release that produced the listings are two more macros in `nwergm_manual.tex` (written by `tools/set_version.py`):

    \newcommand{\manualseries}{1.2}
    \newcommand{\pkgversion}{1.2.3}
    \newcommand{\pkgdate}{26 October 2026}

Change `\manualseries` only for a new minor or major release whose documented behaviour changed. For a patch release change the last two lines, rebuild (`make -C manual pdf`) and check the pages that the build output of the examples shows (version strings come from `make examples`, see below). The tag in the installation example of `ch01_intro.tex` (`nwergm/v1.2.3/`, inside a listing, so it cannot use the macro) is the only other place with the number.

## The DOI

`\manualdoi` in `nwergm_manual.tex` holds 10.5281/zenodo.23661332, the DOI reserved for the record. UNCONFIRMED: it may be the version DOI and not the all-versions DOI; after publication replace it by the all-versions DOI, rebuild, and add the DOI to the citation texts listed in `ZENODO.md`.

## Building

    make -C manual pdf        # regenerates the term tables and the comparison tables, then pdflatex (3 passes)
    make -C manual check      # undefined references, overfull boxes
    NWCORE=/path/to/nwcommands make -C manual examples   # reruns the do-files of ex/ in Stata (about 10 minutes)
    NWCORE=/path/to/nwcommands make -C manual compare   # the numerical comparison with R (needs R with ergm 4.12.0)

`build_terms.py` reads `docs/ERGM_TERMS_INVENTORY.csv` and writes `gen_terms.tex`, `gen_notimpl.tex`, `gen_other.tex` and `gen_counts.tex` (the number of terms). `build_compare.py` reads `ex/r/*.csv` and writes `gen_compare.tex` and `gen_compare_nums.tex`. The listings in `ex/out` are cut from the Stata logs by `ex/mklistings.py`. Do not edit the `gen_*.tex` files by hand.

## Archiving

`ZENODO.md` holds the metadata for the Zenodo record and the steps to do.

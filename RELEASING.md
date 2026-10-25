# Releasing nwergm

## Master procedure: https://github.com/thomas-u-grund/nwcommands/blob/main/RELEASING.md

All release procedures and policies of the five packages (steps, order, test launch, tags, GitHub release, website update, Zenodo, lockstep with the core
Mata library, building libraries with Stata 17, known traps) are in the master document above. Follow it; this file only holds what is specific to nwergm.
Two rules from there that are easy to miss: push the release tag by name (`git push origin vX.Y.Z`), never `git push origin main --tags`
(old local tags of this clone never existed on GitHub); and build `lib/*.mlib` with Stata 17, not 18.

## Version files and checks

- Single source of truth: `VERSION` (line 1 the version, line 2 the release date in Stata format, e.g. `25oct2026`). Semantic versioning (master B.4, C4).
- `python3 tools/set_version.py X.Y.Z [date]` writes it into every display (first line of every `.ado`, help headers and the footer of every help file, `nwergm.pkg`, `stata.toc`,
  `README.md`, `NOTICE.md`, `CITATION.cff`, the `e(version)` / `nwergm version` literals); `--check` changes nothing.
- Add `## [X.Y.Z] - YYYY-MM-DD` to `CHANGELOG.md` (Added / Changed / Fixed / Removed); its text is the GitHub release notes.
- `NWCORE=/path/to/nwcommands python3 tools/check_version.py` = version check plus the core-library hash check (below).
- Install lines: latest `net install nwergm, from(https://raw.githubusercontent.com/thomas-u-grund/nwergm/main/) replace`; a given release `.../nwergm/vX.Y.Z/`.
  `nwergm.pkg` states `Requires nwcommands (core), version A.B.C or later`; raise it (and `README.md`) only when this release needs a newer core.

## Library and lockstep with the core

`lib/build.do` builds `lib/lnwergm.mlib` from `unw_ergm.do` against the core's finished `lib/lnwcommands.mlib` (class `nw_def`): run it from the repository root with the Stata 17 binary,
`NWCORE=/path/to/nwcommands "/Applications/Stata 17.0/StataBE.app/Contents/MacOS/StataBE" -e do lib/build.do`, then `NWCORE=/path/to/nwcommands python3 tools/record_core_lib.py`
(writes `lib/core_mlib.sha256`). Whenever the core library changes, rebuild, record, test and release this package in the same batch as the core (master B.5, C3), core first.
Without that, a fresh install fails with r(3021) "class compiled at different times".

## Tests

`NWCORE=/path/to/nwcommands cscripts/run_tests.sh [jobs]` (first step: `tools/check_version.py`; each test runs in its own `-e` Stata process; set `STATA` to the Stata 17 binary, then repeat with 18).
Most tests print no PASS marker: failure is an `r()` error and a missing log is NOT RUN (master C0).

## Plugin

`native/ergm_mcmc.c` builds `ergm_mcmc` (macOS, Windows, Linux; CI commits the binaries to `lib/plugins/` on `main`; wait for the bot commit, `pull --rebase`, tag after it). The operator terms run in the plugin only, so a changed plugin must be rebuilt for every platform before the release.
Do not copy a rebuilt plugin over a loaded one (`rm` first); test through a scratch `adopath`.

## R reference, manual, Zenodo

- The reference is R `ergm` 4.12.0 (the development 4.13 differs in places, GOTCHA.md); keep `docs/VALIDATED_AGAINST_R.md` and `docs/ERGM_TERMS_INVENTORY.csv` current when terms change. Follow R as closely as possible (master B.8).
- The nwergm manual (97 pages) is NOT on `main`: it is on the local branches `manual`, `manual2`, `manual3` of the clone. It waits for its own Zenodo record (the owner creates it and tells the DOI; then `\manualdoi` is filled, the manual merged and the website "Manual" entry added).
  Per master B.10 a new Zenodo version is for minor/major releases that change documented behaviour (nwergm 1.2.0 with R's MCMC defaults was one), never for patches.
- Many old local tags (81, never on GitHub, e.g. `v1.2.1`, `v1.6.3`, `v2.0.0`) exist in the clone: check `git tag -l vX.Y.Z` before tagging, and never push with `--tags`.

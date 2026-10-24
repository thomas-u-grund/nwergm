# Build of the manual.  make pdf     : the tables are regenerated from docs/ERGM_TERMS_INVENTORY.csv and ex/r/*.csv, the PDF is built (3 passes)
#                      make examples: reruns the do-files of ex/ in Stata (needs NWCORE=/path/to/nwcommands and Stata; about 5 minutes)
#                      make check   : undefined references, overfull boxes, glued words
# The PDF is committed with git add -f (the LaTeX build files are ignored).
all: pdf

tables:
	python3 build_terms.py
	python3 build_compare.py

pdf: tables
	pdflatex -interaction=nonstopmode nwergm_manual.tex
	pdflatex -interaction=nonstopmode nwergm_manual.tex
	pdflatex -interaction=nonstopmode nwergm_manual.tex

# the numerical comparison with R of chapter 9 (needs Stata and R with ergm 4.12.0; about 10 minutes): Stata writes the networks and its estimates to ex/r, R reads them and writes its own
compare:
	NWCORE=$(NWCORE) ./run_examples.sh ex90_export_for_r ex91_compare_stata ex97_simcheck ex9a_timing ex9e_extra_terms
	cd ex/r && Rscript compare.R && Rscript simcheck.R && Rscript timing.R && Rscript extra.R
	python3 build_compare.py

examples:
	./run_examples.sh ex01_florentine ex02_mesa ex03_lazega ex04_kapferer ex05_missing ex06_special ex07_graphs ex08_constraints

check:
	python3 check_layout.py

clean:
	rm -f *.aux *.log *.toc *.out *.bbl *.blg *.lof *.lot

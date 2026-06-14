MAIN = main
LATEX = pdflatex
BIBTEX = bibtex

all: $(MAIN).pdf

$(MAIN).pdf: $(MAIN).tex
	$(LATEX) -interaction=nonstopmode $(MAIN)
	$(BIBTEX) $(MAIN)
	$(LATEX) -interaction=nonstopmode $(MAIN)
	$(LATEX) -interaction=nonstopmode $(MAIN)

clean:
	rm -f *.aux *.bbl *.blg *.log *.lof *.lot *.toc *.out *.fls *.fdb_latexmk
	find chapters/ -name "*.aux" -delete
	find frontmatter/ -name "*.aux" -delete
	find appendices/ -name "*.aux" -delete

cleanall: clean
	rm -f $(MAIN).pdf

.PHONY: all clean cleanall

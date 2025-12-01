.SUFFIXES: .dvi .ps .pdf .ltx .xml .tex .eps .js .yaml .cal

BASE	= /locker/gaming/dq/characters
SCRIPTS = $(BASE)/scripts
CONVERT		= $(SCRIPTS)/convert.pl
FORMAT		= $(SCRIPTS)/format.pl
FORMAT_CAIRO	= $(SCRIPTS)/format.pl -p yaml -f cairo
FORMAT_TEX	= $(SCRIPTS)/format.py
FORMAT_CAL	= $(SCRIPTS)/format.pl -p yaml -f cal
LATEX		= lualatex
STY_FILE	= /locker/gaming/dq/documents/styles/ranking-v2.sty


TODAY	= $(shell date +%Y%m%d)

#%_cover.pdf	: %.yaml $(FORMAT) cover.j2
#	$(FORMAT_CAIRO)  -i $< -o $@

%_cover.ltx:	%.yaml $(FORMAT) cover.j2
	$(FORMAT_TEX) -t cover.j2 -i $< -o $@

%.ltx	: %.yaml $(FORMAT_TEX) ranking.j2
	$(FORMAT_TEX) -t ranking.j2 -i $< -o $@

%.pdf	: %.ltx $(STY_FILE)
	texfot $(LATEX) -output-directory $(dir $<) $<

%.cal	: %.yaml $(FORMAT)
	$(FORMAT_CAL) -i $< -o $@

PDF_FILES	= thinknottle.pdf callas.pdf jedburgh.pdf ishamael.pdf 

COVER_FILES	= callas_cover.pdf jedburgh_cover.pdf ishamael_cover.pdf thinknottle_cover.pdf

CAL_FILES	= callas.cal

YAML_FILES	= thinknottle.yaml

all: $(YAML_FILES) $(PDF_FILES) $(COVER_FILES) $(CAL_FILES) $(TS_PDF_FILES)

callas.yaml		: $(BASE)/callas/ranking.tex $(CONVERT)
	$(CONVERT) --format yaml --in $< --out $@

ishamael.yaml		: $(BASE)/ishamael/ranking.tex $(CONVERT)
	$(CONVERT) --format yaml --in $< --out $@

thinknottle.yaml	: $(BASE)/thinknottle/ranking.tex $(CONVERT)
	$(CONVERT) --format yaml --in $< --out $@

jedburgh.yaml		: $(BASE)/jedburgh/ranking.tex $(CONVERT)
	$(CONVERT) --format yaml -i $< -o $@

simon.yaml		: ./regaldo/simon.tex $(CONVERT)
	$(CONVERT) --format yaml -i $< -o $@

arthur.yaml		: ./regaldo/arthur.tex $(CONVERT)
	$(CONVERT) --format yaml -i $< -o $@

ahzrak.yaml		: ./regaldo/ahzrak.tex $(CONVERT)
	$(CONVERT) --format yaml -i $< -o $@

trigg.yaml		: ./regaldo/trigg.tex $(CONVERT)
	$(CONVERT) --format yaml -i $< -o $@

.SUFFIXES: .dvi .ps .pdf .ltx .xml .tex .eps .js .yaml .cal

CONVERT		= scripts/convert.pl
FORMAT_CAIRO	= scripts/format.pl -p yaml -f cairo
FORMAT_TEX	= scripts/format.py
FORMAT_CAL	= scripts/format.pl -p yaml -f cal
LATEX		= lualatex

%_cover.pdf	: %.yaml $(FORMAT_CAIRO)
	$(FORMAT_CAIRO)  -i $< -o $@

%.ltx	: %.yaml $(FORMAT_TEX)
	$(FORMAT_TEX) -i $< -o $@

%.pdf	: %.ltx ../documents/styles/ranking-v2.sty
	$(LATEX) -output-directory $(dir $<) $<

%.cal	: %.yaml 
	$(FORMAT_CAL) -i $< -o $@

VPATH	= ranking

PDF_FILES	= ranking/thinknottle.pdf ranking/callas.pdf ranking/jedburgh.pdf ranking/ishamael.pdf 

COVER_FILES	= ranking/callas_cover.pdf ranking/jedburgh_cover.pdf ranking/ishamael_cover.pdf ranking/thinknottle_cover.pdf

CAL_FILES	= ranking/callas.cal

YAML_FILES = ranking/thinknottle.yaml

all: $(YAML_FILES) $(PDF_FILES) $(COVER_FILES) $(CAL_FILES)


ranking/callas.yaml		: ./callas/ranking.tex $(CONVERT)
	$(CONVERT) --format yaml --in $< --out $@

ranking/ishamael.yaml	: ./ishamael/ranking.tex $(CONVERT)
	$(CONVERT) --format yaml --in $< --out $@

ranking/thinknottle.yaml	: ./thinknottle/ranking.tex $(CONVERT)
	$(CONVERT) --format yaml --in $< --out $@

ranking/jedburgh.yaml	: ./jedburgh/ranking.tex $(CONVERT)
	$(CONVERT) --format yaml -i $< -o $@

ranking/simon.yaml		: ./regaldo/simon.tex $(CONVERT)
	$(CONVERT) --format yaml -i $< -o $@

ranking/arthur.yaml		: ./regaldo/arthur.tex $(CONVERT)
	$(CONVERT) --format yaml -i $< -o $@

ranking/ahzrak.yaml		: ./regaldo/ahzrak.tex $(CONVERT)
	$(CONVERT) --format yaml -i $< -o $@

ranking/trigg.yaml		: ./regaldo/trigg.tex $(CONVERT)
	$(CONVERT) --format yaml -i $< -o $@

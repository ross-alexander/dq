LATEX	= latex
XELATEX	= xelatex
SX	= osx

%.pdf	: %.fo
	fop $< $@

%.fo	: %.xml xml2fo.xsl
	xsltproc -o $@ xml2fo.xsl $<

%.tex : %.sgml tex/mapping
	./mm2tex $<

%.htm : %.sgml
	./mm2htm $<

%.xml : %.sgml dqmm.dtd
	$(SX) -xno-nl-in-tag -xlower $< > $@

SOURCE = avians.sgml \
	aquatics.sgml \
	common-mammals.sgml \
	dragons.sgml \
	fantastical.sgml \
	giants-fairies.sgml \
	lizards.sgml \
	night-shadow.sgml \
	riding.sgml \
	summonables.sgml \
	undead.sgml \
	demons.sgml

HTML = $(SOURCE:.sgml=.htm)
TEX = $(SOURCE:.sgml=.tex)
XML = $(SOURCE:.sgml=.xml)

all: index.htm avians.pdf

index.htm: $(XML) webify.pl
	./webify.pl

dqmm.htm: $(HTML)

dqmm.pdf: dqmm.tex dqmm.sty $(TEX)
	$(XELATEX) dqmm.tex

dqmm.dvi: dqmm.tex dqmm.sty $(TEX)
	$(LATEX) dqmm.tex

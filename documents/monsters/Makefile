.suffix: .pdf .fo .tex .html .xml

LATEX	= lualatex
SX	= osx
CFLAGS	= `pkg-config --cflags libxml-2.0 libxslt`
LDLIBS	= `pkg-config --libs libxml-2.0 libxslt`

%.pdf	: %.fo
	fop $< $@

%.fo	: %.xml xml2fo.xsl
	xsltproc -o $@ xml2fo.xsl $<

%.tex : %.sgml dqmm.dtd tex/mapping
	./sgmlcvt --format tex $< $@

%.html : %.sgml dqmm.dtd html/mapping
	./sgmlcvt --format html $< $@

%.xml : %.sgml dqmm.dtd xml/general
	./sgmlcvt --format xml $< $@

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

HTML = $(SOURCE:.sgml=.html)
TEX = $(SOURCE:.sgml=.tex)
XML = $(SOURCE:.sgml=.xml)

all: dqmm.pdf $(HTML) $(XML) $(TEX)

xslt.o : xslt.c

index.html: $(XML) webify.pl
	./webify.pl

dqmm.html: $(HTML)

dqmm.pdf: dqmm.tex dqmm.sty $(TEX)
	$(LATEX) dqmm.tex

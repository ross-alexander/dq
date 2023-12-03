LATEX	= latex
XELATEX	= xelatex
SX	= osx
CFLAGS	= `pkg-config --cflags libxml-2.0 libxslt`
LDLIBS	= `pkg-config --libs libxml-2.0 libxslt`

%.pdf	: %.fo
	fop $< $@

%.fo	: %.xml xml2fo.xsl
	xsltproc -o $@ xml2fo.xsl $<

%.tex : %.sgml tex/mapping
	./mm2tex $<

%.html : %.sgml
	./mm2html $<

%.xml : %.sgml dqmm.dtd
	$(SX) -Dxml -xno-nl-in-tag -xno-expand-internal -xno-expand-external -xlower $< > $@

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

all: dqmm.pdf xslt

xslt.o : xslt.c

index.html: $(XML) webify.pl
	./webify.pl

dqmm.html: $(HTML)

dqmm.pdf: dqmm.tex dqmm.sty $(TEX)
	$(XELATEX) dqmm.tex

dqmm.dvi: dqmm.tex dqmm.sty $(TEX)
	$(LATEX) dqmm.tex

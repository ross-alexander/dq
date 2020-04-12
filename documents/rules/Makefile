MAJORRELEASE = 5
MINORRELEASE = 11
RELDIR = rules-$(MAJORRELEASE).$(MINORRELEASE)

SUBDIRS=skills magic misc tables
PICDIR=pics
DIRS = $(PICDIR) $(SUBDIRS) .

SKILLS= skills/skills.tex \
	skills/adventuring.tex \
	skills/alchemist.tex \
	skills/armourer.tex \
	skills/artisan.tex \
	skills/assassin.tex \
	skills/astrologer.tex \
	skills/beastmaster.tex \
	skills/courtesan.tex \
	skills/healer.tex \
	skills/herbalist.tex \
	skills/languages.tex \
	skills/mechanician.tex \
	skills/merchant.tex \
	skills/military.tex \
	skills/navigator.tex \
	skills/philosopher.tex \
	skills/ranger.tex \
	skills/spy.tex \
	skills/thief.tex \
	skills/troubadour.tex \
	skills/warrior.tex \
	skills/weaponsmith.tex

MAGIC=	magic/magic.tex \
	magic/minor-magic.tex \
	magic/detect-aura.tex \
	magic/college.tex \
	magic/non-college.tex \
	magic/bardic.tex \
	magic/binder.tex \
	magic/enchant.tex \
	magic/illusion.tex \
	magic/mind.tex \
	magic/namer.tex \
	magic/air.tex \
	magic/celestial.tex \
	magic/earth.tex \
	magic/fire.tex \
	magic/ice.tex \
	magic/water.tex \
	magic/summoning.tex \
	magic/necro.tex \
	magic/rune.tex \
	magic/witchcraft.tex \

TABLES=	tables/fright.tex \
	tables/backfire.tex \
	tables/combat.tex \
	tables/weapons.tex \
	tables/spec-grev.tex \
	tables/equation.tex \
	tables/misc.tex \
	tables/ep.tex \
	tables/fumble.tex

MISC=	misc/combat.tex \
	misc/adventure.tex \
	misc/character.tex \
	misc/ranking.tex

RULES=	rules.tex credits.tex history.tex copyright.tex

LATEX=latex
MAKEINDEX=makeindex
PDFLATEX=pdflatex

rules: rules.dvi rules.pdf


rules.pdf: rules.dvi
	$(PDFLATEX) rules.tex
rules.dvi: $(RULES) $(MAGIC) $(SKILLS) $(TABLES) $(MISC)
	$(LATEX) rules.tex
	$(MAKEINDEX) rules
	$(LATEX) rules.tex

checkout-lock: $(RULES) $(MAGIC) $(SKILLS) $(TABLES) $(MISC)
	co -l $^

checkout: $(RULES) $(MAGIC) $(SKILLS) $(TABLES) $(MISC)
	co $^

force-revision: $(RULES) $(MAGIC) $(SKILLS) $(TABLES) $(MISC)
	ci -f$(MAJORRELEASE).$(MINORRELEASE) -nREL$(MAJORRELEASE)$(MINORRELEASE) -mREL$(MAJORRELEASE)$(MINORRELEASE) $^

revision-text: $(RULES) $(MAGIC) $(SKILLS) $(TABLES) $(MISC)
	for i in $^; do\
		rcs -trevision.txt $$i; \
	done

revision: $(RULES) $(MAGIC) $(SKILLS) $(TABLES) $(MISC)
	co -l $^
	ci -nREL$(MAJORRELEASE)$(MINORRELEASE) $^

rules.tar: Makefile $(RULES) $(MAGIC) $(SKILLS) $(TABLES) $(MISC)
	tar cf $@ $^

release: $(TABLES) $(MAGIC) $(SKILLS) $(MISC) $(RULES)
	co -rREL$(MAJORRELEASE)$(MINORRELEASE) $^
	if [ ! -d $(RELDIR) ]; then \
	mkdir $(RELDIR); \
	for i in $(SUBDIRS) $(PICDIR); do mkdir $(RELDIR)/$$i; done \
	fi
	for i in $(SUBDIRS); do cp -f $$i/*.tex $(RELDIR)/$$i; done
	cp -f *.tex $(RELDIR)
	cp -f $(PICDIR)/*.eps $(RELDIR)/$(PICDIR)

clean:
	for i in . $(SUBDIRS); do \
	(cd $$i; rcsclean ; rm -f *.log *.aux *~ *.dvi *.toc *.idx *.ilg *.ind *.ps *.pdf *.etx)\
	done

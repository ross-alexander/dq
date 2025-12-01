PANDOC_FLAGS = -V documentclass=report -V fontsize=8pt

RULES	= dq2020e.tex chargen.tex characteristics.tex ranking.tex health.tex equipment.tex combat.tex magic.tex cantrips.tex names.tex college.tex noncollege.tex bard.tex binder.tex enchanter.tex illusion.tex mind.tex naming.tex air.tex celestial.tex earth.tex fire.tex ice.tex water.tex summoning.tex necromancy.tex rune.tex witchcraft.tex skills.tex adventuring.tex alchemist.tex armourer.tex artisan.tex assassin.tex astrologer.tex beastmaster.tex courtier.tex healer.tex herbalist.tex languages.tex mechanician.tex merchant.tex milsci.tex navigator.tex philosopher.tex ranger.tex spy.tex thief.tex troubadour.tex warrior.tex weaponsmith.tex grievous.tex fumble.tex backfire.tex fright.tex experience.tex weapons.tex combat-tables.tex miscellaneous.tex history.tex

ALL = dq2020e.pdf

all: $(ALL)

dq2020e.pdf : $(RULES) dq2020e.sty
	latexmk -lualatex $<

clean:
	rm -f *.fls *.out *.aux *.log *~

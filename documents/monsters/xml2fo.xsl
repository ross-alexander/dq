<?xml version="1.0" encoding="iso-8859-1"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:fo="http://www.w3.org/1999/XSL/Format" version="1.0">

<xsl:output method="xml" version="1.0" indent="yes"/>

<xsl:template match="dqmm">
<fo:root xmlns:fo="http://www.w3.org/1999/XSL/Format">
  <fo:layout-master-set>
    <fo:simple-page-master master-name="my-page">
      <fo:region-body margin="1in" column-width="4cm" column-count="3"/>
    </fo:simple-page-master>
  </fo:layout-master-set>

  <xsl:apply-templates select="group"/>

</fo:root>
</xsl:template>

<xsl:template match="group">
  <fo:page-sequence master-reference="my-page">
    <fo:flow flow-name="xsl-region-body">
      <fo:block text-align="center" font-size="18pt" font-family="Times"><xsl:value-of select="@name"/></fo:block>
      <xsl:apply-templates select="notes"/>
      <xsl:apply-templates select="class"/>
    </fo:flow>
  </fo:page-sequence>
</xsl:template>


<xsl:template match="class">
  <fo:block text-align="center"
  	    font-size="14pt"
	    font-family="Times"
	    space-before="10pt"
	    space-after="10pt">
    <xsl:value-of select="@name"/>
  </fo:block>
  <xsl:apply-templates select="notes"/>
  <xsl:apply-templates select="monster"/>
</xsl:template>


<xsl:template match="monster">
  <fo:block text-align="center"
	    font-family="Times"
	    font-weight="bold"
	    font-size="10pt"
	    border-width="1pt"
	    border-color="blue"
	    border-style="solid"
	    space-before="10pt"
	    space-after="4pt"
	    padding-before="2pt"
	    padding-after="2pt"
	    >
    <xsl:value-of select="@name"/>
  </fo:block>
  <xsl:apply-templates select="description"/>
  <xsl:apply-templates select="talents"/>
  <xsl:apply-templates select="stats"/>
  <xsl:apply-templates select="weapons"/>
</xsl:template>


<xsl:template match="notes">
  <fo:block
    font-size="9pt"
    color="red"
    >
    <xsl:value-of select="."/>
  </fo:block>
</xsl:template>

<xsl:template match="description">
  <fo:block font-size="9pt" text-align="justify" keep-together="2">
    <fo:inline font-weight="bold">Description: </fo:inline>
    <xsl:value-of select="."/>
  </fo:block>
</xsl:template>


<xsl:template match="talents">
  <fo:block font-size="9pt" text-align="justify" keep-together="2">
    <fo:inline font-weight="bold">Talents: </fo:inline>
    <xsl:value-of select="."/>
  </fo:block>
</xsl:template>

<xsl:template match="weapons">
  <fo:block font-size="9pt"
            text-align="justify"
	    keep-together="2"
	    keep-together.within-column="always">
    <fo:inline font-weight="bold">Weapons: </fo:inline>
    <xsl:value-of select="."/>
  </fo:block>
</xsl:template>

<xsl:template match="stats">
  <fo:table border="0.2pt solid black" table-layout="fixed" font-size="9pt" space-before="4pt" space-after="4pt">
    <fo:table-column column-width="1.0cm"/>
    <fo:table-column column-width="1.2cm"/>
    <fo:table-column column-width="1.0cm"/>
    <fo:table-column column-width="1.2cm"/>
    <fo:table-body>
      <fo:table-row>
        <fo:table-cell><fo:block font-weight="bold">PS</fo:block></fo:table-cell>
        <fo:table-cell><fo:block font-weight="bold"><xsl:value-of select="ps"/></fo:block></fo:table-cell>
        <fo:table-cell><fo:block font-weight="bold">MD</fo:block></fo:table-cell>
        <fo:table-cell><fo:block font-weight="bold"><xsl:value-of select="md"/></fo:block></fo:table-cell>
      </fo:table-row>
      <fo:table-row>
        <fo:table-cell><fo:block font-weight="bold">AG</fo:block></fo:table-cell>
        <fo:table-cell><fo:block font-weight="bold"><xsl:value-of select="ag"/></fo:block></fo:table-cell>
        <fo:table-cell><fo:block font-weight="bold">MA</fo:block></fo:table-cell>
        <fo:table-cell><fo:block font-weight="bold"><xsl:value-of select="ma"/></fo:block></fo:table-cell>
      </fo:table-row>
      <fo:table-row>
        <fo:table-cell><fo:block font-weight="bold">WP</fo:block></fo:table-cell>
        <fo:table-cell><fo:block font-weight="bold"><xsl:value-of select="wp"/></fo:block></fo:table-cell>
        <fo:table-cell><fo:block font-weight="bold">EN</fo:block></fo:table-cell>
        <fo:table-cell><fo:block font-weight="bold"><xsl:value-of select="en"/></fo:block></fo:table-cell>
      </fo:table-row>
    </fo:table-body>
  </fo:table>
</xsl:template>

</xsl:stylesheet>

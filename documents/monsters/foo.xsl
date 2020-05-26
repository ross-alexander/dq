<?xml version="1.0"?> 
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:template match="DQMM">
    <html>
      
      <head>
	<title> <xsl:value-of select="GROUP/@NAME"/> </title>
        <link rel="stylesheet" type="text/css" href="monsters.css"/>
      </head>
      <xsl:apply-templates/>
    </html>
  </xsl:template>

  <xsl:template match="GROUP">
    <body>
      <div class="group">
      <h1><xsl:value-of select="@NAME"/></h1>
      <xsl:apply-templates/>
    </div>
    </body>
  </xsl:template>

  <xsl:template match="MONSTER">
    <div class="monster">
    <h3><xsl:value-of select="@NAME"/></h3>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <xsl:template match="NUMBERS">
    <p class="talent"><b>Talents</b>
    <xsl:value-of select="."/>
    </p>
  </xsl:template>

  <xsl:template match="HABITAT">
    <p class="talent"><b>Talents</b>
    <xsl:value-of select="."/>
    </p>
  </xsl:template>

  <xsl:template match="FREQUENCY">
    <p class="talent"><b>Talents</b>
    <xsl:value-of select="."/>
    </p>
  </xsl:template>

  <xsl:template match="TALENTS">
    <p class="talent"><b>Talents</b>
    <xsl:value-of select="."/>
    </p>
  </xsl:template>
</xsl:stylesheet>

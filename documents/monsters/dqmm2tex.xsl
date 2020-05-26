<?xml version="1.0"?> 
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:template match="DQMM">
\documentclass[a4paper]{article}
\begin{document}
<xsl:apply-templates/>
\end{document}
  </xsl:template>

<xsl:template match="GROUP">
\section{<xsl:value-of select="@NAME"/>}
<xsl:apply-templates/>
</xsl:template>

<xsl:template match="MONSTER">
\subsection{<xsl:value-of select="@NAME"/>}
<xsl:apply-templates/>
</xsl:template>

</xsl:stylesheet>

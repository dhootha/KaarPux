<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
    <xsl:import href="/usr/share/xml/docbook/stylesheet/nwalsh/xhtml/chunk.xsl"/>
    <xsl:import href="kx_navigation.xsl"/>
    <xsl:import href="kx_toc.xsl"/>

    <xsl:param name="suppress.navigation">1</xsl:param>
    <xsl:param name="chunker.output.indent">yes</xsl:param>
    <xsl:param name="navig.showtitles">0</xsl:param>
    <xsl:param name="html.stylesheet">default.css</xsl:param>
    <xsl:param name="use.id.as.filename">1</xsl:param>
    <xsl:param name="chapter.autolabel">0</xsl:param>
    <xsl:param name="appendix.autolabel">0</xsl:param>
    <xsl:param name="chunk.first.sections">1</xsl:param>
    <xsl:param name="chunk.section.depth">1</xsl:param>
    <xsl:param name="make.valid.html">1</xsl:param>
    <xsl:param name="html.cleanup">1</xsl:param>

    <xsl:param name="toc.max.depth">2</xsl:param>
    
    <xsl:param name="generate.toc">
        appendix  toc,title
        article/appendix  nop
        article   toc,title
        book      toc,title
        chapter   toc,title
        part      toc,title
        preface   toc,title
        qandadiv  toc
        qandaset  toc
        reference toc,title
        sect1     toc
        sect2     toc
        sect3     toc
        sect4     toc
        sect5     toc
        section   toc
        set       toc,title
    </xsl:param>

    <!-- customize xref title generation: include only text of titles -->
    <xsl:param name="local.l10n.xml" select="document('')"/>
    <l:i18n xmlns:l="http://docbook.sourceforge.net/xmlns/l10n/1.0">
        <l:l10n language="en">
            <l:context name="xref">
                <l:template name="appendix" text="%t"/>
                <l:template name="chapter" text="%t"/>
                <l:template name="section" text="%t"/>
            </l:context>
        </l:l10n>
    </l:i18n>

</xsl:stylesheet>


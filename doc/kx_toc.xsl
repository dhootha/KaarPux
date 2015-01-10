<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

<!-- ==================================================================== -->

<!-- originally from /usr/share/xml/docbook/stylesheet/nwalsh/xhtml/autotoc.xsl -->

<xsl:template match="section" mode="toc">
	<xsl:param name="toc-context" select="."/>

	<xsl:choose>
		<xsl:when test="local-name($toc-context) = 'book'">
			<xsl:choose>
				<xsl:when test="ancestor::appendix">
					<!-- no TOC for sections under appendix -->
				</xsl:when>
				<xsl:otherwise>
					<xsl:call-template name="subtoc">
					<xsl:with-param name="toc-context" select="$toc-context"/>
					<xsl:with-param name="nodes" select="section|refentry |simplesect[$simplesect.in.toc != 0]|bridgehead[$bridgehead.in.toc != 0]"/>
					</xsl:call-template>
				</xsl:otherwise>
			</xsl:choose>

		</xsl:when>
		<xsl:otherwise>
			<xsl:call-template name="subtoc">
			<xsl:with-param name="toc-context" select="$toc-context"/>
			<xsl:with-param name="nodes" select="section|refentry|simplesect[$simplesect.in.toc != 0] |bridgehead[$bridgehead.in.toc != 0]"/>
			</xsl:call-template>
		</xsl:otherwise>
	</xsl:choose>

</xsl:template>

</xsl:stylesheet>


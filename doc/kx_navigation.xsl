<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns="http://www.w3.org/1999/xhtml">

<!-- ==================================================================== -->

<!-- originally from /usr/share/xml/docbook/stylesheet/nwalsh/xhtml/chunk-common.xsl -->

<xsl:template name="header.navigation">
  <xsl:param name="prev" select="/foo"/>
  <xsl:param name="next" select="/foo"/>
  <xsl:param name="nav.context"/>

  <xsl:variable name="home" select="/*[1]"/>
  <xsl:variable name="up" select="parent::*"/>

  <div class="navheader">
    <xsl:call-template name="breadcrumbs"/>

    <div class="next">
      <xsl:if test="count($next)&gt;0">
        <span />
        <a accesskey="n">
           <xsl:attribute name="href">
            <xsl:call-template name="href.target">
              <xsl:with-param name="object" select="$next"/>
            </xsl:call-template>
          </xsl:attribute>
          <xsl:attribute name="title">
            <xsl:apply-templates select="$next" mode="object.title.markup"/>
          </xsl:attribute>
          <xsl:call-template name="navig.content">
            <xsl:with-param name="direction" select="'next'"/>
          </xsl:call-template>
        </a>
      </xsl:if>
    </div>
  </div>
</xsl:template>

<!-- ==================================================================== -->

<!-- originally from /usr/share/xml/docbook/stylesheet/nwalsh/xhtml/chunk-common.xsl -->

<xsl:template name="footer.navigation">
  <xsl:param name="prev" select="/foo"/>
  <xsl:param name="next" select="/foo"/>
  <xsl:param name="nav.context"/>

  <xsl:variable name="home" select="/*[1]"/>
  <xsl:variable name="up" select="parent::*"/>

  <div class="navfooter">

    <ul>
      <li class="prev">
        <xsl:choose>
        <xsl:when test="count($prev)&gt;0">
          <ul>
            <li>
              <a accesskey="p">
                <xsl:attribute name="href">
                  <xsl:call-template name="href.target">
                    <xsl:with-param name="object" select="$prev"/>
                  </xsl:call-template>
                </xsl:attribute>
                <xsl:call-template name="navig.content">
                  <xsl:with-param name="direction" select="'prev'"/>
                </xsl:call-template>
              </a>
            </li><li>
                <xsl:apply-templates select="$prev" mode="object.title.markup"/>
            </li>
          </ul>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>.</xsl:text>
        </xsl:otherwise>
        </xsl:choose>
        </li>
        <li class="copyright">
          <ul>
            <li>Copyright &#169; 2012-2015: Henrik Kaare Poulsen</li>
            <li>Git version: <xsl:value-of select="document('current_version.xml')"/></li>
          </ul>
        </li>
        <xsl:if test="count($next)&gt;0">
          <li class="next">
            <ul>
              <li>
                  <a accesskey="n">
                    <xsl:attribute name="href">
                      <xsl:call-template name="href.target">
                        <xsl:with-param name="object" select="$next"/>
                      </xsl:call-template>
                    </xsl:attribute>
                    <xsl:call-template name="navig.content">
                      <xsl:with-param name="direction" select="'next'"/>
                    </xsl:call-template>
                  </a>
                </li><li>
                  <xsl:apply-templates select="$next" mode="object.title.markup"/>
              </li>
            </ul>
          </li>
        </xsl:if>
      </ul>
    </div>
</xsl:template>


<!-- ==================================================================== -->

<!-- originally from http://www.sagehill.net/docbookxsl/HTMLHeaders.html#BreadCrumbs -->

<xsl:template name="breadcrumbs">
  <xsl:param name="this.node" select="."/>
  <xsl:variable name="href.this">
    <xsl:call-template name="href.target.uri">
      <xsl:with-param name="object" select="$this.node"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="depth">
    <xsl:call-template name="count.uri.path.depth">
      <xsl:with-param name="filename" select="$href.this"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="href">
    <xsl:call-template name="copy-string">
      <xsl:with-param name="string" select="'../'"/>
      <xsl:with-param name="count" select="$depth"/>
    </xsl:call-template>
  </xsl:variable>
  <div class="breadcrumbs"><ul>
    <li class="breadcrumb-link">
      <xsl:element name="a"><xsl:attribute name="href"><xsl:value-of select="$href"/>index.html</xsl:attribute>KaarPux</xsl:element>
    </li>
    <xsl:for-each select="$this.node/ancestor::*">
      <li class="breadcrumb-link">
        <a>
          <xsl:attribute name="href">
            <xsl:call-template name="href.target">
              <xsl:with-param name="object" select="."/>
              <xsl:with-param name="context" select="$this.node"/>
            </xsl:call-template>
          </xsl:attribute>
          <xsl:apply-templates select="." mode="title.markup"/>
        </a>
      </li>
    </xsl:for-each>
    <!-- And display the current node, but not as a link -->
    <li class="breadcrumb-node">
      <xsl:apply-templates select="$this.node" mode="title.markup"/>
    </li>
  </ul></div>
</xsl:template>


<!-- ==================================================================== -->

<xsl:template name="user.header.navigation">
  <xsl:param name="this.node" select="."/>

  <xsl:variable name="href.this">
    <xsl:call-template name="href.target.uri">
      <xsl:with-param name="object" select="$this.node"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="depth">
    <xsl:call-template name="count.uri.path.depth">
      <xsl:with-param name="filename" select="$href.this"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="href">
    <xsl:call-template name="copy-string">
      <xsl:with-param name="string" select="'../'"/>
      <xsl:with-param name="count" select="$depth"/>
    </xsl:call-template>
  </xsl:variable>

  <div class="top">
    <div class="kaarpux">
      <xsl:element name="a"><xsl:attribute name="href"><xsl:value-of select="$href"/>index.html</xsl:attribute><xsl:attribute name="id">kaarpux</xsl:attribute>KaarPux</xsl:element><br/>
      <xsl:element name="a"><xsl:attribute name="href"><xsl:value-of select="$href"/>index.html</xsl:attribute>Linux build from source</xsl:element><br/>
    </div>
    <div class="quicklinks">
      <ul>
      <li><xsl:element name="a"><xsl:attribute name="href"><xsl:value-of select="$href"/>index.html</xsl:attribute>About</xsl:element></li>
      <li><xsl:element name="a"><xsl:attribute name="href"><xsl:value-of select="$href"/>help.html</xsl:attribute>Get Help</xsl:element></li>
      <li><xsl:element name="a"><xsl:attribute name="href"><xsl:value-of select="$href"/>documentation.html</xsl:attribute>Documentation</xsl:element></li>
      </ul>
    </div>
  </div>
</xsl:template>

</xsl:stylesheet>


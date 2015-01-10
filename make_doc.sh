#!/bin/sh
#
# KaarPux: http://kaarpux.kaarposoft.dk
#
# Copyright (C) 2012-2014: Henrik Kaare Poulsen
#
# License: http://kaarpux.kaarposoft.dk/license.html
#

set -o nounset
set -o errexit

#
# Find out where we are; and include common functions
#

KX_BASE="$(cd "$(dirname "$0")"; pwd -P)"
KX_TOP="$(cd "${KX_BASE}"/..; pwd -P)"
. "${KX_BASE}/shinc/common_functions.shinc"
kx_ensure_runas_nonroot

#
# update version, if we are in git
#
echo "Getting version ..."
kx_git_describe || echo "We do not seem to be in a git repo"


#
# directories to use
#
KX_DOC_IN="${KX_BASE}/doc"
KX_DOC_OUT="${KX_TOP}/doc"
KX_DOC_TMP=$(mktemp --tmpdir --directory 'kx_doc_XXXXXX')
KX_DOC_PKG="${KX_TOP}/master/packages"
echo "Temp dir [${KX_DOC_TMP}]"

#
# copy eveything into the temp dir
#
echo "Preparing document generation ..."
set -a
. "${KX_BASE}/../linux/shinc/packages.shinc"
cp -r "${KX_DOC_IN}/"* "${KX_DOC_TMP}"
cp "${KX_TOP}/current_version.txt" "${KX_DOC_TMP}"

#
# Clean output
#
echo "Cleaning output dir ..."
mkdir -pv "${KX_DOC_OUT}"
cd "${KX_DOC_OUT}"
rm -rf *

#
# process CSS
#
echo "Processing CSS ..."

#echo java -jar /opt/share/java/js.jar /opt/share/lesscss/less-rhino.js -x \
#${KX_DOC_IN}/default.less ${KX_DOC_OUT}/default.css

java -jar /opt/share/java/js.jar /opt/share/lesscss/less-rhino.js -x \
${KX_DOC_TMP}/default.less ${KX_DOC_OUT}/default.css

#
# process HTACCESS and 404
#
echo "Processing .htaccess and 404 ..."
sed -e 's|@|http://kaarpux.kaarposoft.dk|' ${KX_DOC_IN}/htaccess.txt > ${KX_DOC_OUT}/.htaccess
cp ${KX_DOC_TMP}/404.html .

#
# process CVE list
#
echo "Processing CVE list ..."
${KX_DOC_IN}/cve.pl ${KX_BASE} ${KX_DOC_TMP}

#
# process packages
#
echo "Processing packages ..."
${KX_DOC_IN}/packages.pl ${KX_DOC_PKG} ${KX_DOC_TMP}

#
# where is the XSLT processor
#
XSLTPROC="/usr/bin/xsltproc"

#
# now generate the documentation
#
cp ${KX_DOC_TMP}/index.html .

#echo "Chunking"
#"${XSLTPROC}" --xinclude --output "${KX_DOC_TMP}/chunktoc.xml" "${KX_DOC_TMP}/kx_maketoc.xsl" "${KX_DOC_TMP}/kx.xml" 

echo "Generating documentation with XSLT ..."
"${XSLTPROC}" --xinclude "${KX_DOC_TMP}/kx_html.xsl" "${KX_DOC_TMP}/kx.xml" 

#
# leave no trace ...
#
rm -rf "${KX_DOC_TMP}"
#########echo "${KX_DOC_TMP}"
echo "Done generating documentation"


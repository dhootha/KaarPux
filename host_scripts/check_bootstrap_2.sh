#!/bin/sh
#
# KaarPux: http://kaarpux.kaarposoft.dk
#
# Copyright (C) 2012: Henrik Kaare Poulsen
#
# License: http://kaarpux.kaarposoft.dk/license.html
#

set -o nounset
set -o errexit

KX_BASE="$(cd $(dirname "$0")/..; pwd -P)"
. "${KX_BASE}/shinc/common_functions.shinc"
. "${KX_BASE}/shinc/definitions.shinc"
kx_ensure_runas_kxbuild

kx_echo "Test compiling"

cd /tmp
TEST_DIR="tool_chain_2_check"
rm -rf "${TEST_DIR}"
mkdir "${TEST_DIR}"
cd "${TEST_DIR}"
echo 'main(){}' > dummy.c
cc dummy.c

kx_echo "Verifying compilation"

readelf -l a.out | grep 'Requesting program interpreter' > check1.txt || kx_error_exit "No program interpreter"
cat check1.txt
grep "Requesting program interpreter: /tools/lib" check1.txt > /dev/null || kx_error_exit "Wrong program interpreter"

echo ""
kx_echo "OK"

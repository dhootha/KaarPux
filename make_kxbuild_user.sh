#!/bin/sh
#
# KaarPux: http://kaarpux.kaarposoft.dk
#
# Copyright (C) 2012: Henrik Kaare Poulsen
#
# License: http://kaarpux.kaarposoft.dk/license.html
#

# ============================================================
# Make the full www documentation tree
# ============================================================

set -o nounset
set -o errexit

KX_BASE="$(cd $(dirname "$0"); pwd -P)"
. "${KX_BASE}/shinc/common_functions.shinc"
. "${KX_BASE}/shinc/definitions.shinc"
kx_ensure_runas_root


id kxbuild 2>&1 >/dev/null || {
	kx_step_echo "Creating kxbuild user"
	groupadd --gid ${KX_BUILD_GID} kxbuild
	useradd \
		--gid ${KX_BUILD_GID} \
		--uid ${KX_BUILD_UID} \
		--comment "KaarPux Builder" \
		--shell "/bin/bash" \
		--create-home \
		--skel "${KX_BASE}/host_files/kxbuild_skel/" \
		kxbuild
}

kx_step_echo "Verifying kxbuild user"

id kxbuild || kx_error_exit "User [kxbuild] not found"
test $(id -u kxbuild) = ${KX_BUILD_UID} || kx_error_exit "User [kxbuild] does not have UID=[${KX_BUILD_UID}]"
diff "${KX_BASE}/host_files/kxbuild_skel/.bash_profile" ~kxbuild/.bash_profile || kx_error_exit "Wrong [.bash_profile] for user [kxbuild]"
diff "${KX_BASE}/host_files/kxbuild_skel/.bashrc" ~kxbuild/.bashrc || kx_error_exit "Wrong [.bashrc ] for user [kxbuild]"



#!/bin/bash
#
# KaarPux: http://kaarpux.kaarposoft.dk
#
# Copyright (C) 2013-2014: Henrik Kaare Poulsen
#
# License: http://kaarpux.kaarposoft.dk/license.html
#

set -o nounset
set -o errexit

if test "${1:-unset}" = "RECURSIVE_SH"; then
	shift
else

	test $(id -u) -eq 0 || { echo "*** *** This script must be run as root" >&2; exit 1; }

	if test -t 0 -a x"${1:-}" != x"--yes"; then
		cat <<EOF

------------------------------------------------------------
This script will build a bootable KaarPux system:
- partition and format target disk
- build the bootstrap phase
- install Grub
The script is intended to be run inside a virtual machine
where you want to install KaarPux with just one command.
You are advised to read through the script before executing.
Also modify settings in the top of the script as appropriate.
------------------------------------------------------------
EOF

		systemd-detect-virt --quiet --vm || { echo "*** You are NOT running in a virtual machine"; }

		read -r -p "Are you REALLY sure you want to continue? " DOIT
		case $DOIT in
			[yY][eE][sS]|[yY]) 
				;;
			*)
				echo "Aborting...."
				exit
			;;
		esac
		echo ""
	fi
	test x"${1:-}" = x"--yes" && shift

	"time" --verbose "$0" "RECURSIVE_SH" "$@"

	echo ""
	echo ------------------------------------------------------------
	echo ""
	echo "Now set a password for root and for kaarpux"
	echo ""
	echo "/mnt/kxmnt/home/kaarpux/kaarpux/bootstrap/host_scripts/enter_chroot.sh"
	echo "passwd root"
	echo "passwd kaarpux"
	echo "exit"
	echo ""

	exit
fi


# ============================================================

# Partition and format this device for KaarPux
FDEV=${1:-/dev/vdb}
DEV=${FDEV}1

# Device containing downloads
DDEV=${2:-/dev/vdc}

# Mount KaarPux target here
MNT=/mnt/kxmnt

# Who do we want to be
UNAME=kaarpux
USR=1000
GRP=1000

# Should we disable testing?
#DISABLE_TEST=""
DISABLE_TEST="yes"

# Should we keep core files in filesystem?
# (otherwise systemd-corectl may put them in the journal)
# Note that this is system-wide, not just for KaarPux build
SET_CORE_PATTERN=""
# Testing generates lots of cores, even if everything is OK,
# and some tests (eg. in elfutils) may fail if systemd "steals" the core files
test -n "${DISABLE_TEST}" || SET_CORE_PATTERN=yes

# Should we enable systemtap?
SYSTEMTAP=""
#SYSTEMTAP="yes"

# Should we build packages in parallel?
#PARALLEL=""
PARALLEL="yes"

# Tarball location
KAARPUX_TAR="$(cd "$(dirname "$0")/../.."; pwd -P)"
KAARPUX_TAR="${KAARPUX_TAR}/kaarpux.tar.gz"

# Build-directories in ram
# NOT RECOMMENDED when testing is enabled
# (as tmpfs does not implement the user prefix on extended attributes)
# USE_TMPFS=""
USE_TMPFS="yes"

# ============================================================

if { mount -l | grep "^${FDEV}"; } then
	echo "*** ${FDEV} is mounted!"
	exit 1
fi

# ============================================================

echo ------------------------------------------------------------
echo "Improved scheduling; errors are not fatal"

MULT=10
sysctl -w kernel.sched_min_granularity_ns=$(( MULT * 3000000)) || true
sysctl -w kernel.sched_latency_ns=$(( MULT * 24000000)) || true
sysctl -w kernel.sched_wakeup_granularity_ns=$(( MULT * 4000000)) || true
sysctl -w kernel.sched_migration_cost_ns=$(( MULT * 500000)) || true
sysctl -w kernel.sched_shares_window_ns=$(( MULT * 10000000)) || true
sysctl -w kernel.sched_child_runs_first=1 || true
sysctl -w kernel.sched_autogroup_enabled=0 || true

# batch scheduling
chrt -a -b -p 0 $$ || true

test -z "${SET_CORE_PATTERN}" || echo "core.%p" > /proc/sys/kernel/core_pattern

# ============================================================

echo ------------------------------------------------------------
echo "Default partitioning - legacy MBR style"

dd if=/dev/zero of="${FDEV}" bs=2048 count=1

fdisk ${FDEV} <<EOF
n
p
1


w
EOF
echo "done"


echo ------------------------------------------------------------
echo "Show disk layout"
fdisk -l ${FDEV}
echo "done"


echo ------------------------------------------------------------
echo "Disk formatting"

mke2fs -t ext4 -jv ${DEV}
fsck -a ${DEV}
echo "done"


echo ------------------------------------------------------------
echo "Mounting the target disk"
mkdir -pv ${MNT}
mount ${DEV} ${MNT}
echo deadline > /sys/block/${FDEV#/dev/}/queue/scheduler
echo "done"


echo ------------------------------------------------------------
echo "Preparing a home directory"

mkdir -pv ${MNT}/home/kaarpux/kaarpux
mkdir -pv ${MNT}/home/kaarpux/kaarpux/bootstrap/build/

if test -n "${USE_TMPFS}"; then
	mount -t tmpfs -o size=32G tmpfs ${MNT}/home/kaarpux/kaarpux/bootstrap/build/
fi

chown -R ${USR}:${GRP} ${MNT}/home/kaarpux/

cd ${MNT}/home/kaarpux/kaarpux
echo "done"


echo ------------------------------------------------------------
echo "Unpacking KaarPux"

su ${UNAME} <<EOF
mkdir -pv master
rm -rf master/*
tar xzf ${KAARPUX_TAR}
EOF
echo "done"

echo ------------------------------------------------------------
echo "Configuring KaarPux"

su  ${UNAME} <<EOF
cat > custom_definitions.shinc
KX_DISABLE_TEST="${DISABLE_TEST}"
KX_PARALLEL="${PARALLEL}"
KX_SYSTEMTAP="${SYSTEMTAP}"
KX_DEFINITIONS_CUSTOMIZED="yes"
KX_MALLOC_MALLOPT_KB=16384
EOF
echo "done"

echo ------------------------------------------------------------
echo "Creating KaarPux scripts"

su  ${UNAME} <<EOF
master/make_scripts.sh | tail -1
EOF
echo "done"


echo ------------------------------------------------------------
echo "Verifying the Host System Tools"

su ${UNAME} <<EOF
bootstrap/host_scripts/verify_host.sh
EOF
echo "done"

if test -n "${SYSTEMTAP}"; then
	echo ------------------------------------------------------------
	echo "Installing SystemTap script"
	bootstrap/chroot_scripts/install_kx_open_stp.sh
	echo "done"
fi

echo ------------------------------------------------------------
echo "Creating kxbuild user"

if ! master/make_kxbuild_user.sh; then
	echo "RETRYING"
	cp master/host_files/kxbuild_skel/.[a-z]* /home/kxbuild
	chown -R kxbuild:kxbuild /home/kxbuild
	master/make_kxbuild_user.sh
fi
echo "done"


echo ------------------------------------------------------------
echo "Making kxbuild the owner"

chown -R kxbuild:kxbuild "${MNT}/home/kaarpux/kaarpux"
echo "done"


echo ------------------------------------------------------------
echo "Downloading All Packages"

mkdir ${MNT}/home/kaarpux/kaarpux/downloads
fsck -a ${DDEV}
mount ${DDEV} ${MNT}/home/kaarpux/kaarpux/downloads
echo deadline > /sys/block/${DDEV#/dev/}/queue/scheduler
chown -R kxbuild:kxbuild ${MNT}/home/kaarpux/kaarpux/downloads

echo
echo I $(date +%F_%T) KX_DLD_STRT Downloading and verifying all packages
su  kxbuild <<EOF
linux/download_packages_2.sh > bootstrap/log/download.log 2>&1
EOF
echo I $(date +%F_%T) KX_DLD_DONE All packages downloaded and verified
echo


echo ------------------------------------------------------------
echo "Build bootstrap packages"
bootstrap/host_scripts/complete_bootstrap.sh
echo "done"


echo ------------------------------------------------------------
echo "Grub Setup"
bootstrap/host_scripts/enter_chroot.sh <<EOF
set -o nounset
set -o errexit
grub-install ${FDEV}
grub-mkconfig > /boot/grub/grub.cfg
EOF
echo "done"


echo ------------------------------------------------------------
echo "Change ownership and cleanup"

if test -n "${USE_TMPFS}"; then
	umount ${MNT}/home/kaarpux/kaarpux/bootstrap/build/
fi
bootstrap/host_scripts/enter_chroot.sh <<EOF
set -o nounset
set -o errexit
cd /home/kaarpux/kaarpux
chown -R kaarpux:kaarpux /home/kaarpux
rm -rf /tmp/*
EOF
umount ${MNT}/home/kaarpux/kaarpux/downloads

df -h >> build.log
uptime >> build.log

echo "done"
echo ""

echo ------------------------------------------------------------
echo "Bootstrap done"
echo ------------------------------------------------------------
echo ""


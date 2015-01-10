#!/bin/sh
#
# KaarPux: http://kaarpux.kaarposoft.dk
#
# Copyright (C) 2014: Henrik Kaare Poulsen
#
# License: http://kaarpux.kaarposoft.dk/license.html
#

# ============================================================
# INSTALL KAARPUX ON REMOTE MACHINE
# See http://kaarpux.kaarposoft.dk/copying_kaarpux_script_remote.html
# ============================================================

set -o nounset
set -o errexit

# ============================================================

usage () {
cat <<EOF
Usage:
$0: <LOCAL_IMG> <LOCAL_MNT> <REMOTE_IP> <REMOTE_PARTITION> <REMOTE_MNT> <REMOTE_KEEP>
EOF
}

# ============================================================

test $(id -u) -eq 0 || { echo "*** $0: must be run as root"; exit 1; }
test $# -eq 6 || { usage; exit 1; } 

LOCAL_IMG="$1"
LOCAL_MNT="$2"
REMOTE_IP="$3"
REMOTE_PARTITION="$4"
REMOTE_MNT="$5"
REMOTE_KEEP="$6"

case ${REMOTE_KEEP} in
	N|n|NO|No|no) REMOTE_KEEP=""
esac

REMOTE_USER=root
SSH="ssh -T -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_IP}"

# ============================================================

echo "==> checking local"
test -d ${LOCAL_MNT} || { echo "*** could not find mount point ${LOCAL_MNT}"; exit 1; }
findmnt ${LOCAL_MNT} && { echo "*** something is already mounted on ${LOCAL_MNT}"; exit 1; }
test -f ${LOCAL_IMG} || { echo "*** could not find image file ${LOCAL_IMG}"; exit 1; }
echo "... OK"

# ============================================================

echo "==> ping ${REMOTE_IP}"
ping -c1 -W10 ${REMOTE_IP} || { echo "*** could not ping ${REMOTE_IP}"; exit 1; }
echo "... OK"

echo "==> ssh to ${REMOTE_IP}"
$SSH id || { echo "*** could not log on to ${REMOTE_IP}"; exit 1; }
echo "... OK"

# ============================================================

echo "==> check for partition ${REMOTE_PARTITION} on ${REMOTE_IP}"
$SSH "test -b ${REMOTE_PARTITION}" || { echo "*** could not find partition ${REMOTE_PARTITION} on ${REMOTE_IP}"; exit 1; }
$SSH "if findmnt ${REMOTE_PARTITION}; then exit 1; else exit 0; fi" || \
	{ echo "*** partition ${REMOTE_PARTITION} on ${REMOTE_IP} is mounted"; exit 1; }
echo "... OK"

# ============================================================

if test -z "${REMOTE_KEEP}"; then
	echo "... NOT keeping home directories and important /etc files"
else
	echo "==> mounting ${REMOTE_PARTITION} on ${REMOTE_MNT} on ${REMOTE_IP}"
	$SSH "mount ${REMOTE_PARTITION} ${REMOTE_MNT}" || \
		{ echo "*** could not mount ${REMOTE_PARTITION} on ${REMOTE_MNT} on ${REMOTE_IP}"; exit 1; }
	echo "... OK"

	echo "==> keeping files from ${REMOTE_PARTITION} on ${REMOTE_IP}"
	echo "    (may output 'stdin: is not a tty' which can be ignored)"
	T=$($SSH mktemp --tmpdir remote_install_keep.tar.gz.XXXXXX)
	$SSH <<-EOF > /dev/null || { echo "*** could create tar archive $T on ${REMOTE_IP}"; exit 1; }
	set -o nounset
	set -o errexit
	tar czf $T --format=pax --anchored \
	  --exclude 'home/*/.cache' \
	  --exclude 'home/*/.thumbnails' \
	  --exclude 'home/*/.java/fonts' \
	  --exclude 'home/*/.local/share/Trash' \
	  --exclude 'home/*/Downloads' \
	  --exclude 'home/kaarpux' \
	-C /mnt \
	  home \
	  etc/passwd \
	  etc/shadow \
	  etc/group \
	  etc/gshadow \
	  etc/fstab \
	  etc/hostname \
	  etc/NetworkManager/system-connections
	EOF
	echo "... OK"

	echo "==> un-mounting ${REMOTE_MNT} on ${REMOTE_IP}"
	$SSH "umount ${REMOTE_MNT}" || \
		{ echo "*** could not un-mount ${REMOTE_MNT} on ${REMOTE_IP}"; exit 1; }
	echo "... OK"
	
fi

# ============================================================

echo "==> formatting ${REMOTE_PARTITION} on ${REMOTE_IP}"
echo "    (may output 'stdin: is not a tty' which can be ignored)"
$SSH <<-EOF || { echo "*** could not format ${REMOTE_PARTITION} on ${REMOTE_IP}"; exit 1; }
	set -o nounset
	set -o errexit
	mke2fs -t ext4 -jv ${REMOTE_PARTITION}
	fsck -a ${REMOTE_PARTITION}
	EOF
echo "... OK"

# ============================================================

echo "==> mounting ${REMOTE_PARTITION} on ${REMOTE_MNT} on ${REMOTE_IP}"
$SSH "mount ${REMOTE_PARTITION} ${REMOTE_MNT}" || \
	{ echo "*** could not mount ${REMOTE_PARTITION} on ${REMOTE_MNT} on ${REMOTE_IP}"; exit 1; }
echo "... OK"

# ============================================================

echo "==> loop mounting image"
mount -v -o loop,offset=$((2048 * 512)) ${LOCAL_IMG} ${LOCAL_MNT}
echo "... OK"

# ============================================================

echo "==> installing KaarPux (this may take some time...)"
tar cf - --format=pax -C ${LOCAL_MNT} . | pigz -4 --stdout - | 
$SSH -o ServerAliveInterval=10 tar xzf - -C ${REMOTE_MNT}
echo "... seems OK"

# ============================================================

if test -z "${REMOTE_KEEP}"; then
	echo "... No kept files to install"
else
	echo "==> installing kept files"
	$SSH tar xf $T -C /mnt --numeric-owner
	$SSH rm $T
	echo "... OK"
fi

# ============================================================

echo "==> tweaking"
echo "    (may output 'stdin: is not a tty' which can be ignored)"
$SSH <<-EOF || { echo "*** tweaking ${REMOTE_IP} failed"; exit 1; }
	set -o nounset
	set -o errexit
	set -o xtrace
	UUID=\$(blkid -s UUID -o value ${REMOTE_PARTITION})
	sed "s!^[[:blank:]]*[^[:blank:]]\+[[:blank:]]\+/[[:blank:]]\+!UUID=\$UUID / !" -i /mnt/etc/fstab
	ln -svf /lib/systemd/system/graphical.target /mnt/etc/systemd/system/default.target
	ln -svf /lib/systemd/system/gdm.service /mnt/etc/systemd/system/display-manager.service
	rm -f /mnt/etc/systemd/system/multi-user.target.wants/systemd-networkd.service
	ln -svf '/lib/systemd/system/NetworkManager.service' '/mnt/etc/systemd/system/dbus-org.freedesktop.NetworkManager.service'
	ln -svf '/lib/systemd/system/NetworkManager.service' '/mnt/etc/systemd/system/multi-user.target.wants/NetworkManager.service'
	ln -svf '/lib/systemd/system/NetworkManager-dispatcher.service' '/mnt/etc/systemd/system/dbus-org.freedesktop.nm-dispatcher.service'
	EOF
echo "... OK"

# ============================================================

echo "==> settings for grub"
echo "    (may output 'stdin: is not a tty' which can be ignored)"
$SSH <<-EOF || { echo "*** tweaking ${REMOTE_IP} failed"; exit 1; }
	set -o nounset
	set -o errexit
	set -o xtrace
	UUID=\$(blkid -s UUID -o value ${REMOTE_PARTITION})
	LINUX=\$(cd /mnt/boot; ls vmlinuz* | cut -c9-)
	set +o xtrace
	sleep 1
	echo "========================================"
	cat <<-EOF2
		menuentry 'KaarPux ' --class gnu-linux --class gnu --class os \\\$menuentry_id_option 'gnulinux-simple-\$UUID' {
			load_video
			set gfxpayload=keep
			insmod gzio
			insmod part_gpt
			insmod ext2
			search --no-floppy --fs-uuid --set=root \$UUID
			echo    'Loading Linux \$LINUX ...'
			linux   /boot/vmlinuz-\$LINUX root=UUID=\$UUID
			echo    'Loading initial ramdisk ...'
			initrd  /boot/initramfs-\$LINUX.img
		}
	EOF2
	echo "========================================"
EOF
echo "==> you should configure grub on the remote machine,"
echo "==> either by using the distro's grub configuration update utilities,"
echo "==> or by adding the above to the grub.cfg file"
echo "========================================"

# ============================================================

echo "==> un-mounting ${REMOTE_MNT} on ${REMOTE_IP}"
$SSH "umount ${REMOTE_MNT}" || \
	{ echo "*** could not un-mount ${REMOTE_MNT} on ${REMOTE_IP}"; exit 1; }
echo "... OK"

# ============================================================

echo "==> un-mounting loop image"
umount ${LOCAL_MNT}
echo "... OK"

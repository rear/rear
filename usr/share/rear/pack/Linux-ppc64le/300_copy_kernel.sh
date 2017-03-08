# 300_copy_kernel.sh
#
# copy kernel for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# find and copy kernel
# we only try to find the currently running kernel
# Using another kernel is a TODO for now

if [ ! -s "$KERNEL_FILE" ]; then
	if [ -r "/boot/vmlinuz-$KERNEL_VERSION" ]; then
		KERNEL_FILE="/boot/vmlinuz-$KERNEL_VERSION"
	elif has_binary get_kernel_version; then
		for src in /boot/* ; do
			if VER=$(get_kernel_version "$src") && test "$VER" == "$KERNEL_VERSION" ; then
				KERNEL_FILE="$src"
				break
			fi
		done
	elif [ -f /etc/redhat-release ]; then
		# GD - kernel not found under /boot - 19/May/2008
		# check under /boot/efi/efi/redhat (for Red Hat)
		[ -f "/boot/efi/efi/redhat/vmlinuz-$KERNEL_VERSION" ]
		StopIfError "Could not find a matching kernel in /boot/efi/efi/redhat !"
		KERNEL_FILE="/boot/efi/efi/redhat/vmlinuz-$KERNEL_VERSION"
	elif [ -f /etc/debian_version ]; then
		[ -f "/boot/vmlinux-$KERNEL_VERSION" ]
		StopIfError "Could not find a matching kernel in /boot (debian) !"
		KERNEL_FILE="/boot/vmlinux-$KERNEL_VERSION"
	else
		Error "Could not find a matching kernel in /boot !"
	fi
fi

[ -s "$KERNEL_FILE" ]
StopIfError "Could not find a suitable kernel. Maybe you have to set KERNEL_FILE [$KERNEL_FILE] ?"

if [ -L $KERNEL_FILE ]; then
    KERNEL_FILE=$(readlink -f $KERNEL_FILE)
fi

Log "Found kernel $KERNEL_FILE"
#cp -aL $v "$KERNEL_FILE" "$TMP_DIR/kernel" >&2

# 300_copy_kernel.sh
#
# copy kernel for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# find and copy kernel
# we only try to find the currently running kernel
# Using another kernel is a TODO for now

# debian version
#
# note: needs to be verified with non-debian (ubuntu ?) !!
#

# if KERNEL_FILE is not a file, search for a kernel under /boot
if [ ! -s "$KERNEL_FILE" ]; then
	if [ -r "/boot/efi/efi/debian/vmlinuz-$KERNEL_VERSION" ]; then
		# guess kernel
		KERNEL_FILE="/boot/efi/efi/debian/vmlinuz-$KERNEL_VERSION"
	elif has_binary get_kernel_version; then
		# if we have get_kernel_version, search for probably matching kernel file
		for src in $(find /boot -type f) ; do
			if VER=$(get_kernel_version "$src") && test "$VER" == "$KERNEL_VERSION" ; then
				KERNEL_FILE="$src"
				break
			fi
		done
	else
		Error "Could not find a matching kernel in /boot !"
	fi
fi

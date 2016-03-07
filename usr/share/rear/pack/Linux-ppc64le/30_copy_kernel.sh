# 30_copy_kernel.sh
#
# copy kernel for Relax-and-Recover
#
#    Relax-and-Recover is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    Relax-and-Recover is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Relax-and-Recover; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#

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

# 30_copy_kernel.sh
#
# copy kernel for Relax & Recover
#
#    Relax & Recover is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    Relax & Recover is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Relax & Recover; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#

# find and copy kernel
# we only try to find the currently running kernel
# Using another kernel is a TODO for now

if ! test -s "$KERNEL_FILE" ; then
	if test -r "/boot/vmlinuz-$KERNEL_VERSION" ; then
		KERNEL_FILE="/boot/vmlinuz-$KERNEL_VERSION"
		Print "Using kernel $KERNEL_FILE"
	elif test "$(type -p get_kernel_version)" ; then
		for k in /boot/* ; do
			if VER=$(get_kernel_version "$k") && test "$VER" == "$KERNEL_VERSION" ; then
				KERNEL_FILE="$k"
				Print "Found kernel $KERNEL_FILE"
				break
			fi
		done
	elif test -f /etc/redhat-release ; then
		# GD - kernel not found under /boot - 19/May/2008
		# check under /boot/efi/efi/redhat (for Red Hat)
		if [ -f "/boot/efi/efi/redhat/vmlinuz-$KERNEL_VERSION" ] ; then
			KERNEL_FILE="/boot/efi/efi/redhat/vmlinuz-$KERNEL_VERSION"
			Print "Found kernel $KERNEL_FILE"
		else
			Error "Could not find a matching kernel in /boot/efi/efi/redhat !"
		fi
	elif test -f /etc/debian_version ; then
		if [ -f "/boot/efi/efi/debian/vmlinuz-$KERNEL_VERSION" ] ; then
			KERNEL_FILE="/boot/efi/efi/debian/vmlinuz-$KERNEL_VERSION"
			Print "Found kernel $KERNEL_FILE"
		else
			Error "Could not find a matching kernel in /boot/efi/efi/debian !"
		fi
	elif test -f /etc/arch-release ; then
		if [ -f "/boot/vmlinuz26" ] ; then
			KERNEL_FILE="/boot/vmlinuz26"
			Print "Found kernel $KERNEL_FILE"
		else
			Error "Could not find Arch kernel /boot/vmlinuz26"
		fi
	else
		Error "Could not find a matching kernel in /boot !"
	fi
fi
if ! test -s "$KERNEL_FILE" ; then
	Error "Could not find a suitable kernel. Maybe you have to set KERNEL_FILE [$KERNEL_FILE] ?"
fi
cp -aL "$KERNEL_FILE" "$BUILD_DIR/kernel" 


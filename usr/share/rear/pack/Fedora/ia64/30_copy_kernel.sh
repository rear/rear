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

# centos / rhel version
#
# note: needs to be verified with non-rhel !!
#

# if KERNEL_FILE is not a file, search for a kernel under /boot
if [ ! -s "$KERNEL_FILE" ]; then
	if [ -r "/boot/efi/efi/redhat/vmlinuz-$KERNEL_VERSION" ]; then
		# guess kernel
		KERNEL_FILE="/boot/efi/efi/redhat/vmlinuz-$KERNEL_VERSION"
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

# if KERNEL_FILE is still not a valid file, complain
[ -s "$KERNEL_FILE" ]
StopIfError "Could not find a suitable kernel. Maybe you have to set KERNEL_FILE [$KERNEL_FILE] ?"

if [ -L $KERNEL_FILE ]; then
    KERNEL_FILE=$(readlink -f $KERNEL_FILE)
fi

Log "Found kernel $KERNEL_FILE"
#cp -aL $v "$KERNEL_FILE" "$TMP_DIR/kernel" >&2

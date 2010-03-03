# #80_copy_to_usb_dir.sh
#
# copy kernel and initrd to USB dir for Relax & Recover
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

# define the filenames
USB_KERNEL=kernel
USB_INITRD=initrd.sys
USB_MESSAGE=message.txt

if ! test -d "$USB_DIR" ; then
	mkdir -vp "$USB_DIR" || Error "Could not create USB dir [$USB_DIR] !"
fi

cp -a "$BUILD_DIR"/kernel "$USB_DIR/$USB_KERNEL"
cp -a "$BUILD_DIR"/initrd "$USB_DIR/$USB_INITRD"

echo "$VERSION_INFO" >"$USB_DIR/$USB_MESSAGE"

Log "Copied $USB_KERNEL and $USB_INITRD to $USB_DIR"

# Add to USB_FILES
USB_FILES=( "${USB_FILES[@]}" "$USB_DIR/$USB_KERNEL" "$USB_DIR/$USB_INITRD" "$USB_DIR/$USB_MESSAGE" )

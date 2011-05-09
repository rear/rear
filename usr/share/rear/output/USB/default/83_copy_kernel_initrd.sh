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

cp -v "$BUILD_DIR/kernel" "$BUILD_DIR/usbfs/$USB_BOOT_PREFIX/kernel" >&8 || Error "Could not create $BUILD_DIR/usbfs/$USB_BOOT_PREFIX/kernel"

cp -v "$BUILD_DIR/initrd.cgz" "$BUILD_DIR/usbfs/$USB_BOOT_PREFIX/initrd.cgz" >&8 || Error "Could not create $BUILD_DIR/usbfs/$USB_BOOT_PREFIX/initrd.cgz"

Log "Copied kernel and initrd.cgz to $BUILD_DIR/usbfs/$USB_BOOT_PREFIX/"

# Add to RESULT_FILES for emailing it
RESULT_FILES=( "${RESULT_FILES[@]}" "${USB_FILES[@]}" "$BUILD_DIR/kernel" "$BUILD_DIR/initrd.cgz" )

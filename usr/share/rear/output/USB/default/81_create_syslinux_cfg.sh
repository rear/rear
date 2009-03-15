# #81_create_syslinux_cfg.sh
#
# create syslinux config on PXE server for Relax & Recover
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

# we got USB_KERNEL and USB_INITRD set in the previous script

cat >"$USB_DIR/syslinux.cfg" <<EOF
$(test -s $CONFIG_DIR/templates/USB_syslinux.cfg && cat $CONFIG_DIR/templates/USB_syslinux.cfg)
display $USB_MESSAGE
say ----------------------------------------------------------
say rear = disaster recover this system with Relax & Recover
label rear
	kernel $USB_KERNEL
	append initrd=$USB_INITRD root=/dev/ram0 vga=normal rw $KERNEL_CMDLINE
EOF

Log "Created syslinux.cfg in $USB_DIR"

# Add to USB_FILES files
USB_FILES=( "${USB_FILES[@]}" "$USB_DIR/syslinux.cfg" )

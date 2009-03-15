# #30_create_isolinux.sh
#
# create isolinux.cfg for Relax & Recover
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

# finding isolinux.bin is now done in the prep stage, not here.
# therefore ISO_ISOLINUX_BIN for sure contains the full path to isolinux.bin
cp -L "$ISO_ISOLINUX_BIN" $BUILD_DIR/isolinux.bin 

echo "$VERSION_INFO" >$BUILD_DIR/message

cat >"$BUILD_DIR/isolinux.cfg" <<EOF
$(test -s $CONFIG_DIR/templates/ISO_isolinux.cfg && cat $CONFIG_DIR/templates/ISO_isolinux.cfg)
display message
say ----------------------------------------------------------                                                 
say rear = disaster recover this system with Relax & Recover                                                   

label rear
	kernel kernel
	append initrd=initrd root=/dev/ram0 vga=normal rw $KERNEL_CMDLINE
EOF

ISO_FILES=( "${ISO_FILES[@]}" message isolinux.bin isolinux.cfg )

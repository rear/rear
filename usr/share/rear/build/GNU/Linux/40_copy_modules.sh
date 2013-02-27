# #40_copy_modules.sh
#
# copy kernel modules for Relax-and-Recover
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

Log "Collecting modules for kernel version $KERNEL_VERSION"
MODFILES=(
$( ResolveModules "$KERNEL_VERSION" "${MODULES[@]}" "${MODULES_LOAD[@]}"  )
)
StopIfError "Could not resolve kernel module dependancies"

# copy modules & depmod
LogPrint "Copying kernel modules"
ModulesCopyTo "$ROOTFS_DIR" "${MODFILES[@]}" >&8
StopIfError "Could not copy kernel modules"

depmod -avb "$ROOTFS_DIR" "$KERNEL_VERSION" >&8
StopIfError "Could not configure modules with depmod"

for m in "${MODULES_LOAD[@]}" ; do
    echo $m
done >>$ROOTFS_DIR/etc/modules

# avoid duplicates in etc/modules
cat $ROOTFS_DIR/etc/modules | sort -u > $ROOTFS_DIR/etc/modules.new
mv -f $ROOTFS_DIR/etc/modules.new  $ROOTFS_DIR/etc/modules

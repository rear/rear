# #40_copy_modules.sh
#
# copy kernel modules for Relax & Recover
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

Log "Collecting modules for kernel version $KERNEL_VERSION"
LogPrint "Copy kernel modules"
MODFILES=(
$( ResolveModules "$KERNEL_VERSION" "${MODULES[@]}" "${MODULES_LOAD[@]}"  )
)
StopIfError "Could not resolve kernel module dependancies"

# copy modules & depmod
Log "Copying kernel modules"
ModulesCopyTo "$ROOTFS_DIR" "${MODFILES[@]}" 1>&8 
StopIfError "Could not copy kernel modules"

depmod -avb "$ROOTFS_DIR" "$KERNEL_VERSION" 1>&8 
StopIfError "Could not configure modules with depmod"

for m in "${MODULES_LOAD[@]}" ; do
	echo $m
done >>$ROOTFS_DIR/etc/modules


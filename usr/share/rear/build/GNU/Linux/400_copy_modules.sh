# 400_copy_modules.sh
#
# copy kernel modules for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

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

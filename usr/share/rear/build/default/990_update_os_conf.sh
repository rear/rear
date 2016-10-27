# add os/version info to os.conf in the rescue system so that we don't need to pull lsb into the rescue system

echo -e "#\n# WARNING ! This information was added automatically by the $WORKFLOW workflow !!!" >> $ROOTFS_DIR/etc/rear/os.conf
for var in ARCH OS OS_VERSION OS_VENDOR OS_VENDOR_VERSION OS_VENDOR_ARCH ; do
	echo "$var='${!var}'"
done >> $ROOTFS_DIR/etc/rear/os.conf

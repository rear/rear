# add os/version info to os.conf in the rescue system so that we don't need to pull lsb into the rescue system

echo -e "#\n# WARNING ! This information was added automatically by the $WORKFLOW workflow !!!" >> $ROOTFS_DIR$CONFIG_DIR/os.conf
declare -p ARCH OS OS_VERSION OS_VENDOR >> $ROOTFS_DIR$CONFIG_DIR/os.conf 2>/dev/null

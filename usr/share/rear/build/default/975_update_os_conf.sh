# Add os/version info to os.conf in the rescue system
# so that we don't need to pull 'lsb_release' into the rescue system
# cf. the SetOSVendorAndVersion function in lib/config-functions.sh
# see pull #2142 https://github.com/rear/rear/pull/2142#issuecomment-506900480
# add OS_MASTER_VENDOR to os.conf

local rescue_system_os_conf_file="$ROOTFS_DIR/etc/rear/os.conf"
echo "# The following information was added automatically by the $WORKFLOW workflow:" >> $rescue_system_os_conf_file
for var in ARCH OS OS_VERSION OS_VENDOR OS_VENDOR_VERSION OS_VENDOR_ARCH OS_MASTER_VENDOR ; do
    echo "$var='${!var}'"
done >> $rescue_system_os_conf_file
echo "# End of what was added automatically by the $WORKFLOW workflow." >> $rescue_system_os_conf_file


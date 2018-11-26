# Add os/version info to os.conf in the rescue system
# so that we don't need to pull 'lsb_release' into the rescue system
# cf. the SetOSVendorAndVersion function in lib/config-functions.sh

local rescue_system_os_conf_file="$ROOTFS_DIR/etc/rear/os.conf"
echo "# The following information was added automatically by the $WORKFLOW workflow:" >> $rescue_system_os_conf_file
for var in ARCH OS OS_VERSION OS_VENDOR OS_VENDOR_VERSION OS_VENDOR_ARCH ; do
    echo "$var='${!var}'"
done >> $rescue_system_os_conf_file
echo "# End of what was added automatically by the $WORKFLOW workflow." >> $rescue_system_os_conf_file


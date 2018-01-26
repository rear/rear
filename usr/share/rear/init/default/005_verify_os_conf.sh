# usr/share/rear/init/default/005_verify_os_conf.sh
# Purpose is to verify if the /etc/rear/os.conf file has been created already and if this is the first time
# then we will create a new os.conf file with the values found by the main script 'rear' (via the function
# SetOSVendorAndVersion)
if [[ ! -f "$CONFIG_DIR/os.conf" ]] ; then
    echo "OS_VENDOR=$OS_VENDOR"    > "$CONFIG_DIR/os.conf"
    echo "OS_VERSION=$OS_VERSION" >> "$CONFIG_DIR/os.conf"
    Log "Created the $CONFIG_DIR/os.conf file with content:"
    cat "$CONFIG_DIR/os.conf" >&2
fi

# usr/share/rear/init/default/005_verify_os_conf.sh

# Skip if etc/rear/os.conf already exists:
test -f "$CONFIG_DIR/os.conf" && return

# If there is none create etc/rear/os.conf with the values set
# by SetOSVendorAndVersion() that was called in usr/sbin/rear:
echo "OS_VENDOR=$OS_VENDOR" > "$CONFIG_DIR/os.conf"
echo "OS_VERSION=$OS_VERSION" >> "$CONFIG_DIR/os.conf"
Log "Created $CONFIG_DIR/os.conf with content:"
cat "$CONFIG_DIR/os.conf"

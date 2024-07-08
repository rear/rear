#
# create a systemd service file for the bareos-fd
# based on the existing one.
# Remove Requires, as these not available in the rescue environment,
# and add -r option to the bareos-fd.
# -r: Restore only mode. (Backup jobs will fail).
#

local bareos_fd_service
bareos_fd_service="$( systemctl cat bareos-fd.service )"
sed -r -e '/^Requires=/d' -e 's|^(ExecStart=.*bareos-fd .*)$|\1 -r|' <<< "$bareos_fd_service" > "$ROOTFS_DIR/usr/lib/systemd/system/bareos-fd.service"

# we can write stuff to $CONFIG_DIR/rescue.conf if we want to preserve some dynamic variables
# so that they stay static in the rescue system. static means they stay the same as when the
# rescue system was created.

cat - <<EOF >> "$ROOTFS_DIR/etc/rear/rescue.conf"
# initialize our /etc/rear/rescue.conf file sourced by the rear command in recover mode
# also the configuration is sourced by system-setup script during booting our recovery image

EOF

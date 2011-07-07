# keep the RSYNC_vars (except for RSYNC_OPTIONS as being rebuild dynamically)
declare -p ${!RSYNC*} | sed -e 's/declare .. //' | grep -v RSYNC_OPTIONS >>$ROOTFS_DIR$CONFIG_DIR/rescue.conf

# keep the RSYNC_vars (except for BACKUP_RSYNC_OPTIONS as being rebuild dynamically)
declare -p ${!RSYNC*} | sed -e 's/declare .. //' | grep -v BACKUP_RSYNC_OPTIONS >>$ROOTFS_DIR/etc/rear/rescue.conf

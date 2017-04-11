
# Store all currently set NETFS* variables into /etc/rear/rescue.conf in the ReaR recovery system.
echo "All set NETFS_* variables (cf. rescue/NETFS/default/600_store_NETFS_variables.sh):" >> $ROOTFS_DIR/etc/rear/rescue.conf
set | grep '^NETFS_' >>$ROOTFS_DIR/etc/rear/rescue.conf
echo "" >> $ROOTFS_DIR/etc/rear/rescue.conf


# copy current unfinished logfile to initramfs for debug purpose

Log "Copying logfile $LOGFILE into initramfs as '/tmp/rear-original-$LOGFILE'"
mkdir -p $ROOTFS_DIR/tmp
cp -a $LOGFILE $ROOTFS_DIR/tmp/rear-original-$LOGFILE

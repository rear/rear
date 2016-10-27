# copy current unfinished logfile to initramfs for debug purpose

Log "Copying logfile $LOGFILE into initramfs as '/tmp/rear-partial-$(date -Iseconds).log'"
mkdir -p $v $ROOTFS_DIR/tmp >&2
cp -a $v $LOGFILE $ROOTFS_DIR/tmp/rear-partial-$(date -Iseconds).log >&2

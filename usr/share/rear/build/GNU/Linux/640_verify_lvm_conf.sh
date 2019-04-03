# build/GNU/Linux/640_verify_lvm_conf.sh
# Purpose is to turn off the "WARNING: Failed to connect to lvmetad. Falling back to device scanning"  in the output during
# the 'rear recover' process - see issue https://github.com/rear/rear/issues/2044 for more details

if test -f $ROOTFS_DIR/etc/lvm/lvm.conf ; then
    sed -i 's/use_lvmetad =.*/use_lvmetad = 0/' $ROOTFS_DIR/etc/lvm/lvm.conf
fi

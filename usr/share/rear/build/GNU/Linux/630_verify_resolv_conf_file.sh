# Because of issue #1200 and #520 where /etc/resol.conf is linked to /run/resolvconf/resolv.conf
# We need to remove the link and cat the content into /etc/resolv.conf (Ubuntu)
if [[ -h $ROOTFS_DIR/etc/resolv.conf ]] ; then
    rm -f $ROOTFS_DIR/etc/resolv.conf
    cp $v /etc/resolv.conf  $ROOTFS_DIR/etc/resolv.conf >&2
fi

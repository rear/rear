grep -q blocks /proc/mdstat 2>/dev/null || return 0

# Include /etc/mdadm.conf without building arrays automatically
# for the reason behind see
# https://github.com/rear/rear/issues/1722#issuecomment-394746478
if [ -e "/etc/mdadm.conf" ] ; then
	(
		echo "AUTO -all"
		sed "s/^ARRAY/#ARRAY/g" /etc/mdadm.conf
	) > $ROOTFS_DIR/etc/mdadm.conf
fi
# Ubuntu has /etc/mdadm/mdadm.conf instead of /etc/mdadm.conf
if [ -e "/etc/mdadm/mdadm.conf" ] ; then
        [[ ! -d $ROOTFS_DIR/etc/mdadm ]] && \
             mkdir -m 0755 $ROOTFS_DIR/etc/mdadm
        (
                echo "AUTO -all"
                sed "s/^ARRAY/#ARRAY/g" /etc/mdadm/mdadm.conf
        ) > $ROOTFS_DIR/etc/mdadm/mdadm.conf
fi

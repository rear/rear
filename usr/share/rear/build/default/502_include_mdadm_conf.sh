grep -q blocks /proc/mdstat 2>/dev/null || return 0

# Include /etc/mdadm.conf without building arrays automatically
if [ -e "/etc/mdadm.conf" ] ; then
	(
		echo "AUTO -all"
		sed "s/^ARRAY/#ARRAY/g" /etc/mdadm.conf
	) > $ROOTFS_DIR/etc/mdadm.conf
fi

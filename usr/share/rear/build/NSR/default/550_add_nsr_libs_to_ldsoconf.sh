# 55_add_nsr_libs_to_ldsoconf.sh
if [[ -f $ROOTFS_DIR/etc/ld.so.conf ]]; then
     Log "Add NSR library paths to etc/ld.so.conf"
     cat >> $ROOTFS_DIR/etc/ld.so.conf <<-EOD
	/usr/lib/nsr
	/usr/lib/nsr/lib64
	EOD
fi

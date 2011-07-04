# rebuild the initramfs if the drivers changed
#
# probably not required, but I prefer to rely on this information when it
# is backed by udev
have_udev || return 0

# check if we need to do something
if test -s $TMP_DIR/storage_drivers && ! diff $TMP_DIR/storage_drivers $VAR_DIR/recovery/storage_drivers >&8 ; then
	# remember, diff returns 0 if the files are the same

	# merge new drivers with previous initrd modules
	# BUG: we only add modules to the initrd, we don't take old ones out
	#      could be done better, but might not be worth the risk
	INITRD_MODULES="$( sort -t " " -k 1 -u $TMP_DIR/storage_drivers /mnt/local/etc/initramfs-tools/module[s] )"
	# use [] to skip file if it does not exist
	# -t " " -k 1 tries to keep the comments unsorted

	echo "$INITRD_MODULES" >/mnt/local/etc/initramfs-tools/modules

	mount -t proc none /mnt/local/proc
	mount -t sysfs none /mnt/local/sys
	# handle mdadm.conf Debian style
	if [ -r /proc/mdstat -a -r /mnt/local/etc/mdadm/mdadm.conf -a -x /mnt/local/usr/share/mdadm/mkconf ] ; then
		if chroot /mnt/local /bin/bash --login -c "/usr/share/mdadm/mkconf >/etc/mdadm/mdadm.conf" ; then
			LogPrint "Updated '/etc/mdadm/mdadm.conf'"
		else
			LogPrint "WARNING !!!
Could not update /etc/mdadm/mdadm.conf with the new MD Array information.
Your system might not boot if the MD Arrays are required for booting due
to changed MD Array UUIDs or other details.

Please 'chroot /mnt/local' and try to fix this. You should also run
update-initramfs afterwards to update the initramfs with the new mdadm.conf
"
		fi
	fi

	if chroot /mnt/local /bin/bash --login -c "update-initramfs -v -u -k all" >&2 ; then
		LogPrint "Updated initramfs with new drivers for this system."
	else
		LogPrint "WARNING !!!
initramfs creation failed, please check '$LOGFILE' to see the error
messages in detail and decide yourself, wether the system will boot or not.
"
	fi
	umount /mnt/local/proc /mnt/local/sys

fi

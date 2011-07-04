# run the recovery/mkbootloader script chrooted
#
LogPrint "Restoring the bootloader (SuSE style)"
if bootloader="$(cat $VAR_DIR/recovery/mkbootloader)"  ; then
	mount -t proc none /mnt/local/proc
	# if the device.map contains /dev/disk/by-id... we move the file and
	# hope for the best
	if grep -q "/dev/disk/by-id"  /mnt/local/boot/grub/device.map ; then
		LogPrint "WARNING !
			Your system.map contains a reference to a disk by UUID, which does
			not work at the moment. I will copy the file to device.map.rear and try
			to autoprobe the correct device. If this fails you might have to manually
			reinstall your bootloader"
		mv /mnt/local/boot/grub/device.map /mnt/local/boot/grub/device.map.rear
	fi
	Log "Running chroot '$bootloader'"
	if chroot /mnt/local /bin/bash --login -c "$bootloader"  >&2 ; then
		NOBOOTLOADER=
	else
		LogPrint "WARNING !
	Could not run content of '$VAR_DIR/recovery/mkbootloader'

	The boot loader might not be installed properly, check $LOGFILE for
	more details about this. You might have to re-install the bootloader
	manually to get this system to boot"
	fi
	umount /mnt/local/proc
else

	LogPrint "WARNING !
	Could not find '$VAR_DIR/recovery/mkbootloader'

	You have to install a boot loader yourself MANUALLY, otherwise the
	system will not be booting !!!
"
fi

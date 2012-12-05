# run the recovery/mkbootloader script chrooted
#
LogPrint "Restoring the bootloader (SuSE style)"
if bootloader="$(cat $VAR_DIR/recovery/mkbootloader)"  ; then
	mount -t proc none /mnt/local/proc
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

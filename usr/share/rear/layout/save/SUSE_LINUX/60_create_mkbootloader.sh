#
# create recovery/mkbootloader script file
# this script file is then executed in a chroot'ed eval() environment
#
# for SuSE Linux

. /etc/sysconfig/bootloader

case "$LOADER_TYPE" in
	GRUB|grub)
		[ -s /etc/grub.conf ]
		LogPrintIfError "GRUB selected as boot loader in '/etc/sysconfig/bootloader',
	but '/etc/grub.conf' doesn't contain any data !
	I don't know how to restore the boot loader on your system. You will
	have to restore the boot loader MANUALLY after the restore !!!
"
		echo "grub --batch </etc/grub.conf"
		COPY_AS_IS=( "${COPY_AS_IS[@]}" /etc/grub.conf )
		Log "Using boot loader GRUB"
	;;
	LILO|lilo)
		echo "lilo"
		Log "Using boot loader LILO"
	;;
	*)
		Error "Unknown boot loader $LOADER_TYPE found in '/etc/sysconfig/bootloader'"
	;;
esac >$VAR_DIR/recovery/mkbootloader

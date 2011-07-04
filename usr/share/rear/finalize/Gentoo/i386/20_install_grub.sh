#
# Gentoo uses grub by default. There is no information stored in the system about the boot
# loader installation, so we can only guess and try to install grub.
LogPrint "Installing boot loader (I hope you used grub and it works ...)"
mount -t proc none /mnt/local/proc
if chroot /mnt/local /bin/bash --login -c "grub-install '(hd0)'" >&2 ; then
	NOBOOTLOADER=
else
	LogPrint "WARNING !!!
	grub installation failed, please check '$LOGFILE' to see the error
	message and decide yourself, wether the system will boot or not.

	You also might consider to improve this script so that this won't happen again:
	$SHARE_DIR/finalize/Gentoo/i386/20_install_grub.sh"
fi
umount /mnt/local/proc

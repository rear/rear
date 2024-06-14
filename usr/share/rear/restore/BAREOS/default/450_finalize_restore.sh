mkdir $TARGET_FS_ROOT/var/lib/bareos && chroot $TARGET_FS_ROOT chown bareos: /var/lib/bareos

LogPrint "Bareos restore finished."

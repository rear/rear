# rebuild the initramfs if the drivers changed
#
# probably not required, but I prefer to rely on this information when it is backed by udev
# FIXME: who is 'I'?
# Perhaps Schlomo Schapiro or someone who made the "P2V patch from Heinlein Support"?
# (see commit 844d50b75ac4b7722f4fee7a5ee3350b93f3adb7)
# And what happens if there is no 'have_udev'? Why is everything o.k. then to just 'return 0'?
have_udev || return 0

# check if we need to do something
if test -s $TMP_DIR/storage_drivers && ! diff $TMP_DIR/storage_drivers $VAR_DIR/recovery/storage_drivers >&8 ; then
	# remember, diff returns 0 if the files are the same

	# merge new drivers with previous initrd modules
	# BUG: we only add modules to the initrd, we don't take old ones out
	#      could be done better, but might not be worth the risk
	INITRD_MODULES="$( sort -t " " -k 1 -u $TMP_DIR/storage_drivers $TARGET_FS_ROOT/etc/initramfs-tools/module[s] )"
	# use [] to skip file if it does not exist
	# -t " " -k 1 tries to keep the comments unsorted

	echo "$INITRD_MODULES" >$TARGET_FS_ROOT/etc/initramfs-tools/modules

	mount -t proc none $TARGET_FS_ROOT/proc
	mount -t sysfs none $TARGET_FS_ROOT/sys
	# handle mdadm.conf Debian style
	if [ -r /proc/mdstat -a -r $TARGET_FS_ROOT/etc/mdadm/mdadm.conf -a -x $TARGET_FS_ROOT/usr/share/mdadm/mkconf ] ; then
		if chroot $TARGET_FS_ROOT /bin/bash --login -c "/usr/share/mdadm/mkconf >/etc/mdadm/mdadm.conf" ; then
			LogPrint "Updated '/etc/mdadm/mdadm.conf'"
		else
			LogPrint "WARNING !!!
Could not update /etc/mdadm/mdadm.conf with the new MD Array information.
Your system might not boot if the MD Arrays are required for booting due
to changed MD Array UUIDs or other details.

Please 'chroot $TARGET_FS_ROOT' and try to fix this. You should also run
update-initramfs afterwards to update the initramfs with the new mdadm.conf
"
		fi
	fi

        # Run update-initramfs directly in chroot without a login shell in between (see https://github.com/rear/rear/issues/862).
        # We need the update-initramfs binary in the chroot environment i.e. the update-initramfs binary in the recreated system.
        # Normally we would use a login shell like: chroot $TARGET_FS_ROOT /bin/bash --login -c 'type -P update-initramfs'
        # because otherwise there is no useful PATH (PATH is only /bin) so that 'type -P' won't find it
        # but we cannot use a login shell because that contradicts https://github.com/rear/rear/issues/862
        # so that we use a plain (non-login) shell and set a (hopefully) reasonable PATH:
        local update_initramfs_binary=$( chroot $TARGET_FS_ROOT /bin/bash -c 'PATH=/sbin:/usr/sbin:/usr/bin:/bin type -P update-initramfs' )
        # If there is no update-initramfs in the chroot environment plain 'chroot $TARGET_FS_ROOT' will hang up endlessly
        # and then "rear recover" cannot be aborted with the usual [Ctrl]+[C] keys.
        # Use plain $var because when var contains only blanks test "$var" results true because test " " results true:
        if test $update_initramfs_binary ; then
            if chroot $TARGET_FS_ROOT $update_initramfs_binary -v -u -k all >&2 ; then
                LogPrint "Updated initramfs with new drivers for this system."
            else
                LogPrint "WARNING:
Failed to create initramfs ($update_initramfs_binary).
Check '$RUNTIME_LOGFILE' to see the error messages in detail
and decide yourself, whether the system will boot or not.
"
            fi
        else
        LogPrint "WARNING:
Cannot create initramfs (found no update-initramfs in the recreated system).
Check the recreated system (mounted at $TARGET_FS_ROOT)
and decide yourself, whether the system will boot or not.
"
        fi
        umount $TARGET_FS_ROOT/proc $TARGET_FS_ROOT/sys

fi


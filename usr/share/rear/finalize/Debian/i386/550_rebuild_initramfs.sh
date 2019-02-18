
# Rebuild the initramfs:

# Skip if it is explicitly wanted to not rebuild the initramfs:
if is_false $REBUILD_INITRAMFS ; then
    Log "Skip recreating initramfs (REBUILD_INITRAMFS is false)"
    return 0
fi

# Skip if not needed but only when it is not explicitly wanted to rebuild the initramfs in any case:
if ! is_true $REBUILD_INITRAMFS ; then
    # During "rear recover" 260_recovery_storage_drivers.sh creates $TMP_DIR/storage_drivers
    if ! test -s $TMP_DIR/storage_drivers ; then
        Log "Skip recreating initramfs: No needed storage drivers ('$TMP_DIR/storage_drivers' is empty)"
        return 0
    fi
    # During "rear mkbackup/mkrescue" 260_storage_drivers.sh creates $VAR_DIR/recovery/storage_drivers
    if cmp -s $TMP_DIR/storage_drivers $VAR_DIR/recovery/storage_drivers ; then
        Log "Skip recreating initramfs: '$TMP_DIR/storage_drivers' and '$VAR_DIR/recovery/storage_drivers' are the same"
        return 0
    fi
fi

# A longer time ago udev was optional on some distros.
# This changed and nowadays udev is not optional any more.
# See https://github.com/rear/rear/pull/1171#issuecomment-274442700
# But it is not necessarily an error if initramfs cannot be re-created here
# because usually it works with the unchanged initramfs from the backup restore.
if ! have_udev ; then
    LogPrint "WARNING:
Cannot recreate initramfs (no udev found).
It may work with the initramfs 'as is' from the backup restore.
Check the recreated system (mounted at $TARGET_FS_ROOT)
and decide yourself, whether the system will boot or not.
"
    return 0
fi

# Merge new drivers with previous initrd modules.
# We only add modules to the initrd, we don't take old ones out.
# This might be done better, but is not worth the risk.
# use [] to skip file if it does not exist
# -t " " -k 1 tries to keep the comments unsorted
INITRD_MODULES="$( sort -t " " -k 1 -u $TMP_DIR/storage_drivers $TARGET_FS_ROOT/etc/initramfs-tools/module[s] )"
echo "$INITRD_MODULES" >$TARGET_FS_ROOT/etc/initramfs-tools/modules

# Handle mdadm.conf Debian style:
if [ -r /proc/mdstat -a -r $TARGET_FS_ROOT/etc/mdadm/mdadm.conf -a -x $TARGET_FS_ROOT/usr/share/mdadm/mkconf ] ; then
    if chroot $TARGET_FS_ROOT /bin/bash --login -c "/usr/share/mdadm/mkconf >/etc/mdadm/mdadm.conf" ; then
        LogPrint "Updated '/etc/mdadm/mdadm.conf' before recreating initramfs"
    else
        LogPrint "WARNING:
Could not update /etc/mdadm/mdadm.conf with the new MD array information.
Your system might not boot if the MD arrays are required for booting
due to changed MD array UUIDs or other details.
You should 'chroot $TARGET_FS_ROOT' and try to fix this.
Afterwards you should run update-initramfs to update
the initramfs with the new mdadm.conf
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


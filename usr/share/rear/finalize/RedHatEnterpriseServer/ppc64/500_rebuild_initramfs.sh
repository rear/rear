
# Rebuild the initrd if the drivers changed:

# Skip if there is nothing to do.
# During "rear recover" 260_recovery_storage_drivers.sh creates $TMP_DIR/storage_drivers
if ! test -s $TMP_DIR/storage_drivers ; then
    Log "Skip recreating initrd: No needed storage drivers ('$TMP_DIR/storage_drivers' is empty)"
    return 0
fi
# During "rear mkbackup/mkrescue" 260_storage_drivers.sh creates $VAR_DIR/recovery/storage_drivers
if cmp -s $TMP_DIR/storage_drivers $VAR_DIR/recovery/storage_drivers ; then
    Log "Skip recreating initrd: '$TMP_DIR/storage_drivers' and '$VAR_DIR/recovery/storage_drivers' are the same"
    return 0
fi

# A longer time ago udev was optional on some distros.
# This changed and nowadays udev is not optional any more.
# See https://github.com/rear/rear/pull/1171#issuecomment-274442700
# But it is not necessarily an error if initrd cannot be re-created here
# because usually it works with the unchanged initrd from the backup restore.
if ! have_udev ; then
    LogPrint "WARNING:
Cannot recreate initrd (no udev found).
It may work with the initrd 'as is' from the backup restore.
Check the recreated system (mounted at $TARGET_FS_ROOT)
and decide yourself, whether the system will boot or not.
"
    return 0
fi

my_udevtrigger
sleep 5
mount -t proc none $TARGET_FS_ROOT/proc
mount -t sysfs none $TARGET_FS_ROOT/sys

if is_true $BOOT_OVER_SAN ; then

    # Adding multipath config files must be part of the initramfs in order to
    # for the "root" disk to be a seen as a multipath device.

    # Add multipath option to dracut (real dracut command will be executed later
    # in this script).
    dracut_additional_option="$dracut_additional_option -a multipath"

    # create /etc/multipath.conf on the target if it does not exists on the target.
    if [ ! -f $TARGET_FS_ROOT/etc/multipath.conf ] ; then
        LogPrint "/etc/multipath.conf not available in target, creating it..."
        chroot $TARGET_FS_ROOT /bin/bash -c 'PATH=/sbin:/usr/sbin:/usr/bin:/bin mpathconf --enable --user_friendly_names y --find_multipaths y --with_module y --with_multipathd y --with_chkconfig y'
    fi

    # Cleaning /etc/multipath/wwids file and update it with new wwids.
    chroot $TARGET_FS_ROOT /bin/bash -c 'PATH=/sbin:/usr/sbin:/usr/bin:/bin multipath -W'

fi

# Run dracut directly in chroot without a login shell in between (see https://github.com/rear/rear/issues/862).
# We need the dracut binary in the chroot environment i.e. the dracut binary in the recreated system.
# Normally we would use a login shell like: chroot $TARGET_FS_ROOT /bin/bash --login -c 'type -P dracut'
# because otherwise there is no useful PATH (PATH is only /bin) so that 'type -P' won't find it
# but we cannot use a login shell because that contradicts https://github.com/rear/rear/issues/862
# so that we use a plain (non-login) shell and set a (hopefully) reasonable PATH:
local dracut_binary=$( chroot $TARGET_FS_ROOT /bin/bash -c 'PATH=/sbin:/usr/sbin:/usr/bin:/bin type -P dracut' )
# If there is no dracut in the chroot environment plain 'chroot $TARGET_FS_ROOT' will hang up endlessly
# and then "rear recover" cannot be aborted with the usual [Ctrl]+[C] keys.
# Use plain $var because when var contains only blanks test "$var" results true because test " " results true:
if test $dracut_binary ; then
    LogPrint "Running dracut to recreate initrd..."
    if chroot $TARGET_FS_ROOT $dracut_binary -f $dracut_additional_option >&2 ; then
        LogPrint "Recreated initrd ($dracut_binary)."
    else
        LogPrint "WARNING:
Failed to create initrd ($dracut_binary).
Check '$RUNTIME_LOGFILE' to see the error messages in detail
and decide yourself, whether the system will boot or not.
"
    fi
else
    LogPrint "WARNING:
Cannot create initrd (dracut not found in the recreated system).
Check the recreated system (mounted at $TARGET_FS_ROOT)
and decide yourself, whether the system will boot or not.
"
fi

umount $TARGET_FS_ROOT/proc $TARGET_FS_ROOT/sys

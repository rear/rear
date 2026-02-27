
# Rebuild the initrd:

# Skip if it is explicitly wanted to not rebuild the initrd:
if is_false $REBUILD_INITRAMFS ; then
    Log "Skip recreating initrd (REBUILD_INITRAMFS is false)"
    return 0
fi

# Skip if not needed but only when it is not explicitly wanted to rebuild the initrd in any case:
if ! is_true $REBUILD_INITRAMFS ; then
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
fi

# A longer time ago udev was optional on some distros.
# This changed and nowadays udev is not optional any more.
# See https://github.com/rear/rear/pull/1171#issuecomment-274442700
# But it is not necessarily an error if initrd cannot be re-created here
# because usually it works with the unchanged initrd from the backup restore.
if ! have_udev ; then
    LogPrintError "Warning:
Cannot recreate initrd (no udev found).
Check the recreated system (mounted at $TARGET_FS_ROOT)
and decide if the recreated system will boot
with the initrd 'as is' from the backup restore.
"
    return 0
fi

my_udevtrigger
sleep 5

# Run 'sdbootutil mkinitrd' to regenerate the initrd on systems that use
# GRUB2 with BLS. sdbootutil runs dracut under the hood and creates new
# bootloader entries, along with new initrds used by these entries.
local sysconfig_bootloader
if sysconfig_bootloader="$(get_sysconfig_bootloader)" \
    && [ "$sysconfig_bootloader" = "grub2-bls" ] ; then
    local sdbootutil_binary
    sdbootutil_binary=$( chroot "$TARGET_FS_ROOT" /bin/bash -c 'PATH=/sbin:/usr/sbin:/usr/bin:/bin type -P sdbootutil' )
    if test "$sdbootutil_binary" ; then
        if chroot "$TARGET_FS_ROOT" /bin/bash -c "PATH=/sbin:/usr/sbin:/usr/bin:/bin $sdbootutil_binary mkinitrd" ; then
            LogPrint "Recreated initrd and boot entry with $sdbootutil_binary"
        else
            LogPrintError "Warning:
Failed to recreate initrd and boot entry with $sdbootutil_binary.
Check '$RUNTIME_LOGFILE' why $sdbootutil_binary failed
and decide if the recreated system will boot
with the initrd 'as is' from the backup restore.
"
        fi
    else
    LogPrintError "Warning:
Cannot recreate initrd bootloader entry (sdbootutil not found in the recreated system).
Check the recreated system (mounted at $TARGET_FS_ROOT)
and decide if the recreated system will boot
with the initrd 'as is' from the backup restore.
"
    fi

    return 0
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
    LogPrint "Recreating initrd with $dracut_binary..."
    # At least in openSUSE Leap 15.5 /usr/bin/dracut sets its own PATH
    # so dracut should run successfully without PATH being set
    # nevertheless we set PATH to be on the safe side in general.
    # The --force option is needed because plain 'dracut' (at least in SLES15-SP5) fails with a message like
    # "dracut: Will not override existing initramfs (/boot/initrd-5.14.21-150500.55.28-default) without --force"
    if chroot $TARGET_FS_ROOT /bin/bash -c "PATH=/sbin:/usr/sbin:/usr/bin:/bin $dracut_binary --force" ; then
        LogPrint "Recreated initrd with $dracut_binary"
    else
        LogPrintError "Warning:
Failed to recreate initrd with $dracut_binary.
Check '$RUNTIME_LOGFILE' why $dracut_binary failed
and decide if the recreated system will boot
with the initrd 'as is' from the backup restore.
"
    fi
else
    # When there is no dracut binary in the chroot environment
    # i.e. when there is no dracut binary in the recreated system,
    # run mkinitrd as fallback in the same way as dracut is run above:
    local mkinitrd_binary=$( chroot $TARGET_FS_ROOT /bin/bash -c 'PATH=/sbin:/usr/sbin:/usr/bin:/bin type -P mkinitrd' )
    if test $mkinitrd_binary ; then
        LogPrint "Recreating initrd with $mkinitrd_binary..."
        if chroot $TARGET_FS_ROOT /bin/bash -c "PATH=/sbin:/usr/sbin:/usr/bin:/bin $mkinitrd_binary" ; then
            LogPrint "Recreated initrd with $mkinitrd_binary"
        else
            LogPrintError "Warning:
Failed to recreate initrd with $mkinitrd_binary.
Check '$RUNTIME_LOGFILE' why $dracut_binary failed
and decide if the recreated system will boot
with the initrd 'as is' from the backup restore.
"
        fi
    else
    LogPrintError "Warning:
Cannot recreate initrd (neither dracut nor mkinitrd found in the recreated system).
Check the recreated system (mounted at $TARGET_FS_ROOT)
and decide if the recreated system will boot
with the initrd 'as is' from the backup restore.
"
    fi
fi

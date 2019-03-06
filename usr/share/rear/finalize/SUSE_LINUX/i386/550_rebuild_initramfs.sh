
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
    LogPrint "WARNING:
Cannot recreate initrd (no udev found).
It may work with the initrd 'as is' from the backup restore.
Check the recreated system (mounted at $TARGET_FS_ROOT)
and decide yourself, whether the system will boot or not.
"
    return 0
fi

# Merge new drivers with previous initrd modules.
# We only add modules to the initrd, we don't take old ones out.
# This might be done better, but is not worth the risk.

# Set INITRD_MODULES from recovered system
if test -r $TARGET_FS_ROOT/etc/sysconfig/kernel ; then
    # In SLE12 RC2 /etc/sysconfig/kernel is an useless stub that contains only one line
    #   INITRD_MODULES=""
    # Since SLE12 RC3 /etc/sysconfig/kernel does no longer exist, see bnc#895084 where
    # in particular https://bugzilla.novell.com/show_bug.cgi?id=895084#c7 reads
    #   Best would be to add something like that:
    #   # This replaces old INITRD_MODULES= variable from /etc/sysconfig/kernel
    #   # force_drivers+="kernel_module1 kernel_module2 ..."
    #   in our /etc/dracut.conf.d/01-dist.conf file.
    #   And a similar comment to /etc/sysconfig/kernel
    #   # DO NOT USE THIS FILE ANYMORE. IF YOU WANT TO ENFORCE LOADING
    #   # SPECIFIC KERNEL MODULES SEE /etc/dracut.conf.d/01-dist.conf
    #   # and the dracut (--force-drivers paramter) manpage.
    # Because the comment above reads "probably not required" at least for now
    # there is no support for force_drivers in /etc/dracut.conf.d/01-dist.conf.
    source $TARGET_FS_ROOT/etc/sysconfig/kernel || Error "Could not source '$TARGET_FS_ROOT/etc/sysconfig/kernel'"
    Log "Original INITRD_MODULES='$INITRD_MODULES'"
    # Using array to split into words:
    OLD_INITRD_MODULES=( $INITRD_MODULES )
    # To see what has been added by the migration process, the new modules are added to the
    # end of the list. To achieve this, we list the old modules twice in the variable
    # NEW_INITRD_MODULES and then add the new modules. Then we use "uniq -u" to filter out
    # the modules which only appear once in the list. The result array the only
    # contains the new modules.
    NEW_INITRD_MODULES=( $INITRD_MODULES $INITRD_MODULES $( cat $TMP_DIR/storage_drivers ) )
    # uniq INITRD_MODULES
    NEW_INITRD_MODULES=( $( tr " " "\n" <<< "${NEW_INITRD_MODULES[*]}" | sort | uniq -u ) )
    Log "New INITRD_MODULES='${OLD_INITRD_MODULES[@]} ${NEW_INITRD_MODULES[@]}'"
    sed -i -e '/^INITRD_MODULES/s/^.*$/#&\nINITRD_MODULES="'"${OLD_INITRD_MODULES[*]} ${NEW_INITRD_MODULES[*]}"'"/' $TARGET_FS_ROOT/etc/sysconfig/kernel
fi

my_udevtrigger
sleep 5

LogPrint "Running mkinitrd..."
# Run mkinitrd directly in chroot without a login shell in between (see https://github.com/rear/rear/issues/862).
# We need the mkinitrd binary in the chroot environment i.e. the mkinitrd binary in the recreated system.
# Normally we would use a login shell like: chroot $TARGET_FS_ROOT /bin/bash --login -c 'type -P mkinitrd'
# because otherwise there is no useful PATH (PATH is only /bin) so that 'type -P' won't find it
# but we cannot use a login shell because that contradicts https://github.com/rear/rear/issues/862
# so that we use a plain (non-login) shell and set a (hopefully) reasonable PATH:
local mkinitrd_binary=$( chroot $TARGET_FS_ROOT /bin/bash -c 'PATH=/sbin:/usr/sbin:/usr/bin:/bin type -P mkinitrd' )
# If there is no mkinitrd in the chroot environment plain 'chroot $TARGET_FS_ROOT' will hang up endlessly
# and then "rear recover" cannot be aborted with the usual [Ctrl]+[C] keys.
# Use plain $var because when var contains only blanks test "$var" results true because test " " results true:
if test $mkinitrd_binary ; then
    # mkinitrd calls other tool like find, xargs, wc ... without full PATH.
    # $PATH MUST BE SET for mkinitrd can run successfully.
    if chroot $TARGET_FS_ROOT /bin/bash -c "PATH=/sbin:/usr/sbin:/usr/bin:/bin $mkinitrd_binary" >&2 ; then
        LogPrint "Recreated initrd ($mkinitrd_binary)."
    else
        LogPrint "WARNING:
Failed to create initrd ($mkinitrd_binary).
Check '$RUNTIME_LOGFILE' to see the error messages in detail
and decide yourself, whether the system will boot or not.
"
    fi
else
    LogPrint "WARNING:
Cannot create initrd (found no mkinitrd in the recreated system).
Check the recreated system (mounted at $TARGET_FS_ROOT)
and decide yourself, whether the system will boot or not.
"
fi


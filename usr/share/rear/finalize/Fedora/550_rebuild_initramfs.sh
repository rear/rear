
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

# Read original INITRD_MODULES from source system
if [ -f $VAR_DIR/recovery/initrd_modules ]; then
    OLD_INITRD_MODULES=( $(cat $VAR_DIR/recovery/initrd_modules) )
    else
    OLD_INITRD_MODULES=()
fi

Log "Original OLD_INITRD_MODULES=( ${OLD_INITRD_MODULES[*]} )"
# To see what has been added by the migration process, the new modules are added to the end of the list.
# To achieve this, we list the old modules twice in the variable NEW_INITRD_MODULES and then add the new modules.
# Then we use "uniq -u" to filter out the modules which only appear once in the list.
# The resulting array contains only the new modules:
NEW_INITRD_MODULES=( "${OLD_INITRD_MODULES[@]}" "${OLD_INITRD_MODULES[@]}" $( cat $TMP_DIR/storage_drivers ) )
NEW_INITRD_MODULES=( $( tr " " "\n" <<< "${NEW_INITRD_MODULES[*]}" | sort | uniq -u ) )

# Concatenate the old and new modules into a string:
INITRD_MODULES="${OLD_INITRD_MODULES[*]} ${NEW_INITRD_MODULES[*]}"
Log "New INITRD_MODULES='$INITRD_MODULES'"

# Do not quote $INITRD_MODULES otherwise printf could not split words as separated arguments on separated lines:
WITH_INITRD_MODULES=$( printf '%s\n' $INITRD_MODULES | awk '{printf "--add-drivers=%s ", $1}' )

# Recreate any initrd or initramfs image under $TARGET_FS_ROOT/boot/ with new drivers
# Images ignored:
# kdump images as they are build by kdump
# initramfs rescue images (>= Rhel 7), which need all modules and are created by new-kernel-pkg
# initrd-plymouth.img (>= Rhel 7), which contains only files needed for graphical boot via plymouth
for INITRD_IMG in $( ls $TARGET_FS_ROOT/boot/initramfs-*.img $TARGET_FS_ROOT/boot/initrd-*.img | egrep -v '(kdump|rescue|plymouth)' ) ; do
    # Do not use KERNEL_VERSION here because that is readonly in the rear main script:
    kernel_version=$( basename $( echo $INITRD_IMG ) | cut -f2- -d"-" | sed s/"\.img"// )
    INITRD=$( echo $INITRD_IMG | egrep -o "/boot/.*" )
    LogPrint "Running dracut..."
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
        if chroot $TARGET_FS_ROOT $dracut_binary -v -f $WITH_INITRD_MODULES $INITRD $kernel_version ; then
            LogPrint "Updated initrd with new drivers for kernel $kernel_version."
        else
            LogPrint "WARNING:
Failed to create initrd for kernel version '$kernel_version'.
Check '$RUNTIME_LOGFILE' to see the error messages in detail
and decide yourself, whether the system will boot or not.
"
        fi
    else
        LogPrint "WARNING:
Cannot create initrd (found no dracut in the recreated system).
Check the recreated system (mounted at $TARGET_FS_ROOT)
and decide yourself, whether the system will boot or not.
"
    fi
done


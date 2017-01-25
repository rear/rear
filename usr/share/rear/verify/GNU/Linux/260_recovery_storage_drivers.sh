# Find the storage drivers for the recovery hardware.

# A longer time ago udev was optional on some distros.
# This changed and nowadays udev is not optional any more.
# See https://github.com/rear/rear/pull/1171#issuecomment-274442700
# But it is not necessarily an error if the storage drivers
# for the recovery hardware cannot be determined:
if ! have_udev ; then
    LogPrint "Cannot determine storage drivers (no udev found), proceeding bona fide"
    return 0
fi

FindStorageDrivers $TMP_DIR/dev >$TMP_DIR/storage_drivers

if ! test -s $TMP_DIR/storage_drivers ; then
    Log "No driver migration: No needed storage drivers found ('$TMP_DIR/storage_drivers' is empty)"
    return 0
fi
# During "rear mkbackup/mkrescue" 260_storage_drivers.sh creates $VAR_DIR/recovery/storage_drivers
if cmp -s $TMP_DIR/storage_drivers $VAR_DIR/recovery/storage_drivers ; then
    Log "No driver migration: '$TMP_DIR/storage_drivers' and '$VAR_DIR/recovery/storage_drivers' are the same"
    return 0
fi

LogPrint "Will do driver migration (recreating initramfs/initrd)"


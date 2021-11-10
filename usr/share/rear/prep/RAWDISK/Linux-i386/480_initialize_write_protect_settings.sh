# RAWDISK output typically resides on a writable disk device, which should be protected against
# accidental overwriting by rear recover. This code initializes RAWDISK_PTUUID, a partition table UUID
# designating ReaR's own boot device and registers it as write protected.

if has_binary uuidgen; then
    # Generate a partition table UUID now and add it to the kernel's command line options.
    #
    # Normally, a partition table UUID is generated automatically during partitioning. We cannot wait for this
    # to happen as the variable will be part of the initrd, which is completed before any partition table is
    # created.
    RAWDISK_PTUUID="$( uuidgen )"
    if test "$RAWDISK_PTUUID"; then
        WRITE_PROTECTED_IDS+=( $RAWDISK_PTUUID )
    else
        LogPrintError "Cannot write protect '${RAWDISK_GPT_PARTITION_NAME:-Rescue System}' disk (no partition table UUID)"
    fi
else
    LogPrintError "Cannot write protect '${RAWDISK_GPT_PARTITION_NAME:-Rescue System}' disk (no 'uuidgen' found)"
fi

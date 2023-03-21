# prepare rescue system to use ramdisk rootfs


is_false "$USE_RAMDISK" && return

if is_true "$USE_RAMDISK"; then
    LogPrint "Configuring Rescue system with default ramdisk size"
elif is_positive_integer "$USE_RAMDISK" ; then
    LogPrint "Configuring Rescue system with ramdisk and free disk space of $USE_RAMDISK MiB"
    echo $USE_RAMDISK >$ROOTFS_DIR/etc/ramdisk-free-space
else
    Error "USE_RAMDISK='$USE_RAMDISK' is not a positive integer"
fi

REQUIRED_PROGS+=(switch_root du)
KERNEL_CMDLINE+=" rdinit=/etc/scripts/ramdisk-rootfs"

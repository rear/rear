# prepare rescue system to use ramdisk rootfs

test "$USE_RAMDISK" || return 0

if is_positive_integer "$USE_RAMDISK" && ((USE_RAMDISK > 1000)); then
    # is a number and greater 1000, use as free space in MB
    Log "Configuring Rescue system with ramdisk and free disk space of $USE_RAMDISK MB"
    echo $USE_RAMDISK >$ROOTFS_DIR/etc/ramdisk-free-space
else
    Log "Configuring Rescue system with default ramdisk size"
fi

REQUIRED_PROGS+=(switch_root du)
KERNEL_CMDLINE+=" rdinit=/etc/scripts/ramdisk-rootfs"

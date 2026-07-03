
# Include tools needed for the initrd overlay feature.
# depmod is required to regenerate module dependencies after
# the overlay content is copied into the rescue system at boot time.
# curl is required for PXE output to download the overlay from the server.

test "$REAR_INITRD_OVERLAY" || return 0

PROGS+=( depmod )

if test "$OUTPUT" = "PXE" ; then
    REQUIRED_PROGS+=( curl )
fi

# Ensure modules needed for overlay access are included in the rescue system
# even when MODULES is restricted to loaded modules only.
MODULES_LOAD+=( loop squashfs overlay )
case "$OUTPUT" in
    (ISO) MODULES_LOAD+=( isofs udf sr_mod cdrom ) ;;
    (USB) MODULES_LOAD+=( ext4 jbd2 ) ;;
esac

# When GRUB_RESCUE is enabled, detect the /boot filesystem type and storage
# driver at prep time so the pack stage can keep the right modules in the
# initramfs. The output stage (940_grub2_rescue.sh) uses boot_dir="/boot"
# and we must match that here.
if is_true "$GRUB_RESCUE" ; then
    GRUB_RESCUE_BOOT_DIR="/boot"
    GRUB_RESCUE_BOOT_FSTYPE=$( df -T "$GRUB_RESCUE_BOOT_DIR" 2>/dev/null | awk 'END {print $2}' )
    GRUB_RESCUE_BOOT_DISK=$( lsblk -no PKNAME "$( df "$GRUB_RESCUE_BOOT_DIR" 2>/dev/null | awk 'END {print $1}' )" 2>/dev/null | head -1 )
    if test "$GRUB_RESCUE_BOOT_DISK" ; then
        GRUB_RESCUE_BOOT_DRIVER=$( basename "$( readlink "/sys/block/$GRUB_RESCUE_BOOT_DISK/device/driver" 2>/dev/null )" 2>/dev/null )
    fi
    Log "GRUB_RESCUE: $GRUB_RESCUE_BOOT_DIR uses $GRUB_RESCUE_BOOT_FSTYPE on $GRUB_RESCUE_BOOT_DRIVER (disk $GRUB_RESCUE_BOOT_DISK)"
fi

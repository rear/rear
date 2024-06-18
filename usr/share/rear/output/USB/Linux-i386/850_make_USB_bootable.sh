
# Nothing to do here when GRUB2 is specified to be used as USB bootloader:
test "$USB_BOOTLOADER" = "grub" && return

# Test for features in dd
# true if dd supports oflag= option
FEATURE_DD_OFLAG=
dd_version=$( get_version dd --version )
version_newer "$dd_version" 5.3.0 && FEATURE_DD_OFLAG="y"

# We assume REAL_USB_DEVICE and RAW_USB_DEVICE are both set by prep/USB/Linux-i386/350_check_usb_disk.sh
[ "$RAW_USB_DEVICE" -a "$REAL_USB_DEVICE" ] || BugError "RAW_USB_DEVICE and REAL_USB_DEVICE are not both set"

# Check if syslinux needs to be updated:
usb_syslinux_version=$( get_usb_syslinux_version )
syslinux_version=$( get_syslinux_version )
if [[ "$usb_syslinux_version" ]] && version_newer "$usb_syslinux_version" "$syslinux_version" ; then
    DebugPrint "No need to update syslinux on $RAW_USB_DEVICE that has version $usb_syslinux_version"
    return
fi

LogPrint "Making $RAW_USB_DEVICE bootable with syslinux/extlinux"

# When RAW_USB_DEVICE is e.g. /dev/sdb
# then REAL_USB_DEVICE is the data partition /dev/sdb1 when there in no boot partition or /dev/sdb2 when there is a boot partition which is /dev/sdb1
# and USB_DEVICE is e.g. /dev/disk/by-label/REAR-000 (from BACKUP_URL=usb:///dev/disk/by-label/REAR-000) which is also the data partition
# but here we need the filesystem where the booting related files are which are on the data partition or on the boot partition if exists
# and that filesystem was mounted by output/default/100_mount_output_path.sh at $BUILD_DIR/outputfs which is shown in /proc/mounts like
# /dev/sdb1 /var/tmp/rear.XXXXXXXXXXXXXXX/outputfs ext2 rw,noatime 0 0
# so we search for " $BUILD_DIR/outputfs " in /proc/mounts to get the filesystem (third field) where the booting related files are:
usb_filesystem=$( grep " $BUILD_DIR/outputfs " /proc/mounts | cut -d' ' -f3 | tail -1 )
case "$usb_filesystem" in
    # Since SYSLINUX version 4.00 extlinux also works for a mounted vfat boot partition
    # because https://wiki.archlinux.org/title/syslinux reads (excerpts):
    #   For FAT, ext2/3/4, or btrfs boot partition use extlinux, where the device has been mounted:
    #     # extlinux --install ...
    #   Alternatively, for a FAT boot partition use syslinux, where the device is unmounted
    # and see https://wiki.syslinux.org/wiki/index.php?title=EXTLINUX that reads (excerpt):
    #   EXTLINUX supports:
    #   [3.00+] ext2/3,
    #   [4.00+] FAT12/16/32, ext2/3/4, Btrfs,
    #   [4.06+] FAT12/16/32, NTFS, ext2/3/4, Btrfs,
    #   [5.01+] FAT12/16/32, NTFS, ext2/3/4, Btrfs, XFS,
    #   [6.03+] FAT12/16/32, NTFS, ext2/3/4, Btrfs, XFS, UFS/FFS
    # and see https://wiki.syslinux.org/wiki/index.php?title=Syslinux_4_Changelog that reads (excerpts):
    #   Changes in 4.00
    #   ...
    #   EXTLINUX is no longer a separate derivative;
    #   extlinux and syslinux both install the same loader (ldlinux.sys);
    #   for the Linux-based installers the extlinux binary is used for a mounted filesystem;
    #   the syslinux binary for an unmounted filesystem.
    # See https://github.com/rear/rear/issues/2884
    # and https://github.com/rear/rear/pull/2904
    (ext?|vfat)
        if [[ "$FEATURE_SYSLINUX_EXTLINUX_INSTALL" ]] ; then
            extlinux -i "$BUILD_DIR/outputfs/$SYSLINUX_PREFIX" || Error "'extlinux -i $BUILD_DIR/outputfs/$SYSLINUX_PREFIX' failed"
        else
            extlinux "$BUILD_DIR/outputfs/$SYSLINUX_PREFIX" || Error "'extlinux $BUILD_DIR/outputfs/$SYSLINUX_PREFIX' failed"
        fi
        ;;
    ("")
        LogPrintError "Could not find a filesystem in /proc/mounts for $BUILD_DIR/outputfs"
        Error "An ext2/3/4 or vfat filesystem must be mounted for the booting related files on $RAW_USB_DEVICE"
        ;;
    (*)
        LogPrintError "Only ext2/3/4 and vfat are supported for the booting related files on $RAW_USB_DEVICE"
        Error "Unsupported filesystem $usb_filesystem is mounted at $BUILD_DIR/outputfs"
        ;;
esac

if [ "$REAL_USB_DEVICE" != "$RAW_USB_DEVICE" ] ; then
    # Write the USB boot sector if the filesystem is not the entire disk:
    LogPrint "Writing syslinux MBR $SYSLINUX_MBR_BIN of type $USB_DEVICE_PARTED_LABEL to $RAW_USB_DEVICE"
    if [[ "$FEATURE_DD_OFLAG" ]] ; then
        dd if=$SYSLINUX_MBR_BIN of=$RAW_USB_DEVICE bs=440 count=1 oflag=sync || Error "Failed to write syslinux MBR to $RAW_USB_DEVICE"
    else
        dd if=$SYSLINUX_MBR_BIN of=$RAW_USB_DEVICE bs=440 count=1 || Error "Writing syslinux MBR to $RAW_USB_DEVICE failed"
        sync
    fi
else
    LogPrintError "Not writing syslinux MBR to $RAW_USB_DEVICE so it may not be bootable"
fi

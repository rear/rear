
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
# /dev/sdb1 /tmp/rear.gfYZXbLIa2Xjult/outputfs ext2 rw,noatime 0 0
# so we search for " $BUILD_DIR/outputfs " in /proc/mounts to get the filesystem (third field) where the booting related files are:
usb_filesystem=$( grep " $BUILD_DIR/outputfs " /proc/mounts | cut -d' ' -f3 | tail -1 )
case "$usb_filesystem" in
    (ext?)
        if [[ "$FEATURE_SYSLINUX_EXTLINUX_INSTALL" ]] ; then
            extlinux -i "$BUILD_DIR/outputfs/$SYSLINUX_PREFIX" || Error "'extlinux -i $BUILD_DIR/outputfs/$SYSLINUX_PREFIX' failed"
        else
            extlinux "$BUILD_DIR/outputfs/$SYSLINUX_PREFIX" || Error "'extlinux $BUILD_DIR/outputfs/$SYSLINUX_PREFIX' failed"
        fi
        ;;
    ("")
        BugError "Filesystem where the booting related files are on $RAW_USB_DEVICE could not be found"
        ;;
    (*)
        Error "Filesystem $usb_filesystem for the booting related files is not supported"
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

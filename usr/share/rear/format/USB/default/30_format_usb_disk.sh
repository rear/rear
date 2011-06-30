# $answer is filled by 20_check_usb_layout.sh
if [[ "$answer" == "Yes" || "$FORCE" ]]; then
    umount $REAL_USB_DEVICE >&8 2>&1

    LogPrint "Repartition $RAW_USB_DEVICE"

    echo "Yes" | parted -s $RAW_USB_DEVICE mklabel msdos >&2
    StopIfError "Could not create msdos partitioning"

    # FIXME: Parted shipping with RHEL4 does not support percentages !
    echo "Yes" | parted -s $RAW_USB_DEVICE mkpart primary 0 100% >&2
    StopIfError "Could not create a primary partition on '$REAL_USB_DEVICE'"

    echo "Yes" | parted -s $RAW_USB_DEVICE set 1 boot on >&2
    StopIfError "Could not make primary partition boot-able on '$REAL_USB_DEVICE'"

    partprobe $RAW_USB_DEVICE

    # Wait until udev has had the time to kick in
    sleep 5

    LogPrint "Creating new filesystem on ${RAW_USB_DEVICE}1"
    mkfs.ext3 -L REAR-000 ${RAW_USB_DEVICE}1 >&2
    StopIfError "Could not format '${RAW_USB_DEVICE}1' with ext3 layout"

    tune2fs -c 0 -i 0 -o acl,journal_data,journal_data_ordered ${RAW_USB_DEVICE}1 >&2
    StopIfError "Failed to change filesystem characteristics on '${RAW_USB_DEVICE}1'"

fi

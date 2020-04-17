# 310_autoexclude_usb.sh
# Reason: issue #645
# /dev/sdb1                           240234164 2996672 225027564   2% /mnt
# is not detected as an USB path which causing rsync to loop until usb output_url is full
# If we find an USB device we will just add it to AUTOEXCLUDE_USB_PATH

for URL in "$OUTPUT_URL" "$BACKUP_URL" ; do
    if [[ ! -z "$URL" ]] ; then
        local host=$(url_host $URL)
        local scheme=$(url_scheme $URL)
        local path=$(url_path $URL)

        case $scheme in
            (usb)
                if [[ -z "$USB_DEVICE" ]] ; then
                    USB_DEVICE="$path"
                fi
                ;;
	        (*)
                continue ;;
        esac
    else
        continue  # check next one
    fi

    # Return a proper short device name using udev
    REAL_USB_DEVICE=$(readlink -f $USB_DEVICE)

    # when USB device is not a block device no need to dig deeper here (in savelayout part)
    [[ ! -b "$REAL_USB_DEVICE" ]] && return

    # if we are still here then we found an USB device, e.g. /dev/sdb1
    # in savelayout we have not yet mounted the OUTPUT_URL so if we find a mount point it was manually mounted
    # and therefore, we should add this mount point to AUTOEXCLUDE_USB_PATH

    grep -q "^$REAL_USB_DEVICE " /proc/mounts
    if [[ $? -eq 0 ]] ; then
        local usb_mntpt=$( grep "^$REAL_USB_DEVICE " /proc/mounts | cut -d" " -f2 | tail -1 )
        if ! IsInArray "$usb_mntpt" "${AUTOEXCLUDE_USB_PATH[@]}" ; then
            AUTOEXCLUDE_USB_PATH+=( $usb_mntpt )
            Log "Auto-excluding USB path $usb_mntpt [device $REAL_USB_DEVICE]"
        fi
    fi
done

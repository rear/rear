# Describe luks devices
# We use /etc/crypttab and cryptsetup for information

if ! has_binary cryptsetup; then
    return
fi

Log "Saving Encrypted volumes."
REQUIRED_PROGS=( "${REQUIRED_PROGS[@]}" cryptsetup )

while read dm_name junk ; do
    # find the device we're mapping
    if ! [ -e /dev/mapper/$dm_name ] ; then
        Log "Device Mapper name $dm_name not found in /dev/mapper."
        continue
    fi

    dev_name=$(get_sysfs_name /dev/mapper/$dm_name)
    if [ -z "$dev_name" ] ; then
        Log "Could not find device $dev_number in sysfs."
        continue
    fi

    device=""
    for slave in /sys/block/$dev_name/slaves/* ; do
        if ! [ -z "$device" ] ; then
            BugError "Multiple Device Mapper slaves for crypt $dm_name detected."
        fi
        device="$(get_device_name ${slave##*/})"
    done

    if ! cryptsetup isLuks $device >&8 2>&1; then
        continue
    fi

    # gather crypt information
    cipher=$(cryptsetup luksDump $device | grep "Cipher name" | sed -r 's/^.+:\s*(.+)$/\1/')
    ##mode=$(cryptsetup luksDump $device | grep "Cipher mode" | sed -r 's/^.+:\s*(.+)$/\1/')
    mode=$(cryptsetup luksDump $device | grep "Cipher mode" | cut -d: -f2- | awk '{printf("%s",$1)};')
    hash=$(cryptsetup luksDump $device | grep "Hash spec" | sed -r 's/^.+:\s*(.+)$/\1/')
    uuid=$(cryptsetup luksDump $device | grep "UUID" | sed -r 's/^.+:\s*(.+)$/\1/')

    echo "crypt /dev/mapper/$dm_name $device cipher=$cipher mode=$mode hash=$hash uuid=${uuid}" >> $DISKLAYOUT_FILE
done < <( dmsetup ls --target crypt )

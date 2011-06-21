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
        device="/dev/$(get_device_name ${slave##*/})"
    done
    
    if ! cryptsetup isLuks $device >&8 2>&1; then
        continue
    fi
    
    # gather crypt information
    cipher=$(cryptsetup luksDump $device | grep "Cipher name" | sed -r 's/^.+:[^a-z]+(.+)$/\1/')
    mode=$(cryptsetup luksDump $device | grep "Cipher mode" | sed -r 's/^.+:[^a-z]+(.+)$/\1/')
    hash=$(cryptsetup luksDump $device | grep "Hash spec" | sed -r 's/^.+:[^a-z]+(.+)$/\1/')
    uuid=$(cryptsetup luksDump $device | grep "UUID" | sed -r 's/^.+:[^a-z]+(.+)$/\1/')
    
    # Search for a keyfile or password.
    keyfile=""
    password=""
    if [ -e /etc/crypttab ] ; then
        while read name path key junk ; do
            # skip blank lines, comments and non-block devices
            if [ -n "$name" ] && [ "${name#\#}" = "$name" ] && [ -b "$path" ] && [ "$path" = "$device" ] ; then
                # manual password
                if [ "$key" = "none" ] ; then
                    break
                elif [ -e "$key" ] ; then
                    # keyfile
                    keyfile=" key=$key"
                    COPY_AS_IS=( "${COPY_AS_IS[@]}" $key )
                else
                    # password
                    password=" password=$key"
                fi
                break
            fi
        done < /etc/crypttab
    fi
    
    echo "crypt /dev/mapper/$dm_name $device cipher=$cipher mode=$mode hash=$hash uuid=${uuid}${keyfile}${password}" >> $DISKLAYOUT_FILE
done < <( dmsetup ls --target crypt )

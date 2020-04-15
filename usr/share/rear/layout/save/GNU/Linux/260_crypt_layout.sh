# Describe LUKS devices
# We use /etc/crypttab and cryptsetup for information

if ! has_binary cryptsetup; then
    return
fi

Log "Saving Encrypted volumes."
REQUIRED_PROGS+=( cryptsetup dmsetup )
COPY_AS_IS+=( /usr/share/cracklib/\* /etc/security/pwquality.conf )

while read target_name junk ; do
    # find the target device we're mapping
    if ! [ -e /dev/mapper/$target_name ] ; then
        Log "Device Mapper name $target_name not found in /dev/mapper."
        continue
    fi

    sysfs_device=$(get_sysfs_name /dev/mapper/$target_name)
    if [ -z "$sysfs_device" ] ; then
        Log "Could not find device $target_name in sysfs."
        continue
    fi

    source_device=""
    for slave in /sys/block/$sysfs_device/slaves/* ; do
        if ! [ -z "$source_device" ] ; then
            BugError "Multiple Device Mapper slaves for crypt $target_name detected."
        fi
        source_device="$(get_device_name ${slave##*/})"
    done

    if ! cryptsetup isLuks $source_device >/dev/null 2>&1; then
        continue
    fi

    # gather crypt information
    cipher=$(cryptsetup luksDump $source_device | grep "Cipher name" | sed -r 's/^.+:\s*(.+)$/\1/')
    mode=$(cryptsetup luksDump $source_device | grep "Cipher mode" | cut -d: -f2- | awk '{printf("%s",$1)};')
    key_size=$(cryptsetup luksDump $source_device | grep "MK bits" | sed -r 's/^.+:\s*(.+)$/\1/')
    hash=$(cryptsetup luksDump $source_device | grep "Hash spec" | sed -r 's/^.+:\s*(.+)$/\1/')
    uuid=$(cryptsetup luksDump $source_device | grep "UUID" | sed -r 's/^.+:\s*(.+)$/\1/')
    keyfile_option=$([ -f /etc/crypttab ] && awk '$1 == "'"$target_name"'" && $3 != "none" && $3 != "-" && $3 != "" { print "keyfile=" $3; }' /etc/crypttab)

    echo "crypt /dev/mapper/$target_name $source_device cipher=$cipher-$mode key_size=$key_size hash=$hash uuid=$uuid $keyfile_option" >> $DISKLAYOUT_FILE
done < <( dmsetup ls --target crypt )

# cryptsetup is required in the recovery system if disklayout.conf contains at least one 'crypt' entry
# see the create_crypt function in layout/prepare/GNU/Linux/160_include_luks_code.sh
# what program calls are written to diskrestore.sh
# cf. https://github.com/rear/rear/issues/1963
grep -q '^crypt ' $DISKLAYOUT_FILE && REQUIRED_PROGS+=( cryptsetup ) || true


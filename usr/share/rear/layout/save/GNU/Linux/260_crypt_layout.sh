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

    # LUKS version 2 is not yet suppported, see https://github.com/rear/rear/issues/2204
    # When LUKS version 2 is used the above code fails at least to determine the hash value
    # so we use an empty hash value as a simple test if gathering crypt information was successful:
    if ! test "$hash" ; then
        # Inform the user and write the available info as comment to disklayout.conf so that the user could manually adapt it
        # but do not error out here because there is no user-friendly way to skip LUKS2 volumes during "rear mkrescue"
        # and LUKS2 volumes must nnot be automatically (or even silently) skipped during "rear mkrescue"
        # to let the user find out later (when it is too late) during "rear recover" that LUKS2 volumes are not supported.
        # The only way to not let "rear mkrescue" process LUKS2 volumes is to 'umount' and 'cryptsetup luksClose' them
        # before "rear mkrescue" is run so that those volumes are no longer listed by 'dmsetup ls --target crypt'
        # cf. https://github.com/rear/rear/issues/2491
        LogPrintError "Error: Incomplete values for LUKS device '$target_name' at '$source_device' (only LUKS version 1 is supported) see $DISKLAYOUT_FILE"
        echo "# Incomplete values for LUKS device '$target_name' at '$source_device' (only LUKS version 1 is supported):" >> $DISKLAYOUT_FILE
        echo "#crypt /dev/mapper/$target_name $source_device cipher=$cipher-$mode key_size=$key_size hash=$hash uuid=$uuid $keyfile_option" >> $DISKLAYOUT_FILE
        continue
    fi

    echo "crypt /dev/mapper/$target_name $source_device cipher=$cipher-$mode key_size=$key_size hash=$hash uuid=$uuid $keyfile_option" >> $DISKLAYOUT_FILE
    
done < <( dmsetup ls --target crypt )

# cryptsetup is required in the recovery system if disklayout.conf contains at least one 'crypt' entry
# (also in case of an incomplete commented '#crypt' entry from a LUKS2 volume for manual setup by the user)
# see the create_crypt function in layout/prepare/GNU/Linux/160_include_luks_code.sh
# what program calls are written to diskrestore.sh
# cf. https://github.com/rear/rear/issues/1963
grep -q '^#*crypt ' $DISKLAYOUT_FILE && REQUIRED_PROGS+=( cryptsetup ) || true


# Describe LUKS devices
# We use /etc/crypttab and cryptsetup for information

# Skip when not needed:
has_binary cryptsetup || return 0

Log "Saving Encrypted volumes"

# cryptsetup is required in the recovery system if disklayout.conf contains at least one 'crypt' entry
# but also in case of an incomplete commented '#crypt' entry from a LUKS2 volume
# so we include things in any case so that the user could do a manual setup if needed
# cf. https://github.com/rear/rear/issues/2491
# See the create_crypt function in layout/prepare/GNU/Linux/160_include_luks_code.sh
# what program calls are written to diskrestore.sh and
# see also https://github.com/rear/rear/issues/1963
REQUIRED_PROGS+=( cryptsetup dmsetup )
COPY_AS_IS+=( /usr/share/cracklib/\* /etc/security/pwquality.conf )

while read target_name junk ; do

    if ! test -e /dev/mapper/$target_name ; then
        Log "Skipping $target_name (there is no /dev/mapper/$target_name)"
        continue
    fi

    sysfs_device=$( get_sysfs_name /dev/mapper/$target_name )
    if ! test "$sysfs_device" ; then
        Log "Skipping $target_name (could not find device for $target_name in /sys/block/)"
        continue
    fi

    source_device=""
    for slave in /sys/block/$sysfs_device/slaves/* ; do
        if test "$source_device" ; then
            BugError "Crypt $target_name has multiple device mapper slaves in /sys/block/$sysfs_device/slaves/"
        fi
        source_device="$( get_device_name ${slave##*/} )"
    done
    if ! test "$source_device" ; then
        Log "Skipping $target_name (could not get its device in /sys/block/$sysfs_device/slaves/)"
        continue
    fi
    
    if ! cryptsetup isLuks $source_device ; then
        Log "Skipping $target_name (its $source_device is not a LUKS device)"
        continue
    fi

    # Gather crypt information:
    if ! cryptsetup luksDump $source_device >$TMP_DIR/cryptsetup.luksDump ; then
        LogPrintError "Error: Cannot get LUKS values for $target_name ('cryptsetup luksDump $source_device' failed)"
        continue
    fi
    cipher=$( grep "Cipher name" $TMP_DIR/cryptsetup.luksDump | sed -r 's/^.+:\s*(.+)$/\1/' )
    mode=$( grep "Cipher mode" $TMP_DIR/cryptsetup.luksDump | cut -d: -f2- | awk '{printf("%s",$1)};' )
    key_size=$( grep "MK bits" $TMP_DIR/cryptsetup.luksDump | sed -r 's/^.+:\s*(.+)$/\1/' )
    hash=$( grep "Hash spec" $TMP_DIR/cryptsetup.luksDump | sed -r 's/^.+:\s*(.+)$/\1/' )
    uuid=$( grep "UUID" $TMP_DIR/cryptsetup.luksDump | sed -r 's/^.+:\s*(.+)$/\1/' )
    keyfile_option=$( [ -f /etc/crypttab ] && awk '$1 == "'"$target_name"'" && $3 != "none" && $3 != "-" && $3 != "" { print "keyfile=" $3; }' /etc/crypttab )

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


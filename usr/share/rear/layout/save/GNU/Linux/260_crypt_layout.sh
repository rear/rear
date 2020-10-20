# Describe LUKS devices
# We use /etc/crypttab and cryptsetup for information

# Skip when not needed:
has_binary cryptsetup || return 0

Log "Saving Encrypted volumes"

# cryptsetup is required in the recovery system if disklayout.conf contains at least one 'crypt' entry
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

    if ! blkid -p -o export $source_device >$TMP_DIR/blkid.output ; then
        LogPrintError "Error: Cannot get attributes for $target_name ('blkid -p -o export  $source_device' failed)"
        continue
    fi

    if ! grep -q "TYPE=crypto_LUKS" $TMP_DIR/blkid.output ; then
        Log "Skipping $target_name (its $source_device is not a LUKS device)"
        continue
    fi

    # Detect LUKS version
    version=$( grep "VERSION" $TMP_DIR/blkid.output | cut -d= -f2 )
    if !( test $version = "1" || test $version = "2") ; then
        LogPrintError "Error: Unsupported LUKS version for $target_name"
        continue
    fi
    luks_type=luks$version

    # Gather crypt information:
    if ! cryptsetup luksDump $source_device >$TMP_DIR/cryptsetup.luksDump ; then
        LogPrintError "Error: Cannot get LUKS values for $target_name ('cryptsetup luksDump $source_device' failed)"
        continue
    fi
    uuid=$( grep "UUID" $TMP_DIR/cryptsetup.luksDump | sed -r 's/^.+:\s*(.+)$/\1/' )
    keyfile_option=$( [ -f /etc/crypttab ] && awk '$1 == "'"$target_name"'" && $3 != "none" && $3 != "-" && $3 != "" { print "keyfile=" $3; }' /etc/crypttab )
    if test $luks_type = "luks1" ; then
        cipher_name=$( grep "Cipher name" $TMP_DIR/cryptsetup.luksDump | sed -r 's/^.+:\s*(.+)$/\1/' )
        cipher_mode=$( grep "Cipher mode" $TMP_DIR/cryptsetup.luksDump | cut -d: -f2- | awk '{printf("%s",$1)};' )
        cipher=$cipher_name-$cipher_mode
        key_size=$( grep "MK bits" $TMP_DIR/cryptsetup.luksDump | sed -r 's/^.+:\s*(.+)$/\1/' )
        hash=$( grep "Hash spec" $TMP_DIR/cryptsetup.luksDump | sed -r 's/^.+:\s*(.+)$/\1/' )
    elif test $luks_type = "luks2" ; then
        cipher=$( grep "cipher:" $TMP_DIR/cryptsetup.luksDump | sed -r 's/^.+:\s*(.+)$/\1/' )
        key_size=$( grep "Cipher key" $TMP_DIR/cryptsetup.luksDump | sed -r 's/^.+:\s*(.+) bits$/\1/' )
        hash=$( grep "Hash" $TMP_DIR/cryptsetup.luksDump | sed -r 's/^.+:\s*(.+)$/\1/' )
    fi

    echo "crypt /dev/mapper/$target_name $source_device type=$luks_type cipher=$cipher key_size=$key_size hash=$hash uuid=$uuid $keyfile_option" >> $DISKLAYOUT_FILE

done < <( dmsetup ls --target crypt )


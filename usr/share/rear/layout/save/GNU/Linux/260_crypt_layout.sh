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

local invalid_cryptsetup_option_value="no"

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
        LogPrintError "Error: Cannot get attributes for $target_name ('blkid -p -o export $source_device' failed)"
        continue
    fi

    if ! grep -q "TYPE=crypto_LUKS" $TMP_DIR/blkid.output ; then
        Log "Skipping $target_name (no 'TYPE=crypto_LUKS' in 'blkid -p -o export $source_device' output)"
        continue
    fi

    # Detect LUKS version:
    # Remove all non-digits in particular to avoid leading or trailing spaces in the version string
    # cf. "Beware of the emptiness" in https://github.com/rear/rear/wiki/Coding-Style
    # that could happen if the blkid output contains "VERSION = 2" so that 'cut -d= -f2' results " 2".
    version=$( grep "VERSION" $TMP_DIR/blkid.output | cut -d= -f2 | tr -c -d '[:digit:]' )
    if ! test "$version" = "1" -o "$version" = "2" ; then
        LogPrintError "Error: Unsupported LUKS version for $target_name ('blkid -p -o export $source_device' shows 'VERSION=$version')"
        continue
    fi
    luks_type=luks$version

    luksDump_cmd="cryptsetup luksDump $source_device"

    # Gather crypt information:
    if ! $luksDump_cmd >$TMP_DIR/cryptsetup.luksDump ; then
        LogPrintError "Error: Cannot get LUKS$version values for $target_name ('$luksDump_cmd' failed)"
        continue
    fi

    uuid=$( grep "UUID" $TMP_DIR/cryptsetup.luksDump | sed -r 's/^.+:\s*(.+)$/\1/' )
    keyfile_option=$( [ -f /etc/crypttab ] && awk '$1 == "'"$target_name"'" && $3 != "none" && $3 != "-" && $3 != "" { print "keyfile=" $3; }' /etc/crypttab )
    pbkdf_option=""

    if test $luks_type = "luks1" ; then

        cipher_name=$( grep "Cipher name" $TMP_DIR/cryptsetup.luksDump | sed -r 's/^.+:\s*(.+)$/\1/' )
        cipher_mode=$( grep "Cipher mode" $TMP_DIR/cryptsetup.luksDump | cut -d: -f2- | awk '{printf("%s",$1)};' )
        cipher=$cipher_name-$cipher_mode
        key_size=$( grep "MK bits" $TMP_DIR/cryptsetup.luksDump | sed -r 's/^.+:\s*(.+)$/\1/' )
        hash=$( grep "Hash spec" $TMP_DIR/cryptsetup.luksDump | sed -r 's/^.+:\s*(.+)$/\1/' )

    elif test $luks_type = "luks2" ; then

        keyslots_section=$( awk '/^Keyslots:/ {include=1;next} /^[[:upper:]]/ && include {exit} include' $TMP_DIR/cryptsetup.luksDump )
        if [ -z "$keyslots_section" ]; then
            LogPrintError "Error: No Keyslots section found in '$luksDump_cmd' output"
            continue
        fi
        if [ $( grep -c -P '^\s+\d+: luks2' <<< "$keyslots_section" ) -gt 1 ]; then
            LogPrintError "Warning: More than one luks2 keyslot found in '$luksDump_cmd' output, will only consider the first keyslot during recovery"
        fi
        luks2_section=$( awk '/^[[:blank:]]+[[:digit:]]+:/ && include {exit} /^[[:blank:]]+[[:digit:]]+: luks2/{include=1} include' <<< "$keyslots_section")

        cipher=$( grep "Cipher:" <<< "$luks2_section" | sed -r 's/^.+:\s*(.+)$/\1/' )
        pbkdf=$( grep "PBKDF:" <<< "$luks2_section" | sed -r 's/^.+:\s*(.+)$/\1/' )
        if [ -z "$pbkdf" ]; then
            LogPrintError "Warning: no PBKDF found in luks2 keyslot of '$luksDump_cmd' output, will use defaults during recovery"
        else
            pbkdf_option="pbkdf=$pbkdf"
        fi

        # Depending on the version the "cryptsetup luksDump" command outputs the key_size value
        # as a line like
        #         Key:        512 bits
        # and/or as a line like
        #         Cipher key: 512 bits
        # cf. https://github.com/rear/rear/pull/2504#issuecomment-718729198 and subsequent comments
        key_size=$( grep -E "Key:|Cipher key:" <<< "$luks2_section" | sed -r 's/^.+:\s*(.+) bits$/\1/' | sort -u )
        if [ -z "$key_size" ]; then
            LogPrintError "Error: No key size found in luks2 keyslot of '$luksDump_cmd' output"
        elif [ $( wc -w <<< "$key_size" ) -gt 1 ]; then
            LogPrintError "Error: Too many key sizes found in luks2 keyslot of '$luksDump_cmd' output"
            key_size=""
        fi

        hash=$( grep "AF hash:" <<< "$luks2_section" | sed -r 's/^.+:\s*(.+)$/\1/' )
        if [ -z "$hash" ]; then
            # Fallback to using Hash field found in Digests section
            digests_section=$( awk '/^Digests:/ {include=1;next} /^[[:upper:]]/ && include {exit} include' $TMP_DIR/cryptsetup.luksDump )
            hash=$( grep "Hash:" <<< "$digests_section" | sed -r 's/^.+:\s*(.+)$/\1/' | sort -u )
            if [ -z "$hash" ]; then
                LogPrintError "Warning: No Hash found in Digests section of '$luksDump_cmd' output, will use default type during recovery"
            elif [ $( wc -w <<< "$hash" ) -gt 1 ]; then
                hash=$( head -1 <<< "$hash" )
                LogPrintError "Warning: Too many Hash found in Digests section of '$luksDump_cmd' output, will use '$hash' during recovery"
            fi
        fi

    fi

    # Basic checks that the cipher key_size hash uuid values exist
    # cf. https://github.com/rear/rear/pull/2504#issuecomment-718729198
    # because some values are needed during "rear recover"
    # to set cryptsetup options in layout/prepare/GNU/Linux/160_include_luks_code.sh
    # and it seems cryptsetup fails when options with empty values are specified
    # cf. https://github.com/rear/rear/pull/2504#issuecomment-719479724
    # For example a LUKS1 crypt entry in disklayout.conf looks like
    # crypt /dev/mapper/luks1test /dev/sda7 type=luks1 cipher=aes-xts-plain64 key_size=256 hash=sha256 uuid=1b4198c9-d9b0-4c57-b9a3-3433e391e706
    # and a LUKS2 crypt entry in disklayout.conf looks like
    # crypt /dev/mapper/luks2test /dev/sda8 type=luks2 cipher=aes-xts-plain64 key_size=256 hash=sha256 uuid=3e874a28-7415-4f8c-9757-b3f28a96c4d2 pbkdf=argon2id
    # Only the keyfile_option value is optional and the luks_type value is already tested above.
    # Using plain test to ensure a value is a single non empty and non blank word
    # without quoting because test " " would return zero exit code
    # cf. "Beware of the emptiness" in https://github.com/rear/rear/wiki/Coding-Style
    # Do not error out instantly here but only report errors here so the user can see all messages
    # and actually error out at the end of this script if there was one actually invalid value:
    if ! test $cipher ; then
        LogPrint "No 'cipher' value for LUKS$version volume $target_name in $source_device"
    fi
    if test $key_size ; then
        if ! is_positive_integer $key_size ; then
            LogPrintError "Error: 'key_size=$key_size' is no positive integer for LUKS$version volume $target_name in $source_device"
            invalid_cryptsetup_option_value="yes"
        fi
    else
        LogPrint "No 'key_size' value for LUKS$version volume $target_name in $source_device"
    fi
    if ! test $hash ; then
        LogPrint "No 'hash' value for LUKS$version volume $target_name in $source_device"
    fi
    if ! test $uuid ; then
        # Report a missig uuid value as an error to have the user informed
        # but do not error out here because things can be fixed manually during "rear recover"
        # cf. https://github.com/rear/rear/pull/2506#issuecomment-721757810
        # and https://github.com/rear/rear/pull/2506#issuecomment-722315498
        # and https://github.com/rear/rear/issues/2509
        LogPrintError "Error: No 'uuid' value for LUKS$version volume $target_name in $source_device (mounting it or booting the recreated system may fail)"
    fi

    {
        echo -n "crypt /dev/mapper/$target_name $source_device type=$luks_type cipher=$cipher key_size=$key_size hash=$hash uuid=$uuid"
        [ -n "$keyfile_option" ] && echo -n " $keyfile_option"
        [ -n "$pbkdf_option" ] && echo -n " $pbkdf_option"
        echo
    } >> $DISKLAYOUT_FILE

done < <( dmsetup ls --target crypt )

# Let this script return successfully when invalid_cryptsetup_option_value is not true:
is_true $invalid_cryptsetup_option_value && Error "Invalid or empty LUKS cryptsetup option value(s) in $DISKLAYOUT_FILE" || true

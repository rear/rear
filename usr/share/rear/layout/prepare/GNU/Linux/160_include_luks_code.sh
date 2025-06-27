
# Code to recreate and/or open LUKS volumes.

create_crypt() {
    # See the create_device() function in lib/layout-functions.sh what "device type" means:
    local device_type="$1"
    if ! grep -q "^crypt $device_type " "$LAYOUT_FILE" ; then
        LogPrintError "Skip recreating LUKS volume $device_type (no 'crypt $device_type' entry in $LAYOUT_FILE)"
        # FIXME: The return code is ignored in the create_device() function in lib/layout-functions.sh:
        return 1
    fi
    
    local crypt target_device source_device options
    local mapping_name option key value
    local cryptsetup_options="" keyfile="" password=""

    read crypt target_device source_device options < <( grep "^crypt $device_type " "$LAYOUT_FILE" )

    # Careful! One cannot 'test -b $source_device' here at the time when this code is run
    # because the source device is usually a disk partition block device like /dev/sda2
    # but disk partition block devices usually do not yet exist (in particular not on a new clean disk)
    # because partitions are actually created later when the diskrestore.sh script is run
    # but not here when this code is run which only generates the diskrestore.sh script:
    if ! test $source_device ; then
        LogPrintError "Skip recreating LUKS volume $device_type: No source device (see the 'crypt $device_type' entry in $LAYOUT_FILE)"
        # FIXME: The return code is ignored in the create_device() function in lib/layout-functions.sh:
        return 1
    fi

    mapping_name=${target_device#/dev/mapper/}
    if ! test $mapping_name ; then
        LogPrintError "Skip recreating LUKS volume $device_type on $source_device: No /dev/mapper/... mapping name (see the 'crypt $device_type' entry in $LAYOUT_FILE)"
        # FIXME: The return code is ignored in the create_device() function in lib/layout-functions.sh:
        return 1
    fi

    for option in $options ; do
        # $option is of the form keyword=value and
        # we assume keyword has no '=' character but value could be anything that may have a '=' character
        # so we split keyword=value at the leftmost '=' character so that
        # e.g. keyword=foo=bar gets split into key="keyword" and value="foo=bar":
        key=${option%%=*}
        value=${option#*=}
        # The "cryptseup luksFormat" command does not require any of the type, cipher, key-size, hash, uuid option values
        # because if omitted a cryptseup default value is used so we treat those values as optional.
        # Using plain test to ensure the value is a single non empty and non blank word
        # without quoting because test " " would return zero exit code
        # cf. "Beware of the emptiness" in https://github.com/rear/rear/wiki/Coding-Style
        case "$key" in
            (type)
                test $value && cryptsetup_options+=" --type $value"
                ;;
            (cipher)
                test $value && cryptsetup_options+=" --cipher $value"
                ;;
            (key_size)
                test $value && cryptsetup_options+=" --key-size $value"
                ;;
            (hash)
                test $value && cryptsetup_options+=" --hash $value"
                ;;
            (uuid)
                test $value && cryptsetup_options+=" --uuid $value"
                ;;
            (pbkdf)
                test $value && cryptsetup_options+=" --pbkdf $value"
                ;;
            (keyfile)
                test $value && keyfile=$value
                ;;
            (password)
                test $value && password=$value
                ;;
            (*)
                LogPrintError "Skipping unsupported LUKS cryptsetup option '$key' in 'crypt $target_device $source_device' entry in $LAYOUT_FILE"
                ;;
        esac
    done

    cryptsetup_options+=" $LUKS_CRYPTSETUP_OPTIONS"

    (
    echo "LogPrint \"Creating LUKS volume $mapping_name on $source_device\""
    if [ -n "$keyfile" ] ; then
        # Assign a temporary keyfile at this stage so that original keyfiles do not leak onto the rescue medium.
        # The original keyfile will be restored from the backup and then re-assigned to the LUKS device in the
        # 'finalize' stage.
        # The scheme for generating a temporary keyfile path must be the same here and in the 'finalize' stage.
        keyfile="$TMP_DIR/LUKS-keyfile-$mapping_name"
        dd bs=512 count=4 if=/dev/urandom of="$keyfile"
        chmod u=rw,go=- "$keyfile"
        echo "cryptsetup luksFormat --batch-mode $cryptsetup_options $source_device $keyfile"
        echo "cryptsetup luksOpen --key-file $keyfile $source_device $mapping_name"
    elif [ -n "$password" ] ; then
        echo "echo \"$password\" | cryptsetup luksFormat --batch-mode $cryptsetup_options $source_device"
        echo "echo \"$password\" | cryptsetup luksOpen $source_device $mapping_name"
    else
        echo "LogUserOutput \"Set the password for LUKS volume $mapping_name (for 'cryptsetup luksFormat' on $source_device):\""
        echo "cryptsetup luksFormat --batch-mode $cryptsetup_options $source_device"
        echo "LogUserOutput \"Enter the password for LUKS volume $mapping_name (for 'cryptsetup luksOpen' on $source_device):\""
        echo "cryptsetup luksOpen $source_device $mapping_name"
    fi
    echo ""
    ) >> "$LAYOUT_CODE"
}

# Function open_crypt() is meant to be used by the 'mountonly' workflow
open_crypt() {
    # See the do_mount_device() function in lib/layout-functions.sh what "device type" means:
    local device_type="$1"
    if ! grep -q "^crypt $device_type " "$LAYOUT_FILE" ; then
        LogPrintError "Skip opening LUKS volume $device_type (no 'crypt $device_type' entry in $LAYOUT_FILE)"
        # FIXME: The return code is ignored in the do_mount_device() function in lib/layout-functions.sh:
        return 1
    fi

    local crypt target_device source_device options
    local mapping_name option key value
    local cryptsetup_options="" keyfile="" password=""

    read crypt target_device source_device options < <( grep "^crypt $device_type " "$LAYOUT_FILE" )

    if ! test -b "$source_device" ; then
        LogPrintError "Skip opening LUKS volume $device_type on device '$source_device' that is no block device (see the 'crypt $device_type' entry in $LAYOUT_FILE)"
        # FIXME: The return code is ignored in the do_mount_device() function in lib/layout-functions.sh:
        return 1
    fi

    mapping_name=${target_device#/dev/mapper/}
    if ! test $mapping_name ; then
        LogPrintError "Skip opening LUKS volume $device_type on $source_device: No /dev/mapper/... mapping name (see the 'crypt $device_type' entry in $LAYOUT_FILE)"
        # FIXME: The return code is ignored in the do_mount_device() function in lib/layout-functions.sh:
        return 1
    fi

    for option in $options ; do
        # $option is of the form keyword=value and
        # we assume keyword has no '=' character but value could be anything that may have a '=' character
        # so we split keyword=value at the leftmost '=' character so that
        # e.g. keyword=foo=bar gets split into key="keyword" and value="foo=bar":
        key=${option%%=*}
        value=${option#*=}
        case "$key" in
            (keyfile)
                test $value && keyfile=$value
                ;;
            (password)
                test $value && password=$value
                ;;
        esac
    done

    (
    echo "LogPrint \"Opening LUKS volume $mapping_name on $source_device\""
    if [ -n "$keyfile" ] ; then
        # During a 'mountonly' workflow, the original keyfile is supposed to be
        # available at this point.
        echo "cryptsetup luksOpen --key-file $keyfile $source_device $mapping_name"
    elif [ -n "$password" ] ; then
        echo "echo \"$password\" | cryptsetup luksOpen $source_device $mapping_name"
    else
        echo "LogUserOutput \"Enter the password for LUKS volume $mapping_name (for 'cryptsetup luksOpen' on $source_device):\""
        echo "cryptsetup luksOpen $source_device $mapping_name"
    fi
    echo ""
    ) >> "$LAYOUT_CODE"
}

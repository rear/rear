# Code to recreate and/or open LUKS volumes.

create_crypt() {
    # See the create_device() function in lib/layout-functions.sh what "device type" means:
    local device_type="$1"
    if ! grep -q "^crypt $device_type " "$LAYOUT_FILE" ; then
        LogPrintError "Skip recreating LUKS device $device_type (no 'crypt $device_type' entry in $LAYOUT_FILE)"
        # FIXME: The return code is ignored in the create_device() function in lib/layout-functions.sh:
        return 1
    fi
    
    local crypt target_device source_device options
    read crypt target_device source_device options < <( grep "^crypt $device_type " "$LAYOUT_FILE" )
    local target_name=${target_device#/dev/mapper/}
    local cryptsetup_options="" keyfile="" password=""
    local option key value
    for option in $options ; do
        key=${option%=*}
        value=${option#*=}
        # The "cryptseup luksFormat" command does not require any of the cipher, key-size, hash option values
        # because if omitted a cryptseup default value is used so treat those values as optional.
        # Using plain test to ensure the value is a single non empty and non blank word
        # without quoting because test " " would return zero exit code
        # cf. "Beware of the emptiness" in https://github.com/rear/rear/wiki/Coding-Style
        case "$key" in
            (type)
                cryptsetup_options+=" --type $value"
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
                cryptsetup_options+=" --uuid $value"
                ;;
            (keyfile)
                keyfile=$value
                ;;
            (password)
                password=$value
                ;;
            (*)
                LogPrintError "Skipping unsupported LUKS cryptsetup option '$key' in 'crypt $target_device $source_device' entry in $LAYOUT_FILE"
                ;;
        esac
    done

    cryptsetup_options+=" $LUKS_CRYPTSETUP_OPTIONS"

    (
    echo "Log \"Creating LUKS device $target_name on $source_device\""
    if [ -n "$keyfile" ] ; then
        # Assign a temporary keyfile at this stage so that original keyfiles do not leak onto the rescue medium.
        # The original keyfile will be restored from the backup and then re-assigned to the LUKS device in the
        # 'finalize' stage.
        # The scheme for generating a temporary keyfile path must be the same here and in the 'finalize' stage.
        keyfile="$TMP_DIR/LUKS-keyfile-$target_name"
        dd bs=512 count=4 if=/dev/urandom of="$keyfile"
        chmod u=rw,go=- "$keyfile"
        echo "cryptsetup luksFormat --batch-mode $cryptsetup_options $source_device $keyfile"
        echo "cryptsetup luksOpen --key-file $keyfile $source_device $target_name"
    elif [ -n "$password" ] ; then
        echo "echo \"$password\" | cryptsetup luksFormat --batch-mode $cryptsetup_options $source_device"
        echo "echo \"$password\" | cryptsetup luksOpen $source_device $target_name"
    else
        echo "LogPrint \"Set the password for LUKS device $target_name (for 'cryptsetup luksFormat' on $source_device):\""
        echo "cryptsetup luksFormat --batch-mode $cryptsetup_options $source_device"
        echo "LogPrint \"Enter the password for LUKS device $target_name (for 'cryptsetup luksOpen' on $source_device):\""
        echo "cryptsetup luksOpen $source_device $target_name"
    fi
    echo ""
    ) >> "$LAYOUT_CODE"
}

# Function open_crypt() is meant to be used by the 'mountonly' workflow
open_crypt() {
    local crypt target_device source_device options
    read crypt target_device source_device options < <(grep "^crypt $1 " "$LAYOUT_FILE")

    local target_name=${target_device#/dev/mapper/}

    local cryptsetup_options="" keyfile="" password=""
    local option key value
    for option in $options ; do
        key=${option%=*}
        value=${option#*=}
        case "$key" in
            (keyfile)
                keyfile=$value
                ;;
            (password)
                password=$value
                ;;
        esac
    done

    (
    echo "Log \"Opening LUKS device $target_name on $source_device\""
    if [ -n "$keyfile" ] ; then
        # During a 'mountonly' workflow, the original keyfile is supposed to be
        # available at this point.
        echo "cryptsetup luksOpen --key-file $keyfile $source_device $target_name"
    elif [ -n "$password" ] ; then
        echo "echo \"$password\" | cryptsetup luksOpen $source_device $target_name"
    else
        echo "LogPrint \"Enter the password for LUKS device $target_name (for 'cryptsetup luksOpen' on $source_device):\""
        echo "cryptsetup luksOpen $source_device $target_name"
    fi
    echo ""
    ) >> "$LAYOUT_CODE"
}

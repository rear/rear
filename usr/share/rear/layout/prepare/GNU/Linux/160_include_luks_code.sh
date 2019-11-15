# Code to recreate and/or open LUKS volumes.

create_crypt() {
    local crypt target_device source_device options
    read crypt target_device source_device options < <(grep "^crypt $1 " "$LAYOUT_FILE")

    local target_name=${target_device#/dev/mapper/}

    local cryptsetup_options="" keyfile="" password=""
    local option key value
    for option in $options ; do
        key=${option%=*}
        value=${option#*=}

        case "$key" in
            cipher)
                cryptsetup_options+=" --cipher $value"
                ;;
            key_size)
                cryptsetup_options+=" --key-size $value"
                ;;
            hash)
                cryptsetup_options+=" --hash $value"
                ;;
            uuid)
                cryptsetup_options+=" --uuid $value"
                ;;
            keyfile)
                keyfile=$value
                ;;
            password)
                password=$value
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
        keyfile="${TMPDIR:-/tmp}/LUKS-keyfile-$target_name"
        dd bs=512 count=4 if=/dev/urandom of="$keyfile"
        chmod u=rw,go=- "$keyfile"

        echo "cryptsetup luksFormat --batch-mode $cryptsetup_options $source_device $keyfile"
        echo "cryptsetup luksOpen --key-file $keyfile $source_device $target_name"
    elif [ -n "$password" ] ; then
        echo "echo \"$password\" | cryptsetup luksFormat --batch-mode $cryptsetup_options $source_device"
        echo "echo \"$password\" | cryptsetup luksOpen $source_device $target_name"
    else
        echo "LogPrint \"Please enter the password for LUKS device $target_name ($source_device):\""
        echo "cryptsetup luksFormat --batch-mode $cryptsetup_options $source_device"
        echo "LogPrint \"Please re-enter the password for LUKS device $target_name ($source_device):\""
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
            keyfile)
                keyfile=$value
                ;;
            password)
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
        echo "LogPrint \"Please enter the password for LUKS device $target_name ($source_device):\""
        echo "cryptsetup luksOpen $source_device $target_name"
    fi
    echo ""
    ) >> "$LAYOUT_CODE"
}

# Code to recreate LUKS volumes.

create_crypt() {
    local crypt device encdevice options
    read crypt device encdevice options < <(grep "^crypt $1 " "$LAYOUT_FILE")

    local name=${device#/dev/mapper/}

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
    echo "Log \"Creating luks device $name on $encdevice\""
    if [ -n "$keyfile" ] ; then
        # Assign a temporary keyfile at this stage so that original keyfiles do not leak onto the rescue medium.
        # The original keyfile will be restored from the backup and then re-assigned to the LUKS device in the
        # 'finalize' stage.
        # The scheme for generating a temporary keyfile path must be the same here and in the 'finalize' stage.
        keyfile="${TMPDIR:-/tmp}/LUKS-keyfile-$(basename $keyfile)"
        dd bs=512 count=4 if=/dev/urandom of="$keyfile"
        chmod u=rw,go=- "$keyfile"

        echo "cryptsetup luksFormat --batch-mode $cryptsetup_options $encdevice $keyfile"
        echo "cryptsetup luksOpen --key-file $keyfile $encdevice $name"
    elif [ -n "$password" ] ; then
        echo "echo \"$password\" | cryptsetup luksFormat --batch-mode $cryptsetup_options $encdevice"
        echo "echo \"$password\" | cryptsetup luksOpen $encdevice $name"
    else
        echo "LogPrint \"Please enter the password for $name($encdevice):\""
        echo "cryptsetup luksFormat --batch-mode $cryptsetup_options $encdevice"
        echo "LogPrint \"Please re-enter the password for $name($encdevice):\""
        echo "cryptsetup luksOpen $encdevice $name"
    fi
    echo ""
    ) >> "$LAYOUT_CODE"
}

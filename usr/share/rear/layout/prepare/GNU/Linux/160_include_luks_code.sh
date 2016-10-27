# Code to recreate LUKS volumes.

create_crypt() {
    local crypt device encdevice options
    read crypt device encdevice options < <(grep "^crypt $1 " "$LAYOUT_FILE")

    local name=${device#/dev/mapper/}

    local cipher="" hash="" uuid="" keyfile="" password=""
    local option key value
    for option in $options ; do
        key=${option%=*}
        value=${option#*=}

        case "$key" in
            cipher)
                cipher=" --cipher $value"
                ;;
            mode)
                cipher="$cipher-$value"
                ;;
            hash)
                hash=" --hash $value"
                ;;
            uuid)
                uuid=" --uuid $value"
                ;;
            key)
                keyfile=$value
                ;;
            password)
                password=$value
                ;;
        esac
    done

    (
    echo "Log \"Creating luks device $name on $encdevice\""
    if [ -n "$keyfile" ] ; then
        echo "cryptsetup luksFormat -q${cipher}${hash}${uuid} ${encdevice} $keyfile"
        echo "cryptsetup luksOpen --key-file $keyfile $encdevice $name"
    elif [ -n "$password" ] ; then
        echo "echo \"$password\" | cryptsetup luksFormat -q${cipher}${hash}${uuid} ${encdevice}"
        echo "echo \"$password\" | cryptsetup luksOpen $encdevice $name"
    else
        echo "LogPrint \"Please enter the password for $name($encdevice):\""
        echo "cryptsetup luksFormat -q${cipher}${hash}${uuid} ${encdevice}"
        echo "LogPrint \"Please re-enter the password for $name($encdevice):\""
        echo "cryptsetup luksOpen $encdevice $name"
    fi
    echo ""
    ) >> "$LAYOUT_CODE"
}

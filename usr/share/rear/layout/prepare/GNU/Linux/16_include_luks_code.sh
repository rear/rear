# Code to recreate LUKS volumes

create_crypt() {
    local crypt device encdevice options
    read crypt device encdevice options < <(grep "^crypt $1" $LAYOUT_FILE)

    local name=${device#/dev/mapper/}

    local cipher="" hash="" uuid="" keyfile="" password=""
    local option key value
    for option in $options ; do
        key=${option%=*}
        value=${option#*=}

        case $key in
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

    echo "Log \"Creating luks device $name on $encdevice\"" >> $LAYOUT_CODE
    if [ -n "$keyfile" ] ; then
        echo "cryptsetup luksFormat -q${cipher}${hash} ${encdevice} $keyfile" >> $LAYOUT_CODE
        echo "cryptsetup luksOpen --key-file $keyfile $encdevice $name" >> $LAYOUT_CODE
    elif [ -n "$password" ] ; then
        echo "echo \"$password\" | cryptsetup luksFormat -q${cipher}${hash} ${encdevice}" >> $LAYOUT_CODE
        echo "echo \"$password\" | cryptsetup luksOpen $encdevice $name" >> $LAYOUT_CODE
    else
        echo "LogPrint \"Please enter the password for $name($encdevice):\"" >> $LAYOUT_CODE
        echo "cryptsetup luksFormat -q${cipher}${hash} ${encdevice}" >> $LAYOUT_CODE
        echo "LogPrint \"Please re-enter the password for $name($encdevice):\"" >> $LAYOUT_CODE
        echo "cryptsetup luksOpen $encdevice $name" >> $LAYOUT_CODE
    fi
    echo "" >> $LAYOUT_CODE
}

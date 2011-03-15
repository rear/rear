# Code to recreate LUKS volumes

create_crypt() {
    read crypt device encdevice options < $1
    
    name=${device#/dev/mapper/}
    
    cipher=""
    hash=""
    uuid=""
    keyfile=""
    password=""
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

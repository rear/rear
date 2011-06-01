# Describe luks devices
# We use /etc/crypttab and cryptsetup for information

if ! type cryptsetup &>/dev/null ; then
    return
fi

Log "Saving Encrypted volumes."
REQUIRED_PROGS=( "${REQUIRED_PROGS[@]}" cryptsetup )

for device in /dev/mapper/* ; do
    if ! cryptsetup isLuks $device &>/dev/null; then
        continue
    fi
    
    # gather crypt information
    cipher=$(cryptsetup luksDump $device | grep "Cipher name" | sed -r 's/^.+:[^a-z]+(.+)$/\1/')
    mode=$(cryptsetup luksDump $device | grep "Cipher mode" | sed -r 's/^.+:[^a-z]+(.+)$/\1/')
    hash=$(cryptsetup luksDump $device | grep "Hash spec" | sed -r 's/^.+:[^a-z]+(.+)$/\1/')
    uuid=$(cryptsetup luksDump $device | grep "UUID" | sed -r 's/^.+:[^a-z]+(.+)$/\1/')
    
    # Search for a keyfile or password.
    keyfile=""
    password=""
    if [ -e /etc/crypttab ] ; then
        while read name path key junk ; do
            # skip blank lines, comments and non-block devices
            if [ -n "$name" ] && [ "${name#\#}" = "$name" ] && [ -b "$path" ] && [ "$path" = "$device" ] ; then
                # manual password
                if [ "$key" = "none" ] ; then
                    break
                elif [ -e "$key" ] ; then
                    # keyfile
                    keyfile=" key=$key"
                    COPY_AS_IS=( "${COPY_AS_IS[@]}" $key )
                else
                    # password
                    password=" password=$key"
                fi
                break
            fi
        done < /etc/crypttab
    fi
    
    echo "crypt /dev/mapper/$name $device cipher=$cipher mode=$mode hash=$hash uuid=${uuid}${keyfile}${password}" >> $DISKLAYOUT_FILE
done

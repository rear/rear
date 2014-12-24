# rewrite all the network configuration files for SUSE LINUX according
# to the mapping files

PATCH_FILES=( /mnt/local/etc/sysconfig/*/ifcfg-* )

# skip if no network configuration files are found
test $PATCH_FILES || return 0


# strip all comments and empty lines from the mapping files and copy
# the results to a temporary directory
mkdir -p $TMP_DIR/mappings
StopIfError "Could not create $TMP_DIR/mappings"
for mapping_file in mac ip_addresses routes ; do
    read_and_strip_file $CONFIG_DIR/mappings/$mapping_file > $TMP_DIR/mappings/$mapping_file
done


# rewrite the changed mac addresses if a valid mapping exists
if test -s $TMP_DIR/mappings/mac ; then

    # create sed script
    SED_SCRIPT=""
    while read old_mac new_mac dev ; do
        SED_SCRIPT="$SED_SCRIPT;s/$old_mac/$new_mac/g"
    done < <( read_and_strip_file $CONFIG_DIR/mappings/mac | sed -e 'p;y/abcdef/ABCDEF/' )
    #                                              ^^^^^^^
    #       this is a nasty hack that prints each line as is (lowercase) and once again in uppercase
    #       the reason is that the mac mappings are in lower case but some systems seem to keep
    #       the MAC adresses in upper case and since I don't want to mess with this I treat it as
    #       separate things and do the replacement case-sensitive

    Log "SED_SCRIPT: '$SED_SCRIPT'"
    sed -i -e "$SED_SCRIPT" "${PATCH_FILES[@]}"
    LogPrintIfError "WARNING! There was an error patching the network configuration files!"

    # rename files
    for file in "${PATCH_FILES[@]}"; do
        new_file="$(sed -e "$SED_SCRIPT" <<<"$file")"
        if test "$new_file" -a "$new_file" != "$file" ; then
            mv $v "$file" "$new_file" >&2
        fi
    done
fi

# for the unlikely case where an ip address mapping is supplied but a mac
# mapping is missing, we have to fake a mac mapping file. Otherwise the
# logic to rewrite the ip addresses wil fail.

if test -s $TMP_DIR/mappings/ip_addresses && ! test -s $TMP_DIR/mappings/mac ; then
    for interface in $(cut -f 1 -d " " $TMP_DIR/mappings/ip_addresses) ; do
        mac=$(cat /sys/class/net/$interface/address)
        echo "$mac $mac $interface" >> $TMP_DIR/mappings/mac
    done
fi

# change the ip addresses in the configuration files if a mapping is available
if test -s $TMP_DIR/mappings/ip_addresses ; then

    join -1 3 $TMP_DIR/mappings/mac $TMP_DIR/mappings/ip_addresses |\
    while read dev old_mac new_mac new_ip ; do
        for network_file in /mnt/local/etc/sysconfig/*/ifcfg-*${new_mac}* /mnt/local/etc/sysconfig/*/ifcfg-*${dev}*; do
            # RHEL 4, 5,... cannot handle IPADDR="x.x.x.x/cidr"
            nmask=$(prefix2netmask ${new_ip#*/})    # ipaddress/cidr (recalculate the cidr)
            if [[ "$nmask" = "0.0.0.0" ]]; then
                nmask=""
                nip="$new_ip"           # keep ipaddress/cidr
            else
                nip="${new_ip%%/*}"     # only keep ipaddress
            fi
            # TODO: what if NETMASK keyword is not defined? Should be keep new_ip then??
            SED_SCRIPT="s#^IPADDR=.*#IPADDR='${nip}'#g;s#^NETMASK=.*#NETMASK='${nmask}'#g;s#^NETWORK=.*#NETWORK=''#g;s#^BROADCAST=.*#BROADCAST=''#g;s#^BOOTPROTO=.*#BOOTPROTO='static'#g;s#STARTMODE='[mo].*#STARTMODE='auto'#g;/^IPADDR_/d;/^LABEL_/d;/^NETMASK_/d"
            Log "SED_SCRIPT: '$SED_SCRIPT'"
            LogPrint "Patching file ${network_file##*/}"
            sed -i -e "$SED_SCRIPT" "$network_file"
            LogPrintIfError "WARNING! There was an error patching the network configuration files!"
        done
    done
fi

# set the new routes if a mapping file is available
if test -s $TMP_DIR/mappings/routes ; then
    while read destination gateway device junk ; do
    #   echo "$destination $gateway - $device" >> /mnt/local/etc/sysconfig/network/routes
        if [[ "$destination" = "default" ]]; then
            for network_file in /mnt/local/etc/sysconfig/*/ifcfg-*${device}* /mnt/local/etc/sysconfig/network ; do
                SED_SCRIPT="s#^GATEWAY=.*#GATEWAY='$gateway'#g;s#^GATEWAYDEV=.*#GATEWAYDEV='$device'#g"
                Log "SED_SCRIPT: '$SED_SCRIPT'"
                sed -i -e "$SED_SCRIPT" "$network_file"
                LogPrintIfError "WARNING! There was an error patching the network configuration files!"
            done
        else
            # static-routes or route-<device> settings?
            for network_file in /mnt/local/etc/sysconfig/*/route-*${device}* /mnt/local/etc/sysconfig/static-routes ; do
                LogPrint "WARNING! Change entries in $network_file manually please!"
            done
        fi
    done < $TMP_DIR/mappings/routes
fi

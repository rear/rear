# rewrite all the network configuration files (currently Redhat/Suse/Debian/Ubuntu)
# accoring to the mapping files

# because the bash option nullglob is set in rear (see usr/sbin/rear)
# PATCH_FILES is empty if nothing matches $TARGET_FS_ROOT/etc/sysconfig/*/ifcfg-* $TARGET_FS_ROOT/etc/network/inter[f]aces or $TARGET_FS_ROOT/etc/network/interfaces.d/*
# $TARGET_FS_ROOT/etc/network/inter[f]aces is a special trick to only add $TARGET_FS_ROOT/etc/network/interfaces if it exists.
PATCH_FILES=( $TARGET_FS_ROOT/etc/sysconfig/*/ifcfg-* $TARGET_FS_ROOT/etc/network/inter[f]aces $TARGET_FS_ROOT/etc/network/interfaces.d/* )

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
        # get device name from mac in case of inet renaming
        new_dev=$( get_device_by_hwaddr "$new_mac" )
        if test "$new_dev" != "$old_dev" ; then
            SED_SCRIPT="$SED_SCRIPT;s/$dev/$new_dev/g"
        fi
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

# for the unlikely case where an ip address or routes mapping is supplied but a mac
# mapping is missing, we have to fake a mac mapping file. Otherwise the
# logic to rewrite the ip addresses or routes will fail.
# The easiest way is to be sure to always provide a mac mapping files with "old_mac new_mac interface" format
# with old_mac=new_mac for non-migrated interfaces.

if ! test -s $TMP_DIR/mappings/mac ; then
    for interface in $(cut -f 1 -d " " $TMP_DIR/mappings/ip_addresses) ; do
        mac=$(cat /sys/class/net/$interface/address)
        echo "$mac $mac $interface" >> $TMP_DIR/mappings/mac
    done
fi

# change the ip addresses in the configuration files if a mapping is available
if test -s $TMP_DIR/mappings/ip_addresses ; then

    join -1 3 $TMP_DIR/mappings/mac $TMP_DIR/mappings/ip_addresses |\
    while read dev old_mac new_mac new_ip ; do

        # RHEL 4, 5,... cannot handle IPADDR="x.x.x.x/cidr"
        nmask=$(prefix2netmask ${new_ip#*/})    # ipaddress/cidr (recalculate the cidr)
        if [[ "$nmask" = "0.0.0.0" ]]; then
            nmask=""
            nip="$new_ip"           # keep ipaddress/cidr
        else
            nip="${new_ip%%/*}"     # only keep ipaddress
        fi

        # Fedora/Suse Family
        for network_file in $TARGET_FS_ROOT/etc/sysconfig/*/ifcfg-*${new_mac}* $TARGET_FS_ROOT/etc/sysconfig/*/ifcfg-*${dev}*; do
            # TODO: what if NETMASK keyword is not defined? Should be keep new_ip then??
            SED_SCRIPT="s#^IPADDR=.*#IPADDR='${nip}'#g;s#^NETMASK=.*#NETMASK='${nmask}'#g;s#^NETWORK=.*#NETWORK=''#g;s#^BROADCAST=.*#BROADCAST=''#g;s#^BOOTPROTO=.*#BOOTPROTO='static'#g;s#STARTMODE='[mo].*#STARTMODE='auto'#g;/^IPADDR_/d;/^LABEL_/d;/^NETMASK_/d"
            Log "SED_SCRIPT: '$SED_SCRIPT'"
            LogPrint "Patching file ${network_file##*/}"
            sed -i -e "$SED_SCRIPT" "$network_file"
            LogPrintIfError "WARNING! There was an error patching the network configuration files!"
        done

        #Debian / ubuntu Family (with network interfaces configuration files)
        for network_file in $TARGET_FS_ROOT/etc/network/inter[f]aces $TARGET_FS_ROOT/etc/network/interfaces.d/* ; do
            new_dev=$( get_device_by_hwaddr "$new_mac" )
            SED_SCRIPT="\
                /iface $new_dev/ s/;address [0-9.]*;/;address ${nip};/g ;\
                /iface $new_dev/ s/;netmask [0-9.]*;/;netmask ${nmask};/g"
            Log "SED_SCRIPT: '$SED_SCRIPT'"

            tmp_network_file="$TMP_DIR/${network_file##*/}"
            linearize_interfaces_file "$network_file" > "$tmp_network_file"

            sed -i -e "$SED_SCRIPT" "$tmp_network_file"
            LogPrintIfError "WARNING! There was an error patching the network configuration files!"

            rebuild_interfaces_file_from_linearized "$tmp_network_file" > "$network_file"
        done
    done
fi

# set the new routes if a mapping file is available
if test -s $TMP_DIR/mappings/routes ; then

    join -1 3 -2 3  $TMP_DIR/mappings/mac $TMP_DIR/mappings/routes |\
    while read dev old_mac new_mac destination gateway device junk ; do
        #   echo "$destination $gateway - $device" >> $TARGET_FS_ROOT/etc/sysconfig/network/routes
        if [[ "$destination" = "default" ]]; then
            # Fedora/Suse Family
            for network_file in $TARGET_FS_ROOT/etc/sysconfig/*/ifcfg-*${device}* $TARGET_FS_ROOT/etc/sysconfig/network ; do
                SED_SCRIPT="s#^GATEWAY=.*#GATEWAY='$gateway'#g;s#^GATEWAYDEV=.*#GATEWAYDEV='$device'#g"
                Log "SED_SCRIPT: '$SED_SCRIPT'"
                sed -i -e "$SED_SCRIPT" "$network_file"
                LogPrintIfError "WARNING! There was an error patching the network configuration files!"
            done

            #Debian / ubuntu Family (with network interfaces configuration files)
            for network_file in $TARGET_FS_ROOT/etc/network/inter[f]aces $TARGET_FS_ROOT/etc/network/interfaces.d/* ; do
                new_dev=$( get_device_by_hwaddr "$new_mac" )
                SED_SCRIPT="/iface $new_dev/ s/;gateway [0-9.]*;/;gateway $gateway;/g"

                tmp_network_file="$TMP_DIR/${network_file##*/}"
                linearize_interfaces_file "$network_file" > "$tmp_network_file"

                sed -i -e "$SED_SCRIPT" "$tmp_network_file"
                LogPrintIfError "WARNING! There was an error patching the network configuration files!"

                rebuild_interfaces_file_from_linearized "$tmp_network_file" > "$network_file"
            done
        else
            # static-routes or route-<device> settings?
            for network_file in $TARGET_FS_ROOT/etc/sysconfig/*/route-*${device}* $TARGET_FS_ROOT/etc/sysconfig/static-routes ; do
                LogPrint "WARNING! Change entries in $network_file manually please!"
            done
        fi
    done
fi

# rewrite all the network configuration files (currently Redhat/Suse/Debian/Ubuntu)
# according to the mapping files

# because the bash option nullglob is set in rear (see usr/sbin/rear)
# PATCH_FILES is empty if nothing matches $TARGET_FS_ROOT/etc/sysconfig/*/ifcfg-* $TARGET_FS_ROOT/etc/network/inter[f]aces or $TARGET_FS_ROOT/etc/network/interfaces.d/*
# $TARGET_FS_ROOT/etc/network/inter[f]aces is a special trick to only add $TARGET_FS_ROOT/etc/network/interfaces if it exists.
PATCH_FILES=( $TARGET_FS_ROOT/etc/sysconfig/*/ifcfg-* $TARGET_FS_ROOT/etc/network/inter[f]aces $TARGET_FS_ROOT/etc/network/interfaces.d/* )

# skip if no network configuration files are found
test $PATCH_FILES || return 0

# Strip all comments and empty lines from the mapping files and copy the results to a temporary directory.
# Do not error out at this late state of "rear recover" (after the backup was restored) but inform the user:
if ! mkdir $v -p $TMP_DIR/mappings ; then
    LogPrintError "Cannot migrate network configuration files according to the mapping files (could not create $TMP_DIR/mappings)"
fi
for mapping_file in mac ip_addresses routes ; do
    read_and_strip_file $CONFIG_DIR/mappings/$mapping_file > $TMP_DIR/mappings/$mapping_file
done

LogPrint "Migrating network configuration files according to the mapping files ..."

# TODO:
# All finalize scripts that patch restored files within TARGET_FS_ROOTshould do the same symlink handling which means:
# 1. Skip patching symlink targets that are not within TARGET_FS_ROOT (i.e. when it is an absolute symlink)
# 2. Skip patching if the symlink target contains /proc/ /sys/ /dev/ or /run/
# 3. Skip patching dead symlinks
# See the symlink handling code in finalize/GNU/Linux/280_migrate_uuid_tags.sh and other such files,
# cf. https://github.com/rear/rear/pull/2055 and https://github.com/rear/rear/issues/1338

# rewrite the changed mac addresses if a valid mapping exists
if test -s $TMP_DIR/mappings/mac ; then

    # create sed script
    sed_script=""
    while read old_mac new_mac dev ; do
        sed_script="$sed_script;s/$old_mac/$new_mac/g"
        # get device name from mac in case of inet renaming
        new_dev=$( get_device_by_hwaddr "$new_mac" )
        if test "$new_dev" != "$old_dev" ; then
            sed_script="$sed_script;s/$dev/$new_dev/g"
        fi
    done < <( read_and_strip_file $CONFIG_DIR/mappings/mac | sed -e 'p;y/abcdef/ABCDEF/' )
    #                                              ^^^^^^^
    #       this is a nasty hack that prints each line as is (lowercase) and once again in uppercase
    #       the reason is that the mac mappings are in lower case but some systems seem to keep
    #       the MAC adresses in upper case and since I don't want to mess with this I treat it as
    #       separate things and do the replacement case-sensitive

    Debug "sed_script: '$sed_script'"

    for patch_file in "${PATCH_FILES[@]}" ; do
        sed -i -e "$sed_script" "$patch_file" || LogPrintError "Migrating network configuration in $patch_file failed"
    done

    # rename files
    for file in "${PATCH_FILES[@]}"; do
        new_file="$(sed -e "$sed_script" <<<"$file")"
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
            sed_script="s#^IPADDR=.*#IPADDR='${nip}'#g;s#^NETMASK=.*#NETMASK='${nmask}'#g;s#^NETWORK=.*#NETWORK=''#g;s#^BROADCAST=.*#BROADCAST=''#g;s#^BOOTPROTO=.*#BOOTPROTO='static'#g;s#STARTMODE='[mo].*#STARTMODE='auto'#g;/^IPADDR_/d;/^LABEL_/d;/^NETMASK_/d"
            Debug "sed_script: '$sed_script'"
            LogPrint "Patching file ${network_file##*/}"
            sed -i -e "$sed_script" "$network_file" || LogPrintError "Migrating network configuration in $network_file failed"
        done

        #Debian / ubuntu Family (with network interfaces configuration files)
        for network_file in $TARGET_FS_ROOT/etc/network/inter[f]aces $TARGET_FS_ROOT/etc/network/interfaces.d/* ; do
            new_dev=$( get_device_by_hwaddr "$new_mac" )
            sed_script="\
                /iface $new_dev/ s/;address [0-9.]*;/;address ${nip};/g ;\
                /iface $new_dev/ s/;netmask [0-9.]*;/;netmask ${nmask};/g"
            Debug "sed_script: '$sed_script'"

            tmp_network_file="$TMP_DIR/${network_file##*/}"
            linearize_interfaces_file "$network_file" > "$tmp_network_file"

            sed -i -e "$sed_script" "$tmp_network_file" || LogPrintError "Migrating network configuration for $network_file in $tmp_network_file failed"

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
                sed_script="s#^GATEWAY=.*#GATEWAY='$gateway'#g;s#^GATEWAYDEV=.*#GATEWAYDEV='$device'#g"
                Debug "sed_script: '$sed_script'"
                sed -i -e "$sed_script" "$network_file" || LogPrintError "Migrating network configuration in $network_file failed"
            done

            #Debian / ubuntu Family (with network interfaces configuration files)
            for network_file in $TARGET_FS_ROOT/etc/network/inter[f]aces $TARGET_FS_ROOT/etc/network/interfaces.d/* ; do
                new_dev=$( get_device_by_hwaddr "$new_mac" )
                sed_script="/iface $new_dev/ s/;gateway [0-9.]*;/;gateway $gateway;/g"
                Debug "sed_script: '$sed_script'"

                tmp_network_file="$TMP_DIR/${network_file##*/}"
                linearize_interfaces_file "$network_file" > "$tmp_network_file"

                sed -i -e "$sed_script" "$tmp_network_file" || LogPrintError "Migrating network configuration for $network_file in $tmp_network_file failed"

                rebuild_interfaces_file_from_linearized "$tmp_network_file" > "$network_file"
            done
        else
            # static-routes or route-<device> settings?
            for network_file in $TARGET_FS_ROOT/etc/sysconfig/*/route-*${device}* $TARGET_FS_ROOT/etc/sysconfig/static-routes ; do
                LogPrint "Cannot migrate network configuration in $network_file - you need to do that manually"
            done
        fi
    done
fi


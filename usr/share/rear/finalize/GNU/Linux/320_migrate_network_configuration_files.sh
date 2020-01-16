
# This script finalize/GNU/Linux/320_migrate_network_configuration_files.sh
# rewrites some network configuration files (cf. network_configuration_files below)
# (currently for Red Hat, SUSE, Debian, Ubuntu)
# as specified in the mapping files
#   /etc/rear/mappings/mac
#   /etc/rear/mappings/ip_addresses
#   /etc/rear/mappings/routes
# in the currently running ReaR recovery system.
# For the mapping files syntax see
#   doc/mappings/mac.example
#   doc/mappings/routes.example
#   doc/mappings/ip_addresses.example

local network_configuration_files=()
local mapping_file_name mapping_file_interface_field mapping_file_content
local sed_script=""
local old_mac new_mac interface junk
local new_interface
local current_mac

# Because the bash option nullglob is set in rear (see usr/sbin/rear) network_configuration_files is empty if nothing matches
# $TARGET_FS_ROOT/etc/sysconfig/*/ifcfg-* or $TARGET_FS_ROOT/etc/network/inter[f]aces or $TARGET_FS_ROOT/etc/network/interfaces.d/*
# and $TARGET_FS_ROOT/etc/network/inter[f]aces is a special trick to only add $TARGET_FS_ROOT/etc/network/interfaces if it exists:
network_configuration_files=( $TARGET_FS_ROOT/etc/sysconfig/*/ifcfg-* $TARGET_FS_ROOT/etc/network/inter[f]aces $TARGET_FS_ROOT/etc/network/interfaces.d/* )

# Skip if no network configuration files are found:
test $network_configuration_files || return 0

# Create a temporary directory for plain mapping files content without comments and empty lines.
# Do not error out at this late state of "rear recover" (after the backup was restored) but inform the user:
if ! mkdir $v -p $TMP_DIR/mappings ; then
    LogPrintError "Cannot migrate network configuration files according to the mapping files (could not create $TMP_DIR/mappings)"
    return 1
fi

# Strip all comments and empty lines from the mapping files and have plain mapping files content in the temporary directory.
# The plain mapping files content without comments or empty lines is needed to cleanly create the sed scripts below.
# Furthermore the lines in the mapping files must be sorted by the network interface field because later
# the lines of two mapping files are combined via 'join' on the common field interface:
for mapping_file_name in mac ip_addresses routes ; do
    case "$mapping_file_name" in
        (mac)
            # The network interface is the 3rd field in mappings/mac
            mapping_file_interface_field=3
            ;;
        (ip_addresses)
            # The network interface is the 1st field in mappings/ip_addresses
            mapping_file_interface_field=1
            ;;
        (routes)
            # The network interface is the 3rd field in mappings/routes
            mapping_file_interface_field=3
            ;;
        (*)
            BugError "Unsupported mapping file name '$mapping_file_name' used in ${BASH_SOURCE[0]}"
            ;;
    esac
    read_and_strip_file $CONFIG_DIR/mappings/$mapping_file_name | sort -b -k $mapping_file_interface_field >$TMP_DIR/mappings/$mapping_file_name
done

# Skip if there is not any mapping file content:
mapping_file_content="no"
for mapping_file_name in mac ip_addresses routes ; do
    test -s $TMP_DIR/mappings/$mapping_file_name && mapping_file_content="yes"
done
is_true $mapping_file_content || return 0

LogPrint "Migrating network configuration files according to the mapping files ..."

# TODO:
# All finalize scripts that patch restored files within TARGET_FS_ROOTshould do the same symlink handling which means:
# 1. Skip patching symlink targets that are not within TARGET_FS_ROOT (i.e. when it is an absolute symlink)
# 2. Skip patching if the symlink target contains /proc/ /sys/ /dev/ or /run/
# 3. Skip patching dead symlinks
# See the symlink handling code in finalize/GNU/Linux/280_migrate_uuid_tags.sh and other such files,
# cf. https://github.com/rear/rear/pull/2055 and https://github.com/rear/rear/issues/1338

# Change MAC addresses and network interfaces in network configuration files when there is content in .../mappings/mac:
if test -s $TMP_DIR/mappings/mac ; then
    Log "Rewriting changed MAC addresses"
    # Create sed script:
    sed_script=""
    while read old_mac new_mac interface junk ; do
        test "$old_mac" -a "$new_mac" -a "$old_mac" != "$new_mac" && sed_script="$sed_script ; s/$old_mac/$new_mac/g"
        # Get new interface from the MAC address in case of inet renaming:
        new_interface=$( get_device_by_hwaddr "$new_mac" )
        test "$interface" -a "$new_interface" -a "$interface" != "$new_interface" && sed_script="$sed_script ; s/$interface/$new_interface/g"
    done < <( sed -e 'p ; y/abcdef/ABCDEF/' $TMP_DIR/mappings/mac )
    # This "sed -e 'p ; y/abcdef/ABCDEF/'" hack prints each line as is and once again with upper case hex letters.
    # The reason is that .../mappings/mac has lower case hex letters (cf. doc/mappings/mac.example)
    # but some systems seem to have MAC adresses with upper case hex letters in the config files.
    # We do not want to mess around with that so we do each replacement two times both case-sensitive
    # one with lower case hex letters and the other one with upper case hex letters in the sed script.
    Debug "sed_script for changing MAC addresses and network interfaces: '$sed_script'"
    # Apply the sed script to the network configuration files:
    for network_configuration_file in "${network_configuration_files[@]}" ; do
        sed -i -e "$sed_script" "$network_configuration_file" || LogPrintError "Migrating network configuration in $network_configuration_file failed"
    done
    # Rename network configuration files where the file name contains the MAC address or the interface name:
    for network_configuration_file in "${network_configuration_files[@]}" ; do
        # E.g. when the interface has changed from eth0 to eth1 the sed_script contains "... ; s/eth0/eth1/g" (cf. "Get new interface" above)
        # so when this sed_script is applied to a network configuration file name like $TARGET_FS_ROOT/etc/sysconfig/network/ifcfg-eth0
        # the new_file_name becomes $TARGET_FS_ROOT/etc/sysconfig/network/ifcfg-eth1
        new_file_name="$( sed -e "$sed_script" <<<"$network_configuration_file" )"
        test "$new_file_name" -a "$network_configuration_file" != "$new_file_name" && mv $v "$network_configuration_file" "$new_file_name"
    done
else
    # When .../mappings/ip_addresses or .../mappings/routes exists but .../mappings/mac is missing or has no content
    # we need a .../mappings/mac file because otherwise the logic to rewrite IP addresses or routes would fail.
    # We try to generate one from .../mappings/ip_addresses with old_mac=new_mac for non-migrated interfaces:
    if test -s $TMP_DIR/mappings/ip_addresses ; then
        for interface in $( cut -f 1 -d " " $TMP_DIR/mappings/ip_addresses ) ; do
            # /sys/class/net/$interface/address contains the MAC address with lower case hex letters (cf. above):
            current_mac=$( cat /sys/class/net/$interface/address )
            echo "$mac $mac $interface" >> $TMP_DIR/mappings/mac
        done
        # Verify we could generate a fallback $TMP_DIR/mappings/mac file with acual content (i.e. non-empty):
        if test -s $TMP_DIR/mappings/mac ; then
            Log "Using generated fallback $TMP_DIR/mappings/mac file (/etc/rear/mappings/mac is missing or has no content)"
        else
            # Do not error out at this late state of "rear recover" (after the backup was restored) but inform the user:
            LogPrintError "Cannot migrate network configuration files (/etc/rear/mappings/ip_addresses exits but /etc/rear/mappings/mac is missing or has no content)"
            return 1
        fi
    else
        # When .../mappings/routes exists but neither .../mappings/mac nor .../mappings/ip_addresses exist or neither have content we give up:
        if test -s $TMP_DIR/mappings/routes ; then
            # Do not error out at this late state of "rear recover" (after the backup was restored) but inform the user:
            LogPrintError "Cannot migrate network configuration files (/etc/rear/mappings/routes exits but /etc/rear/mappings/mac is missing or has no content)"
            return 1
        fi
    fi
fi

# Change IP addresses and CIDR or netmask in network configuration files when there is content in .../mappings/ip_addresses:
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



# This script finalize/GNU/Linux/320_migrate_network_configuration_files.sh
# rewrites some network configuration files (cf. network_configuration_files below)
# (currently for Red Hat, SUSE, Debian, Ubuntu)
# as specified in the mapping files
#   /etc/rear/mappings/mac
#   /etc/rear/mappings/ip_addresses
#   /etc/rear/mappings/routes
# in the currently running ReaR recovery system.
# In particular /etc/rear/mappings/mac gets automatically created during recovery system startup
# via [usr/share/rear/skel/default]/etc/scripts/system-setup.d/55-migrate-network-devices.sh
# if the original interface MAC is not found in the currently running recovery system
# so rewriting of MAC addresses happens usually automatically on replacement hardware.
# For the mapping files syntax see
#   doc/mappings/mac.example
#   doc/mappings/routes.example
#   doc/mappings/ip_addresses.example

local restored_file network_config_file
local network_config_files=()
local mapping_file_name mapping_file_interface_field mapping_file_content
local sed_script sed_script_reason
local old_mac new_mac interface junk
local new_interface
local current_mac
local new_ip_cidr new_ip new_cidr new_netmask
local ifcfg_file multiple_addresses_keyword
local network_interfaces_file linearized_network_interfaces_file
local routing_config_file destination gateway

# All finalize scripts that patch restored files within TARGET_FS_ROOT
# should do the same directory and file and symlink handling which means:
# 0. Skip patching non-regular files like directories, device nodes, or files that do not exist
# When the regular file is a symlink:
# 1. Try to patch the symlink target when the regular file is a symlink
# 2. Skip patching if the symlink target contains /proc/ /sys/ /dev/ or /run/
# 3. Skip patching symlink targets that are non-regular files like directories, device nodes, or files that do not exist
# 4. Skip patching dead symlinks
# See the symlink handling code in finalize/GNU/Linux/280_migrate_uuid_tags.sh and other such files,
# cf. https://github.com/rear/rear/pull/2055 and https://github.com/rear/rear/issues/1338
# The restored file argument $1 must be provided as an absolute path in the recovery system
# i.e. as $TARGET_FS_ROOT/path/to/restored_file (usually /mnt/local/path/to/restored_file).
# The valid_restored_file_for_patching function returns 0 and outputs on stdout
# the absolute path in the recovery system of the file that should be used for patching
# when the restored file is a valid regular file or a symlink with a valid symlink target
# otherwise the valid_restored_file_for_patching function returns 1 and outputs nothing:
function valid_restored_file_for_patching () {
    local restored_file="$1"
    local symlink_target
    # Silently skip non-regular files like directories, device nodes, or file not found:
    test -f "$restored_file" || return 1
    if ! test -L "$restored_file" ; then
        # No symlink but a normal existing regular file:
        Log "Patching $restored_file"
        echo -n "$restored_file"
        return 0
    fi
    # Symlink handling:
    # 'sed -i' bails out on symlinks so we patch the symlink target if it exists within TARGET_FS_ROOT.
    # TODO: We may do this inside 'chroot $TARGET_FS_ROOT' so that absolute symlinks will work correctly
    # cf. https://github.com/rear/rear/issues/1338
    # Currently we prepend absolute symlink targets with $TARGET_FS_ROOT and try to use that instead.
    # Get the symlink target regardless of which of its components exist:
    if ! symlink_target="$( readlink -m "$restored_file" )" ; then
        # Skip when readlink cannot resolve the symlink:
        Log "Skip patching symlink $restored_file (readlink could not resolve it)"
        return 1
    fi
    # symlink_target is an absolute path in the recovery system
    # e.g. the symlink target of etc/mtab is /mnt/local/proc/12345/mounts
    # If the symlink target does not start with /mnt/local/ (i.e. if it does not start with $TARGET_FS_ROOT)
    # it is an absolute symlink (i.e. inside $TARGET_FS_ROOT a symlink points to /absolute/path/file)
    # and the target of an absolute symlink is not within the recreated system but in the recovery system
    # where it does not make sense to patch files, cf. https://github.com/rear/rear/issues/1338
    # so that we prepend $TARGET_FS_ROOT to get the symlink target as absolute path in the recovery system
    # (e.g. /absolute/path/file becomes $TARGET_FS_ROOT/absolute/path/file):
    if ! echo $symlink_target | grep -q "^$TARGET_FS_ROOT/" ; then
        Log "Symlink $restored_file target $symlink_target not within $TARGET_FS_ROOT trying $TARGET_FS_ROOT/$symlink_target instead"
        symlink_target="$TARGET_FS_ROOT/$symlink_target"
    fi
    # If the symlink target contains /proc/ /sys/ /dev/ or /run/ we skip it because then
    # the symlink target is considered to not be a restored file that needs to be patched
    # cf. https://github.com/rear/rear/pull/2047#issuecomment-464846777
    if echo $symlink_target | egrep -q '/proc/|/sys/|/dev/|/run/' ; then
        Log "Skip patching symlink $restored_file target $symlink_target on /proc/ /sys/ /dev/ or /run/"
        return 1
    fi
    # Skip symlink targets that are non-regular files like directories, device nodes, or file not found (i.e. dead symlinks):
    if ! test -f "$symlink_target" ; then
        Log "Skip patching symlink $restored_file target $symlink_target is not a regular file"
        return 1
    fi
    # Patch symlink targets that are regular files within TARGET_FS_ROOT:
    Log "Patching symlink $restored_file target $symlink_target"
    echo -n "$symlink_target"
    return 0
}

# Because the bash option nullglob is set in rear (see usr/sbin/rear) restored_file is empty if nothing matches
# $TARGET_FS_ROOT/etc/sysconfig/*/ifcfg-* or $TARGET_FS_ROOT/etc/network/inter[f]aces or $TARGET_FS_ROOT/etc/network/interfaces.d/*
# and $TARGET_FS_ROOT/etc/network/inter[f]aces is a special trick to only add $TARGET_FS_ROOT/etc/network/interfaces if it exists.
# FIXME: The following code fails if file names contain characters from IFS (e.g. blanks),
# see https://github.com/rear/rear/pull/1514#discussion_r141031975
# and for the general issue see https://github.com/rear/rear/issues/1372
for restored_file in $TARGET_FS_ROOT/etc/sysconfig/*/ifcfg-* $TARGET_FS_ROOT/etc/network/inter[f]aces $TARGET_FS_ROOT/etc/network/interfaces.d/* ; do
    network_config_file="$( valid_restored_file_for_patching "$restored_file" )" || continue
    network_config_files+=( $network_config_file )
done

# Skip if no valid restored network configuration files are found
# i.e. when the network_config_files array does not even have a first (non empty) element:
test $network_config_files || return 0

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

LogPrint "Migrating restored network configuration files according to the mapping files ..."

# Change MAC addresses and network interfaces in network configuration files when there is content in .../mappings/mac:
if test -s $TMP_DIR/mappings/mac ; then
    Log "Rewriting changed MAC addresses and network interfaces"
    # Create sed script:
    sed_script=""
    sed_script_reason="setting new MAC addresses and network interfaces"
    while read old_mac new_mac interface junk ; do
        test "$old_mac" -a "$new_mac" -a "$old_mac" != "$new_mac" && sed_script+=" ; s/$old_mac/$new_mac/g"
        # Get new interface from the MAC address in case of inet renaming:
        new_interface=$( get_device_by_hwaddr "$new_mac" )
        test "$interface" -a "$new_interface" -a "$interface" != "$new_interface" && sed_script+=" ; s/$interface/$new_interface/g"
        # The "sed -e 'p ; y/abcdef/ABCDEF/'" hack prints each line as is and once again with upper case hex letters.
        # The reason is that .../mappings/mac has lower case hex letters (cf. doc/mappings/mac.example)
        # but some systems seem to have MAC adresses with upper case hex letters in the config files.
        # We do not want to mess around with that so we do each replacement two times both case-sensitive
        # one with lower case hex letters and the other one with upper case hex letters in the sed script:
    done < <( sed -e 'p ; y/abcdef/ABCDEF/' $TMP_DIR/mappings/mac )
    # Apply the sed script to the network configuration files:
    if test "$sed_script" ; then
        Debug "sed_script for $sed_script_reason: '$sed_script'"
        for network_config_file in "${network_config_files[@]}" ; do
            # The network_config_files array contains only existing files (cf. above how it is set).
            if sed -i -e "$sed_script" "$network_config_file" ; then
                Log "Wrote new MAC addresses and network interfaces in $network_config_file"
            else
                LogPrintError "Failed to rewrite MAC addresses and network interfaces in $network_config_file"
            fi
        done
    else
        Log "No rewriting of MAC addresses and network interfaces (empty sed_script)"
    fi
    # Rename network configuration files where the file name contains the MAC address or the interface name:
    for network_config_file in "${network_config_files[@]}" ; do
        # E.g. when the interface has changed from eth0 to eth1 the sed_script contains "... ; s/eth0/eth1/g" (cf. "Get new interface" above)
        # so when this sed_script is applied to a network configuration file name like $TARGET_FS_ROOT/etc/sysconfig/network/ifcfg-eth0
        # the new_file_name becomes $TARGET_FS_ROOT/etc/sysconfig/network/ifcfg-eth1
        new_file_name="$( sed -e "$sed_script" <<<"$network_config_file" )"
        if test "$new_file_name" -a "$network_config_file" != "$new_file_name" ; then
            Log "Renaming '$network_config_file' as '$new_file_name'"
            mv $v "$network_config_file" "$new_file_name" || LogPrintError "Failed to rename '$network_config_file' as '$new_file_name'"
        fi
    done
else
    # When .../mappings/ip_addresses or .../mappings/routes exists but .../mappings/mac is missing or has no content
    # we need a .../mappings/mac file because otherwise the logic to rewrite IP addresses or routes would fail.
    # We try to generate one from .../mappings/ip_addresses with old_mac=new_mac for non-migrated interfaces:
    if test -s $TMP_DIR/mappings/ip_addresses ; then
        for interface in $( cut -f 1 -d " " $TMP_DIR/mappings/ip_addresses ) ; do
            # /sys/class/net/$interface/address contains the MAC address with lower case hex letters (cf. above):
            current_mac=$( cat /sys/class/net/$interface/address )
            echo "$current_mac $current_mac $interface" >> $TMP_DIR/mappings/mac
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
    Log "Changing IP addresses and CIDR or netmask in network configuration files"
    # mappings/mac is e.g. (old-MAC-address new-MAC-address interface):
    #   00:11:85:c2:b8:d5 00:50:56:b3:75:ad eth0
    #   00:11:85:c2:b8:d7 00:50:56:b3:08:8c eth2
    #   00:11:85:c2:b8:d9 00:50:56:b3:08:8e eth3
    # and mappings/ip_addresses is e.g. (interface IP-address/CIDR or 'dhcp'):
    #   eth0 192.168.100.101/24
    #   eth1 172.16.200.202/16
    #   eth2 dhcp
    # so that "join -1 3 -2 1 mappings/mac mappings/ip_addresses" results (interface old-MAC-address new-MAC-address IP-address/CIDR or 'dhcp'):
    #   eth0 00:11:85:c2:b8:d5 00:50:56:b3:75:ad 192.168.100.101/24
    #   eth2 00:11:85:c2:b8:d7 00:50:56:b3:08:8c dhcp
    # Keep the join result in a file to make debugging easier in the recovery system after "rear recover":
    join -1 3 -2 1 $TMP_DIR/mappings/mac $TMP_DIR/mappings/ip_addresses > $TMP_DIR/mappings/join_mac_ip_addresses
    # Read $TMP_DIR/mappings/join_mac_ip_addresses contents:
    while read interface old_mac new_mac new_ip_cidr junk ; do
        # No interface value means no input at all (i.e. an empty line) that can be silently skipped:
        test "$interface" || continue
        # No new IP-address/CIDR value indicates an issue, so tell the user about it:
        if ! test "$new_ip_cidr" ; then
            LogPrintError "Cannot migrate network configuration for '$interface' (no new IP-address/CIDR value)"
            continue
        fi
        # No old-MAC-address or new-MAC-address value indicates an issue, so tell the user about it:
        if ! test "$old_mac" -a "$new_mac" ; then 
            LogPrintError "Cannot migrate network configuration for '$interface' (no old or new MAC-address value)"
            continue
        fi
        # FIXME: Currently I <jsmeix@suse.de> do not know what to do in case of new_ip_cidr="dhcp"
        # so I skip this case verbosely so that the user is at least informed:
        if test "dhcp" = "$new_ip_cidr" ; then
            LogPrintError "Skipped migrating network configuration for '$interface' (special new IP-address/CIDR value 'dhcp')"
            continue
        fi
        # Log what will be done to make debugging easier:
        Log "Migrating network configuration for '$interface' '$old_mac' '$new_mac' '$new_ip_cidr' (interface old-MAC-address new-MAC-address IP-address/CIDR)"
        # Only the IP-address part of IP-address/CIDR:
        new_ip="${new_ip_cidr%%/*}"
        # Only the CIDR part of IP-address/CIDR:
        new_cidr=${new_ip_cidr#*/}
        # RHEL 4, 5,... cannot handle IPADDR="x.x.x.x/cidr" in ifcfg configuration files
        # but only plain IPADDR="x.x.x.x" plus a separated NETMASK="y.y.y.y" entry
        # so we convert the CIDR to a netmask (e.g. "24" -> "255.255.255.0").
        # See the prefix2netmask function in lib/network-functions.sh
        # e.g. "prefix2netmask 24" results "255.255.255.0":
        new_netmask=$( prefix2netmask $new_cidr )
        # If prefix2netmask results no real netmask use an empty fallback value:
        test "0.0.0.0" = "$new_netmask" && new_netmask=""
        # Now we have for example for the following input (cf. the example above)
        #   eth0 00:11:85:c2:b8:d5 00:50:56:b3:75:ad 192.168.100.101/24
        # those variables set:
        #   $interface="eth0"
        #   $old_mac="00:11:85:c2:b8:d5"
        #   $new_mac="00:50:56:b3:75:ad"
        #   $new_ip_cidr="192.168.100.101/24"
        #   $new_ip=192.168.100.101"
        #   $new_cidr="24"
        #   $new_netmask="255.255.255.0"

        # Handle Fedora and SUSE network configuration files (with sysconfig ifcfg configuration files).
        # Because the bash option nullglob is set in rear (see usr/sbin/rear) nothing is done if no file matches.
        # FIXME: The following code fails if file names contain characters from IFS (e.g. blanks),
        # see https://github.com/rear/rear/pull/1514#discussion_r141031975
        # and for the general issue see https://github.com/rear/rear/issues/1372
        for restored_file in $TARGET_FS_ROOT/etc/sysconfig/*/ifcfg-*$new_mac* $TARGET_FS_ROOT/etc/sysconfig/*/ifcfg-*$interface* ; do
            ifcfg_file="$( valid_restored_file_for_patching "$restored_file" )" || continue
            sed_script=""
            sed_script_reason=""
            # On a SLES15-like openSUSE Leap 15.0 system /etc/sysconfig/network/ifcfg.template shows in particular
            #   If using a static configuration you have to set an IP address and a netmask
            #   or prefix length. The following examples are equivalent:
            #   1) IPADDR=192.168.1.1/24     # NETMASK and PREFIXLEN will be ignored
            #   2) IPADDR=192.168.1.1
            #      PREFIXLEN=24              # NETMASK will be ignored
            #   3) IPADDR=192.168.1.1
            #      NETMASK=255.255.255.0
            # so we need to adapt the ifcfg configuration file depending on what kind of syntax there is currently used
            # because this script works on the user's restored files of his target system in /mnt/local
            # so what it does must match what there is on the user's target system.
            # An IPv6 address consists of hexadecimal numbers '0-9A-Fa-f' plus ':' separators
            # like '1080::8:800:200C:417A' where '::' is the shortest possible IPv6 address,
            # cf. "Current formats" in https://tools.ietf.org/html/rfc1924
            # so ':' can be the first (and only) character in an IPv6 address.
            # In ifcfg configuration files the vaule can be in single quotes like KEYWORD='VALUE':
            if grep -q "^IPADDR=[':0-9A-Fa-f][.:0-9A-Fa-f]*/[0-9'][0-9']*" $ifcfg_file ; then
                # Case 1) where the syntax is like IPADDR=192.168.1.1/24 or IPADDR='192.168.1.1/24'
                # replace the old IPADDR value with the new_ip_cidr value (always in the IPADDR='...' form) and
                # set NETMASK and PREFIXLEN empty (to remove useless old values that may not match the new_ip_cidr value).
                # The usual sed 's/regexp/replacement/flags' command delimiter character / is replaced by # here because
                # the delimiter character must not appear in regexp or replacement but e.g. 192.168.1.1/24 contains it:
                sed_script+=" ; s#^IPADDR=.*#IPADDR='$new_ip_cidr'#g ; s#^NETMASK=.*#NETMASK=''#g ; s#^PREFIXLEN=.*#PREFIXLEN=''#g"
                sed_script_reason="setting new IP-address/CIDR"
            else # Case 2) plain IPADDR plus PREFIXLEN or case 3) plain IPADDR plus NETMASK:
                if grep -q "^IPADDR=[':0-9A-Fa-f][.:0-9A-Fa-f']*" $ifcfg_file ; then
                    # Plain IPADDR like IPADDR=192.168.1.1 or IPADDR='1080::8:800:200C:417A' found
                    # (the IPADDR with CIDR case like IPADDR='192.168.1.1/24' was found above).
                    # Replace the old plain IPADDR value with the new_ip value (always in the IPADDR='...' form):
                    # set NETMASK and PREFIXLEN empty (to remove useless old values that may not match the new_ip value):
                    sed_script+=" ; s#^IPADDR=.*#IPADDR='$new_ip'#g ; s#^NETMASK=.*#NETMASK=''#g ; s#^PREFIXLEN=.*#PREFIXLEN=''#g"
                    if grep -q "^PREFIXLEN=['0-9][0-9']*" $ifcfg_file ; then
                        # Case 2) plain IPADDR plus PREFIXLEN like PREFIXLEN=24 found.
                        # Replace the old PREFIXLEN value with the new_cidr value (always in the PREFIXLEN='...' form)
                        # and set NETMASK empty (to remove a useless old value that may not match the new_cidr value):
                        sed_script+=" ; s#^PREFIXLEN=.*#PREFIXLEN='$new_cidr'#g ; s#^NETMASK=.*#NETMASK=''#g"
                        sed_script_reason="setting new IP-address plus PREFIXLEN"
                    else
                        # Case 3) plain IPADDR plus NETMASK:
                        if grep -q "^NETMASK=['0-9][.0-9']*" $ifcfg_file ; then
                            # NETMASK like NETMASK=255.255.255.0 found:
                            # Replace the old NETMASK value with the new_netmask value (always in the NETMASK='...' form)
                            # and set PREFIXLEN empty (to remove a useless old value that may not match the new_netmask value):
                            sed_script+=" ; s#^NETMASK=.*#NETMASK='$new_netmask'#g ; s#^PREFIXLEN=.*#PREFIXLEN=''#g"
                            sed_script_reason="setting new IP-address plus NETMASK"
                        else
                            # Neither PREFIXLEN nor NETMASK:
                            LogPrintError "Cannot set netmask or prefix length for new IP-address '$new_ip' (neither PREFIXLEN nor NETMASK in $ifcfg_file)"
                            # Do not 'continue' with the next ifcfg_file because the plain new_ip can be set o it is set without netmask or prefix length.
                        fi
                    fi
                else
                    # Neither IPADDR with CIDR nor plain IPADDR:
                    LogPrintError "Cannot set new IP-address '$new_ip' (no IPADDR in $ifcfg_file)"
                    continue
                fi
            fi
            # Set NETWORK and BROADCAST empty (to remove possibly useless old values that may not match the values):
            sed_script+=" ; s#^NETWORK=.*#NETWORK=''#g ; s#^BROADCAST=.*#BROADCAST=''#g"
            # Set BOOTPROTO and STARTMODE to default/fallback values (for STARTMODE 'manual' or 'off' or 'onboot'):
            sed_script+=" ; s#^BOOTPROTO=.*#BOOTPROTO='static'#g ; s#STARTMODE='*\(manual\|off\|onboot\).*#STARTMODE='auto'#g "
            # Delete entries for
            # IPADDR_suffix BROADCAST_suffix NETMASK_suffix PREFIXLEN_suffix REMOTE_IPADDR_suffix LABEL_suffix SCOPE_suffix IP_OPTIONS_suffix
            # cf. "Multiple addresses" in "man 5 ifcfg":
            for multiple_addresses_keyword in IPADDR_ BROADCAST_ NETMASK_ PREFIXLEN_ REMOTE_IPADDR_ LABEL_ SCOPE_ IP_OPTIONS_ ; do
                sed_script+=" ; /^$multiple_addresses_keyword/d"
            done
            # Apply the sed script to the ifcfg_file:
            if test "$sed_script" ; then
                # The ifcfg_file variable contains only existing files (cf. above how it is set):
                Log "Migrating network configuration in $ifcfg_file"
                Debug "sed_script for $sed_script_reason: '$sed_script'"
                sed -i -e "$sed_script" "$ifcfg_file" || LogPrintError "Failed to migrate network configuration in $ifcfg_file"
            else
                Log "Not migrating network configuration in $ifcfg_file (empty sed_script)"
            fi
            # End handling Fedora and SUSE network configuration files (with sysconfig ifcfg configuration files):
        done

        # Handle Debian and Ubuntu network configuration files (with network interfaces configuration files).
        # Because the bash option nullglob is set in rear (see usr/sbin/rear) nothing is done if no file matches.
        # FIXME: The following code fails if file names contain characters from IFS (e.g. blanks),
        # see https://github.com/rear/rear/pull/1514#discussion_r141031975
        # and for the general issue see https://github.com/rear/rear/issues/1372
        for restored_file in $TARGET_FS_ROOT/etc/network/inter[f]aces $TARGET_FS_ROOT/etc/network/interfaces.d/* ; do
            # To be on the safe side we do not use 'interfaces_file' as variable name here because
            # that name is used as non-local name in the linearize_interfaces_file function which is called below
            # regardless that currently the linearize_interfaces_file function would not change an outer interfaces_file value
            # because it is called with the outer interfaces_file value as $1 and then it sets interfaces_file=$1
            network_interfaces_file="$( valid_restored_file_for_patching "$restored_file" )" || continue
            Log "Migrating network configuration for $network_interfaces_file"
            # Get new interface from the MAC address in case of inet renaming:
            new_interface=$( get_device_by_hwaddr "$new_mac" )
            if test "$new_cidr" ; then
                # We have IP-address/CIDR like 192.168.100.101/24 so we use that without a separated netmask setting.
                # The usual sed 's/regexp/replacement/flags' command delimiter character / is replaced by # here because
                # the delimiter character must not appear in regexp or replacement but e.g. 192.168.100.101/24 contains it:
                sed_script="/iface $new_interface/ s#;address [0-9.]*;#;address $new_ip_cidr;#g"
            else
                # We have a plain IP-address like 192.168.100.101 without CIDR:
                if test "$new_netmask" ; then
                    # We also have a netmask so we use the plain IP-address plus a separated netmask setting:
                    sed_script="/iface $new_interface/ s#;address [0-9.]*;#;address $new_ip;#g ; /iface $new_interface/ s#;netmask [0-9.]*;#;netmask $new_netmask;#g"
                else
                    # We have only a plain IP-address like 192.168.100.101 but no netmask so we can use only the plain IP-address
                    # but only a plain IP-address without netmask is likely insufficient so we tell the user about it:
                    LogPrintError "Only plain IP-address $new_ip without netmask can be set in $network_interfaces_file (likely insufficient)"
                    sed_script="/iface $new_interface/ s#;address [0-9.]*;#;address $new_ip;#g"
                fi
            fi
            linearized_network_interfaces_file="$TMP_DIR/${network_interfaces_file##*/}.linearized"
            linearize_interfaces_file "$network_interfaces_file" > "$linearized_network_interfaces_file"
            # Apply the sed script:
            Debug "sed_script for migrating network configuration for $network_interfaces_file in $linearized_network_interfaces_file: '$sed_script'"
            sed -i -e "$sed_script" "$linearized_network_interfaces_file" || LogPrintError "Failed to migrate network configuration in $linearized_network_interfaces_file"
            rebuild_interfaces_file_from_linearized "$linearized_network_interfaces_file" > "$network_interfaces_file"
            # End handling Debian and Ubuntu network configuration files (with network interfaces configuration files):
        done

        # End of "while read interface old_mac new_mac new_ip_cidr":
    done < $TMP_DIR/mappings/join_mac_ip_addresses
    # End changing IP addresses and CIDR or netmask in network configuration files when there is content in .../mappings/ip_addresses:
fi

# Setting new default routing when there is content in ...mappings/routes:
if test -s $TMP_DIR/mappings/routes ; then
    # Tell the user to do things manually in case of route-<interface> or static-routes configuration files.
    # FIXME: The following code fails if file names contain characters from IFS (e.g. blanks),
    # see https://github.com/rear/rear/pull/1514#discussion_r141031975
    # and for the general issue see https://github.com/rear/rear/issues/1372
    for restored_file in $TARGET_FS_ROOT/etc/sysconfig/*/route-*$interface* $TARGET_FS_ROOT/etc/sysconfig/static-rou[t]es ; do
        routing_config_file="$( valid_restored_file_for_patching "$restored_file" )" || continue
        LogPrintError "Cannot set routing in $routing_config_file - you need to do that manually"
    done
    # mappings/mac is e.g. (old-MAC-address new-MAC-address interface):
    #   00:11:85:c2:b8:d5 00:50:56:b3:75:ad eth0
    #   00:11:85:c2:b8:d7 00:50:56:b3:08:8c eth2
    #   00:11:85:c2:b8:d9 00:50:56:b3:08:8e eth3
    # and mappings/routes is e.g. (destination/CIDR gateway-IP interface):
    #   default 10.100.200.1 eth0
    #   192.168.100.0/24 172.16.200.202 eth3
    # so that "join -1 3 -2 3 mappings/mac mappings/routes" results on stdout (interface old-MAC-address new-MAC-address destination/CIDR gateway-IP):
    #   eth0 00:11:85:c2:b8:d5 00:50:56:b3:75:ad default 10.100.200.1
    #   eth3 00:11:85:c2:b8:d9 00:50:56:b3:08:8e 192.168.100.0/24 172.16.200.202
    # Keep the join result in a file to make debugging easier in the recovery system after "rear recover":
    join -1 3 -2 3 $TMP_DIR/mappings/mac $TMP_DIR/mappings/routes > $TMP_DIR/mappings/join_mac_routes
    # Read $TMP_DIR/mappings/join_mac_routes contents:
    while read interface old_mac new_mac destination gateway junk ; do
        if ! test "$destination" = "default" ; then
            # Tell the user to set non-default routing manually (i.e. non-default destination like 192.168.100.0/24)
            LogPrintError "Cannot set routing for non-default destination $destination via gateway $gateway and interface $interface - you need to do that manually"
            continue
        fi
        # Set default routing:
        Log "Setting new default routing in network configuration files"
        # Handle Fedora and SUSE default routing configuration files (with sysconfig ifcfg configuration files).
        # Because the bash option nullglob is set in rear (see usr/sbin/rear) nothing is done if no file matches.
        # FIXME: The following code fails if file names contain characters from IFS (e.g. blanks),
        # see https://github.com/rear/rear/pull/1514#discussion_r141031975
        # and for the general issue see https://github.com/rear/rear/issues/1372
        for restored_file in $TARGET_FS_ROOT/etc/sysconfig/*/ifcfg-*$new_mac* $TARGET_FS_ROOT/etc/sysconfig/*/ifcfg-*$interface* $TARGET_FS_ROOT/etc/sysconfig/ne[t]work ; do
            routing_config_file="$( valid_restored_file_for_patching "$restored_file" )" || continue
            # etc/sysconfig/network syntay (excerpts):
            #   GATEWAY=gwip where gwip is the IP address of the remote network gateway if available
            #   GATEWAYDEV=gwdev where gwdev is the device name eth# you use to access the remote gateway
            sed_script="s#^GATEWAY=.*#GATEWAY='$gateway'#g ; s#^GATEWAYDEV=.*#GATEWAYDEV='$interface'#g"
            # Apply the sed script:
            Debug "sed_script for setting default routing in $routing_config_file: '$sed_script'"
            sed -i -e "$sed_script" "$routing_config_file" || LogPrintError "Failed to set default routing in $routing_config_file"
        done
        # Handle Debian and Ubuntu network configuration files (with network interfaces configuration files).
        # Because the bash option nullglob is set in rear (see usr/sbin/rear) nothing is done if no file matches.
        # FIXME: The following code fails if file names contain characters from IFS (e.g. blanks),
        # see https://github.com/rear/rear/pull/1514#discussion_r141031975
        # and for the general issue see https://github.com/rear/rear/issues/1372
        for restored_file in $TARGET_FS_ROOT/etc/network/inter[f]aces $TARGET_FS_ROOT/etc/network/interfaces.d/* ; do
            # To be on the safe side we do not use 'interfaces_file' as variable name here because
            # that name is used as non-local name in the linearize_interfaces_file function which is called below
            # regardless that currently the linearize_interfaces_file function would not change an outer interfaces_file value
            # because it is called with the outer interfaces_file value as $1 and then it sets interfaces_file=$1
            network_interfaces_file="$( valid_restored_file_for_patching "$restored_file" )" || continue
            Log "Migrating network configuration for $network_interfaces_file"
            # Get new interface from the MAC address in case of inet renaming:
            new_interface=$( get_device_by_hwaddr "$new_mac" )
            sed_script="/iface $new_interface/ s#;gateway [0-9.]*;#;gateway $gateway;#g"
            linearized_network_interfaces_file="$TMP_DIR/${network_interfaces_file##*/}.linearized"
            linearize_interfaces_file "$network_interfaces_file" > "$linearized_network_interfaces_file"
            # Apply the sed script:
            Debug "sed_script for setting default routing for $network_interfaces_file in $linearized_network_interfaces_file: '$sed_script'"
            sed -i -e "$sed_script" "$linearized_network_interfaces_file" || LogPrintError "Failed to set default routing in $linearized_network_interfaces_file"
            rebuild_interfaces_file_from_linearized "$linearized_network_interfaces_file" > "$network_interfaces_file"
        done
        # End of "while read interface old_mac new_mac destination gateway":
    done < $TMP_DIR/mappings/join_mac_routes
    # End setting new default routing when there is content in ...mappings/routes:
fi

unset -f valid_restored_file_for_patching


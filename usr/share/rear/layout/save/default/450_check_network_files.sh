# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# No quoting of the elements that are appended to the CHECK_CONFIG_FILES array together with
# the bash globbing characters like '*' or the [] around the first letter make sure
# that with 'shopt -s nullglob' files that do not exist will not appear
# so nonexistent files are not appended to CHECK_CONFIG_FILES
# cf. https://github.com/rear/rear/pull/2796#issuecomment-1117171070

if [[ -d /etc/sysconfig/network ]] ; then
    # SUSE
    CHECK_CONFIG_FILES+=( /[e]tc/sysconfig/network/ifcfg-* )
fi

if [[ -d /etc/NetworkManager/system-connections ]] ; then
    # Red Hat >= 8
    # Check if the network interfaces are really present in NetworkManager style and if yes also add nmcli to PROGS array
    CHECK_CONFIG_FILES+=( /[e]tc/NetworkManager/system-connections/*.nmconnection )
    PROGS+=( nmcli )
fi

if [[ -d /etc/sysconfig/network-scripts ]] ; then
    # Red Hat <=8
    # Check if the network interfaces are really present in legacy network configuration files
    CHECK_CONFIG_FILES+=( /[e]tc/sysconfig/network-scripts/ifcfg-* )
fi

if [[ -f /etc/network/interfaces ]] ; then
    # Debian
    CHECK_CONFIG_FILES+=( /etc/network/interfaces )
fi

if [[ -d /etc/netplan ]] ; then
   # Ubuntu using NetworkManager
   CHECK_CONFIG_FILES+=( /[e]tc/netplan/*.yaml )
   PROGS+=( nmcli )
fi

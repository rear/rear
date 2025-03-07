# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# No quoting of the elements that are appended to the CHECK_CONFIG_FILES array together with
# the bash globbing characters like '*' or the [] around the first letter make sure
# that with 'shopt -s nullglob' files that do not exist will not appear
# so nonexistent files are not appended to CHECK_CONFIG_FILES
# cf. https://github.com/rear/rear/pull/2796#issuecomment-1117171070

if [[ -d /etc/sysconfig/network ]] ; then
    # SUSE
    ls /etc/sysconfig/network/ifcfg-* >/dev/null 2>&1 && CHECK_CONFIG_FILES+=( /etc/sysconfig/network/ifcfg-* )
fi

if [[ -d /etc/NetworkManager/system-connections ]] ; then
    # Red Hat >= 8
    # Check if the network interfaces are really present in NetworkManager style and if yes also add nmcli to PROGS array
    ls /etc/NetworkManager/system-connections/*.nmconnection >/dev/null 2>&1 && CHECK_CONFIG_FILES+=( /etc/NetworkManager/system-connections/*.nmconnection )
    PROGS+=( nmcli )
fi

if [[ -d /etc/sysconfig/network-scripts ]] ; then
    # Red Hat <=8
    # Check if the network interfaces are really present in legacy network configuration files
    ls /etc/sysconfig/network-scripts/ifcfg-* >/dev/null 2>&1 && CHECK_CONFIG_FILES+=( /etc/sysconfig/network-scripts/ifcfg-* )
fi

if [[ -d /etc/network ]] ; then
    # Debian
    CHECK_CONFIG_FILES+=( /etc/network/interfaces )
fi

if [[ -d /etc/netplan ]] ; then
   # Ubuntu using NetworkManager
   CHECK_CONFIG_FILES+=( /etc/network/*.yaml )
   PROGS+=( nmcli )
fi

# This file is part of Relax and Recover, licensed under the GNU General
# Public License. Refer to the included LICENSE for full text of license.

if [[ -d /etc/sysconfig/network ]]; then
    # suse
    CHECK_CONFIG_FILES=( ${CHECK_CONFIG_FILES[@]} /etc/sysconfig/network/ifcfg-* )
elif [[ -d /etc/sysconfig/network-scripts ]]; then
    # redhat
    CHECK_CONFIG_FILES=( ${CHECK_CONFIG_FILES[@]} /etc/sysconfig/network-scripts/ifcfg-* )
elif [[ -d /etc/network ]]; then
    # debian
    CHECK_CONFIG_FILES=( ${CHECK_CONFIG_FILES[@]} /etc/network/interfaces )
fi


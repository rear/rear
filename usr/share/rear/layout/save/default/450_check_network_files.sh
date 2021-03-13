# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

if [[ -d /etc/sysconfig/network ]] ; then
    # SUSE
    CHECK_CONFIG_FILES+=( /etc/sysconfig/network/ifcfg-* )
elif [[ -d /etc/sysconfig/network-scripts ]] ; then
    # Red Hat
    CHECK_CONFIG_FILES+=( /etc/sysconfig/network-scripts/ifcfg-* )
elif [[ -d /etc/network ]] ; then
    # Debian
    CHECK_CONFIG_FILES+=( /etc/network/interfaces )
fi


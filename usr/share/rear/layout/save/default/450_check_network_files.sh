# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.


# No quoting of the elements that are appended to the CHECK_CONFIG_FILES array together with
# the bash globbing characters like '*' or the [] around the first letter make sure
# that with 'shopt -s nullglob' files that do not exist will not appear
# so nonexistent files are not appended to CHECK_CONFIG_FILES
# cf. https://github.com/rear/rear/pull/2796#issuecomment-1117171070
if [[ -d /etc/sysconfig/network ]] ; then
    # SUSE
    CHECK_CONFIG_FILES+=( /etc/sysconfig/network/ifcfg-* )
elif [[ -d /etc/sysconfig/network-scripts ]] ; then
    # Red Hat
    CHECK_CONFIG_FILES+=( /etc/sysconfig/network-scripts/ifcfg-* )
elif [[ -d /etc/network ]] ; then
    # Debian
    CHECK_CONFIG_FILES+=( /[e]tc/network/interfaces )
fi


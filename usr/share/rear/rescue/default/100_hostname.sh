# 100_hostname.sh
#
# take hostname for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# For Arch Linux storing the host name in /etc/hostname (lowercase)
# will set the host name in the recovery environment without any scripting.

if [[ -e /etc/hostname ]] ; then
    echo $HOSTNAME >$ROOTFS_DIR/etc/hostname
else
    echo $HOSTNAME >$ROOTFS_DIR/etc/HOSTNAME
fi

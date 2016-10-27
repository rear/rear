# 10_hostname.sh
#
# take hostname for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

echo $HOSTNAME >$ROOTFS_DIR/etc/HOSTNAME

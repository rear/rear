# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

echo "BACKUP_PROG=$BACKUP_PROG" >> "$ROOTFS_DIR/etc/rear/rescue.conf" || Error "Failed to add 'BACKUP_PROG=$BACKUP_PROG' to rescue.conf"
Log "Added 'BACKUP_PROG=$BACKUP_PROG' to rescue.conf"

# This file is part of Relax and Recover, licensed under the GNU General
# Public License. Refer to the included LICENSE for full text of license.

echo "BACKUP_PROG=$BACKUP_PROG" >> "$ROOTFS_DIR/etc/rear/rescue.conf"
LogIfError "Could not add BACKUP_PROG variable to rescue.conf"

Log "Defined BACKUP_PROG=$BACKUP_PROG"

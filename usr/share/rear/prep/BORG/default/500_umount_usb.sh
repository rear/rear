# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 500_umount_usb.sh

if [[ -z $BORGBACKUP_HOST ]]; then
    umount_url usb://$BORGBACKUP_USB_DEV $BUILD_DIR/borg_backup
fi

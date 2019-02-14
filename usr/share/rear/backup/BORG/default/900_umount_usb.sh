# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 900_umount_usb.sh

# After BORG operations are over, we can finally umount USB_DEVICE.
# This will force final sync of data that can still sit in cache.
if [[ -z $BORGBACKUP_HOST ]]; then
    umount_url usb://$USB_DEVICE $borg_dst_dev
fi

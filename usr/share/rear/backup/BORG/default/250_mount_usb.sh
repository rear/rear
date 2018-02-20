# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 250_mount_usb.sh

# We need to mount USB destination device prior the backup starts
if [[ -z $BORGBACKUP_HOST ]]; then
    mount_url usb://$USB_DEVICE $borg_dst_dev
fi

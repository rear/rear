# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 250_mount_usb.sh

# We need to mount USB_DEVICE in order to prepare for Borg archive
# initialization, but only if BORGBACKUP_HOST is not set.
# When BORGBACKUP_HOST is set, we don't need to mount anything as SSH
# backup destination will be handled internally by Borg it self.
if [[ -z $BORGBACKUP_HOST ]]; then
    mkdir -p $v "$borg_dst_dev" >&2
    StopIfError "Could not mkdir '$borg_dst_dev'"

    mount_url usb://$USB_DEVICE $borg_dst_dev
fi

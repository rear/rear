# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 100_set_vars.sh

borg_set_vars

# If BORGBACKUP_HOST is not set, we automatically assume that USB device should
# be used as backup back end.
# borg_dst_dev will be set to mount point, where USB_DEVICE will be mounted
# in case of empty BORGBACKUP_HOST. While by non-zero BORGBACKUP_HOST we assume
# that SSH should be used as transfer protocol and borg_dst_dev becomes
# combined string of "BORGBACKUP_USERNAME@BORGBACKUP_HOST".
# borg_dst_dev directory will be created in later stage
# (if not already present) by 250_mount_usb.sh script.
if [[ -n $BORGBACKUP_HOST ]]; then
    borg_dst_dev=$BORGBACKUP_USERNAME@$BORGBACKUP_HOST:
else
    borg_dst_dev=$BUILD_DIR/borg_backup
fi

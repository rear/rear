# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 250_mount_usb.sh

if [[ -z $BORGBACKUP_HOST ]]; then
    mkdir -p $v "$BUILD_DIR/borg_backup" >&2
    StopIfError "Could not mkdir '$BUILD_DIR/borg_backup'"

    AddExitTask "rm -Rf $v $BUILD_DIR/borg_backup >&2"

    mount_url usb://$USB_DEVICE $BUILD_DIR/borg_backup
fi

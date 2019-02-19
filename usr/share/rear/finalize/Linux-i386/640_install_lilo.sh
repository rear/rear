#  This script is meant for linux based systems using legacy LILO (Slackware)
#

# skip if another bootloader was installed
if [[ -z "$NOBOOTLOADER" ]] ; then
    return
fi

# For UEFI systems with lilo legacy with should use efibootmgr instead:
is_true $USING_UEFI_BOOTLOADER && return

# Only for lilo
[[ "$BOOTLOADER" == "LILO" ]] || return 0 # only continue when bootloader is lilo based

type -p $TARGET_FS_ROOT/sbin/lilo || Error "BOOTLOADER is LILO but there is no $TARGET_FS_ROOT/sbin/lilo"

LogPrint "Installing LILO boot loader"

if [[ -r "$LAYOUT_FILE" && -r "$LAYOUT_DEPS" ]]; then

    [[ -r "$TARGET_FS_ROOT/etc/lilo.conf" ]]
    LogIfError "Unable to find /etc/lilo.conf"

    # Find the disks that need a new LILO
    disks=$( grep '^disk \|^multipath ' $LAYOUT_FILE | cut -d' ' -f2 )
    [[ "$disks" ]] || Error "Unable to find any disks to install LILO on"

    chroot $TARGET_FS_ROOT /sbin/lilo -v >&2

    if (( $? == 0 )); then
        NOBOOTLOADER=
    fi
fi


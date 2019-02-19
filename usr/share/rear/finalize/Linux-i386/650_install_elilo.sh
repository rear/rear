#  This script is meant for UEFI based systems using ELILO (SLES)
#

# skip if another bootloader was installed
if [[ -z "$NOBOOTLOADER" ]] ; then
    return
fi

# for UEFI systems we defined USING_UEFI_BOOTLOADER=1; BIOS based is 0 or ""
is_true $USING_UEFI_BOOTLOADER || return 0 # when set to 0

# Only for elilo
[[ "$BOOTLOADER" == "ELILO" ]] || return 0 # only continue when bootloader is elilo based

# FIXME:
# This tests for elilo in the recovery system but below elilo is called inside chroot in the target system
# furthermore why such a complicated test instead of testing with plain "type -p elilo || Error ..."
# cf. the better looking code in finalize/Linux-i386/640_install_lilo.sh
[[ $(type -p elilo) ]] || Error "Could not find elilo executable"

LogPrint "Installing ELILO boot loader"

if [[ -r "$LAYOUT_FILE" && -r "$LAYOUT_DEPS" ]]; then

    # Check if we find the vfat file system /boot/efi where we expect it
    [[ -d "$TARGET_FS_ROOT/boot/efi" ]] || Error "Could not find directory /boot/efi"

    # the UEFI_BOOTLOADER was saved in /etc/rear/rescue.conf file by rear mkrescue/mkbackup
    [[ -f "$TARGET_FS_ROOT$UEFI_BOOTLOADER" ]] || Error "Could not find elilo.efi"

    [[ -r "$TARGET_FS_ROOT/etc/elilo.conf" ]]
    LogIfError "Unable to find /etc/elilo.conf"

    # Find the disks that need a new ELILO
    disks=$( grep '^disk \|^multipath ' $LAYOUT_FILE | cut -d' ' -f2 )
    [[ "$disks" ]] || Error "Unable to find any disks"

    chroot $TARGET_FS_ROOT elilo -v >&2

    if (( $? == 0 )); then
        NOBOOTLOADER=
    fi
fi

